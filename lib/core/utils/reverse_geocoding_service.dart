import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ReverseGeocodingService {
  static const String _defaultGoogleApiKey = 'AIzaSyCRV3CEy0trgd_EGdX4L6D1tvhJ_GOKxO0';
  static const String _googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: String.fromEnvironment('MAPS_API_KEY', defaultValue: _defaultGoogleApiKey),
  );

  static final Map<String, String> _cache = {};
  static final Map<String, Future<String>> _inFlight = {};

  static String _formatKey(double lat, double lng) {
    return '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
  }

  static String? getCachedAddress(double lat, double lng) {
    final key = _formatKey(lat, lng);
    return _cache[key];
  }

  static String _cleanAddressText(String text) {
    if (text.isEmpty) return text;
    var cleaned = text.trim();
    // Strip leading Plus Code (e.g., '277G+P7, ...')
    cleaned = cleaned.replaceFirst(RegExp(r'^[A-Z0-9\+]+\s*,\s*'), '');
    // Strip municipal administrative zone prefix (e.g. 'Zone 11 Valasaravakkam' -> 'Valasaravakkam')
    cleaned = cleaned.replaceAll(RegExp(r'Zone\s*\d+\s*,?\s*', caseSensitive: false), '');
    // Clean up multiple commas or leading/trailing commas
    cleaned = cleaned.replaceAll(RegExp(r'\s*,\s*,\s*'), ', ').replaceAll(RegExp(r'^,\s*|,\s*$'), '').trim();
    return cleaned;
  }

  static Future<String> getAddress(double lat, double lng) async {
    final key = _formatKey(lat, lng);
    if (_cache.containsKey(key) && _cache[key]!.isNotEmpty) {
      return _cache[key]!;
    }

    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!;
    }

    final future = _fetchAddress(lat, lng, key);
    _inFlight[key] = future;

    try {
      final result = await future;
      _cache[key] = result;
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<String> _fetchAddress(double lat, double lng, String cacheKey) async {
    // 1. Try Google Geocoding API first
    if (_googleMapsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey',
        );
        final resp = await http.get(url).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final results = data['results'] as List;

            // Try to construct a clean address from address_components if available
            final firstResult = results.first as Map<String, dynamic>;
            final components = firstResult['address_components'] as List?;
            if (components != null && components.isNotEmpty) {
              String sublocality = '';
              String neighborhood = '';
              String route = '';
              String locality = '';

              for (final comp in components) {
                final types = (comp['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final name = (comp['long_name'] ?? comp['short_name'] ?? '').toString().trim();
                if (types.contains('sublocality_level_1') || types.contains('sublocality')) {
                  sublocality = name;
                } else if (types.contains('neighborhood')) {
                  neighborhood = name;
                } else if (types.contains('route')) {
                  route = name;
                } else if (types.contains('locality')) {
                  locality = name;
                }
              }

              final parts = <String>[];
              final specificArea = neighborhood.isNotEmpty ? neighborhood : sublocality;
              if (route.isNotEmpty && route != specificArea) parts.add(_cleanAddressText(route));
              if (specificArea.isNotEmpty) parts.add(_cleanAddressText(specificArea));
              if (locality.isNotEmpty && locality != specificArea && locality != route) parts.add(_cleanAddressText(locality));

              if (parts.isNotEmpty) {
                final assembled = parts.where((p) => p.isNotEmpty).join(', ');
                if (assembled.isNotEmpty) {
                  return assembled;
                }
              }
            }

            final fullAddr = firstResult['formatted_address']?.toString() ?? '';
            if (fullAddr.isNotEmpty) {
              final cleaned = _cleanAddressText(fullAddr);
              if (cleaned.isNotEmpty) {
                return cleaned;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ReverseGeocodingService] Google error: $e');
      }
    }

    // 2. Try OpenStreetMap Nominatim API Fallback
    try {
      final nomUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final nomResp = await http.get(
        nomUrl,
        headers: {'User-Agent': 'iGreenTechnologyApp/1.0 (contact@igreentechnology.com)'},
      ).timeout(const Duration(seconds: 4));

      if (nomResp.statusCode == 200) {
        final nomData = jsonDecode(nomResp.body);
        final addr = nomData['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final road = _cleanAddressText((addr['road'] ?? addr['pedestrian'] ?? addr['street'] ?? '').toString().trim());
          final localArea = _cleanAddressText((addr['neighbourhood'] ?? addr['residential'] ?? addr['quarter'] ?? addr['village'] ?? addr['hamlet'] ?? addr['suburb'] ?? '').toString().trim());
          final district = _cleanAddressText((addr['city_district'] ?? addr['subdistrict'] ?? '').toString().trim());
          final city = (addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['state_district'] ?? addr['state'] ?? 'Chennai').toString().trim();

          final primaryArea = localArea.isNotEmpty ? localArea : district;

          final parts = <String>[];
          if (road.isNotEmpty && road != primaryArea) parts.add(road);
          if (primaryArea.isNotEmpty) parts.add(primaryArea);
          if (city.isNotEmpty && city != primaryArea && city != road) parts.add(city);

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        final displayName = (nomData['display_name'] ?? '').toString().trim();
        if (displayName.isNotEmpty) {
          final cleaned = _cleanAddressText(displayName);
          final parts = cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          if (parts.length > 3) {
            return parts.take(3).join(', ');
          }
          return cleaned;
        }
      }
    } catch (e) {
      debugPrint('[ReverseGeocodingService] Nominatim error: $e');
    }

    // Fallback: Formatted coordinates string
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}
