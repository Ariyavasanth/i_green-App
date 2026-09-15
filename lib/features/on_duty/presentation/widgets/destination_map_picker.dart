import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SelectedDestination {
  const SelectedDestination({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.radius = 200,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int radius;

  String get fullDisplayText {
    if (address.isNotEmpty && name != address) {
      return '$name, $address';
    }
    return name;
  }
}

class DestinationMapPickerScreen extends StatelessWidget {
  const DestinationMapPickerScreen({
    super.key,
    this.initialDestination,
    this.primaryColor = const Color(0xFF9CC70A),
    this.darkTextColor = const Color(0xFF414A51),
    this.apiKey,
  });

  final SelectedDestination? initialDestination;
  final Color primaryColor;
  final Color darkTextColor;
  final String? apiKey;

  @override
  Widget build(BuildContext context) {
    return DestinationMapPicker(
      initialDestination: initialDestination,
      isFullScreen: true,
      onDestinationSelected: (dest) {
        Navigator.of(context).pop(dest);
      },
      primaryColor: primaryColor,
      darkTextColor: darkTextColor,
      apiKey: apiKey,
    );
  }
}

class DestinationMapPicker extends StatefulWidget {
  const DestinationMapPicker({
    super.key,
    this.initialDestination,
    required this.onDestinationSelected,
    this.isFullScreen = true,
    this.primaryColor = const Color(0xFF9CC70A),
    this.darkTextColor = const Color(0xFF414A51),
    this.apiKey,
  });

  final SelectedDestination? initialDestination;
  final ValueChanged<SelectedDestination?> onDestinationSelected;
  final bool isFullScreen;
  final Color primaryColor;
  final Color darkTextColor;
  final String? apiKey;

  @override
  State<DestinationMapPicker> createState() => _DestinationMapPickerState();
}

class _DestinationMapPickerState extends State<DestinationMapPicker> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isSearching = false;
  bool _isLocatingUser = false;
  bool _hasLocationPermission = true;
  List<Map<String, dynamic>> _suggestions = [];

  // Places API session token (reused per search session)
  String? _sessionToken;

  // Currently selected / draft location
  String _selectedName = '';
  String _selectedAddress = '';
  double? _selectedLat;
  double? _selectedLng;
  int _selectedRadius = 200;
  bool _isApplied = false;

  // Native Google Map controller & state
  GoogleMapController? _googleMapController;
  static const String _envApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: String.fromEnvironment('MAPS_API_KEY', defaultValue: 'AIzaSyAUjhxMMfOFsi6mmwz2mn0ADjfLKnUY4wk'),
  );
  String get _googleMapsApiKey => (widget.apiKey?.isNotEmpty == true) ? widget.apiKey! : _envApiKey;
  String _mapType = 'roadmap'; // roadmap, satellite, terrain
  double _zoomLevel = 15.0;
  final List<int> _radiusOptions = [50, 100, 200, 500];

  late AnimationController _zoomAnimationController;

  void _animateZoomTo(double targetZoom) {
    _zoomLevel = targetZoom.clamp(10.0, 20.0);
    if (_googleMapController != null && _selectedLat != null && _selectedLng != null) {
      _googleMapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_selectedLat!, _selectedLng!), _zoomLevel),
      );
    }
    if (mounted) setState(() {});
  }

  MapType _getGoogleMapType(String mapType) {
    if (mapType == 'satellite') {
      return MapType.satellite;
    } else if (mapType == 'terrain') {
      return MapType.terrain;
    } else {
      return MapType.normal;
    }
  }

  Future<void> _openInGoogleMaps() async {
    final lat = _selectedLat;
    final lng = _selectedLng;
    if (lat == null || lng == null) return;
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    if (widget.initialDestination != null) {
      _selectedName = widget.initialDestination!.name;
      _selectedAddress = widget.initialDestination!.address;
      _selectedLat = widget.initialDestination!.latitude;
      _selectedLng = widget.initialDestination!.longitude;
      _selectedRadius = widget.initialDestination!.radius;
      _searchController.text = _selectedName;
      _isApplied = true;
    } else {
      _selectedLat = 13.0827;
      _selectedLng = 80.2707;
      _selectedName = 'Current Location';
      _selectedAddress = 'Detecting current GPS location...';
      _searchController.text = '';
      _fetchCurrentGpsLocation(isAuto: true);
    }
  }

  @override
  void dispose() {
    _zoomAnimationController.dispose();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _sessionToken = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performPlaceSearch(query.trim());
    });
  }

  Future<void> _performPlaceSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }

    // Generate session token for search session if missing
    _sessionToken ??= '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(99999)}';

    setState(() => _isSearching = true);

    try {
      final List<Map<String, dynamic>> results = [];

      // 1. Direct coordinates check
      final latLngRegExp = RegExp(r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)');
      final coordMatch = latLngRegExp.firstMatch(query);
      if (coordMatch != null) {
        final parsedLat = double.tryParse(coordMatch.group(1)!);
        final parsedLng = double.tryParse(coordMatch.group(2)!);
        if (parsedLat != null && parsedLng != null) {
          results.add({
            'name': 'Pasted Location ($parsedLat, $parsedLng)',
            'address': 'Direct coordinates',
            'place_id': null,
            'lat': parsedLat,
            'lng': parsedLng,
          });
        }
      }

      final encoded = Uri.encodeComponent(query);

      // 2. Query Google Places Autocomplete API with session token, location bias & region preference
      if (_googleMapsApiKey.isNotEmpty) {
        try {
          String locationBias = '';
          if (_selectedLat != null && _selectedLng != null) {
            locationBias = '&location=$_selectedLat,$_selectedLng&radius=50000';
          }

          final autocompleteUrl = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encoded$locationBias&components=country:in&sessiontoken=$_sessionToken&key=$_googleMapsApiKey',
          );

          final autoResp = await http.get(autocompleteUrl).timeout(const Duration(seconds: 4));
          if (autoResp.statusCode == 200) {
            final Map<String, dynamic> autoData = jsonDecode(autoResp.body);
            final status = (autoData['status'] ?? '').toString();

            if (status == 'OK') {
              final predictions = autoData['predictions'] as List<dynamic>? ?? [];
              for (final pred in predictions) {
                final description = (pred['description'] ?? '').toString();
                final placeId = (pred['place_id'] ?? '').toString();
                final mainText = pred['structured_formatting']?['main_text']?.toString() ?? description.split(',').first.trim();
                final secondaryText = pred['structured_formatting']?['secondary_text']?.toString() ??
                    (description.contains(',') ? description.substring(description.indexOf(',') + 1).trim() : description);

                if (placeId.isNotEmpty) {
                  results.add({
                    'name': mainText,
                    'address': secondaryText,
                    'place_id': placeId,
                    'lat': null,
                    'lng': null,
                  });
                }
              }
            }
          }
        } catch (_) {}
      }

      // 3. Fallback Autocomplete (Photon & Nominatim)
      if (results.length < 5) {
        try {
          final photonUrl = Uri.parse('https://photon.komoot.io/api/?q=$encoded&limit=8');
          final photonResp = await http.get(photonUrl).timeout(const Duration(seconds: 4));
          if (photonResp.statusCode == 200) {
            final Map<String, dynamic> photonData = jsonDecode(photonResp.body);
            final features = photonData['features'] as List<dynamic>? ?? [];
            for (final feat in features) {
              final props = feat['properties'] as Map<String, dynamic>? ?? {};
              final geom = feat['geometry'] as Map<String, dynamic>? ?? {};
              final coords = geom['coordinates'] as List<dynamic>? ?? [];

              if (coords.length >= 2) {
                final lng = double.tryParse(coords[0].toString());
                final lat = double.tryParse(coords[1].toString());

                final String name = (props['name'] ?? props['street'] ?? props['district'] ?? props['city'] ?? query).toString();
                
                final List<String> addrComponents = [];
                if (props['street'] != null && props['street'] != name) addrComponents.add(props['street'].toString());
                if (props['district'] != null && props['district'] != name) addrComponents.add(props['district'].toString());
                if (props['city'] != null && props['city'] != name) addrComponents.add(props['city'].toString());
                if (props['state'] != null) addrComponents.add(props['state'].toString());
                if (props['country'] != null) addrComponents.add(props['country'].toString());

                final String secondaryAddress = addrComponents.isNotEmpty ? addrComponents.join(', ') : 'Location';

                if (lat != null && lng != null && name.isNotEmpty) {
                  final bool isDuplicate = results.any((r) =>
                    r['name'].toString().toLowerCase() == name.toLowerCase() &&
                    (r['lat'] == lat || (r['lat'] != null && ((r['lat'] as double) - lat).abs() < 0.001)));

                  if (!isDuplicate) {
                    results.add({
                      'name': name,
                      'address': secondaryAddress,
                      'place_id': null,
                      'lat': lat,
                      'lng': lng,
                    });
                  }
                }
              }
            }
          }
        } catch (_) {}
      }

      if (results.length < 5) {
        try {
          final nomUrl = Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=$encoded&addressdetails=1&limit=8&dedupe=0',
          );
          final nomResp = await http.get(
            nomUrl,
            headers: {'User-Agent': 'GreenTechnologyApp/1.0'},
          ).timeout(const Duration(seconds: 4));

          if (nomResp.statusCode == 200) {
            final List<dynamic> nomList = jsonDecode(nomResp.body);
            for (final item in nomList) {
              final displayName = (item['display_name'] ?? '').toString();
              final lat = double.tryParse(item['lat']?.toString() ?? '');
              final lng = double.tryParse(item['lon']?.toString() ?? '');
              if (displayName.isNotEmpty && lat != null && lng != null) {
                final parts = displayName.split(',');
                final mainName = parts.isNotEmpty ? parts.first.trim() : displayName;
                final subAddr = parts.length > 1 ? parts.sublist(1).join(',').trim() : displayName;

                final bool isDuplicate = results.any((r) =>
                  r['name'].toString().toLowerCase() == mainName.toLowerCase() ||
                  (r['lat'] != null && ((r['lat'] as double) - lat).abs() < 0.0001));

                if (!isDuplicate) {
                  results.add({
                    'name': mainName,
                    'address': subAddr,
                    'place_id': null,
                    'lat': lat,
                    'lng': lng,
                  });
                }
              }
            }
          }
        } catch (_) {}
      }

      if (results.isEmpty) {
        results.add({
          'name': 'No places found for "$query"',
          'address': 'Try typing another landmark, street, or city name',
          'place_id': null,
          'isInfo': true,
        });
      }

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [
            {
              'name': 'Search Error',
              'address': 'Could not fetch places: $e',
              'place_id': null,
              'isError': true,
            }
          ];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> item) async {
    if (item['isError'] == true || item['isInfo'] == true) return;

    _searchFocusNode.unfocus();

    // 1. Direct coordinates available
    if (item['lat'] != null && item['lng'] != null) {
      final double lat = (item['lat'] as num).toDouble();
      final double lng = (item['lng'] as num).toDouble();
      final String name = item['name'].toString();
      final String address = item['address'].toString();

      setState(() {
        _selectedLat = lat;
        _selectedLng = lng;
        _selectedName = name;
        _selectedAddress = address;
        _searchController.text = _selectedName;
        _suggestions = [];
        _zoomLevel = 16.0;
        _isApplied = false;
        _sessionToken = null;
      });

      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.0),
      );
      return;
    }

    // 2. Fetch Place Details on-demand passing session token to close session
    final placeId = item['place_id']?.toString();
    if (placeId != null && placeId.isNotEmpty) {
      final activeSessionToken = _sessionToken;
      _sessionToken = null; // Reset for next search session

      setState(() {
        _isSearching = true;
        _searchController.text = item['name'].toString();
        _suggestions = [];
      });

      try {
        double? lat;
        double? lng;
        String name = item['name'].toString();
        String address = item['address'].toString();

        if (_googleMapsApiKey.isNotEmpty) {
          String tokenParam = activeSessionToken != null ? '&sessiontoken=$activeSessionToken' : '';
          final detailsUrl = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,name,formatted_address$tokenParam&key=$_googleMapsApiKey',
          );
          final resp = await http.get(detailsUrl).timeout(const Duration(seconds: 5));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            if (data['status'] == 'OK') {
              final result = data['result'];
              final location = result?['geometry']?['location'];
              lat = double.tryParse(location?['lat']?.toString() ?? '');
              lng = double.tryParse(location?['lng']?.toString() ?? '');
              final formattedAddr = result?['formatted_address']?.toString();
              if (formattedAddr != null && formattedAddr.isNotEmpty) {
                address = formattedAddr;
              }
              final placeName = result?['name']?.toString();
              if (placeName != null && placeName.isNotEmpty) {
                name = placeName;
              }
            }
          }
        }

        // OpenStreetMap Nominatim Geocoding fallback if lat/lng is null
        if ((lat == null || lng == null) && name.isNotEmpty) {
          try {
            final nomUrl = Uri.parse(
              'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent('$name $address')}&limit=1',
            );
            final nomResp = await http.get(
              nomUrl,
              headers: {'User-Agent': 'GreenTechnologyApp/1.0'},
            ).timeout(const Duration(seconds: 4));
            if (nomResp.statusCode == 200) {
              final List<dynamic> nomList = jsonDecode(nomResp.body);
              if (nomList.isNotEmpty) {
                lat = double.tryParse(nomList.first['lat']?.toString() ?? '');
                lng = double.tryParse(nomList.first['lon']?.toString() ?? '');
              }
            }
          } catch (_) {}
        }

        if (lat != null && lng != null && mounted) {
          setState(() {
            _selectedLat = lat;
            _selectedLng = lng;
            _selectedName = name;
            _selectedAddress = address;
            _searchController.text = name;
            _suggestions = [];
            _isSearching = false;
            _zoomLevel = 16.0;
            _isApplied = false;
          });

          _googleMapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.0),
          );
        } else if (mounted) {
          setState(() => _isSearching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not fetch location coordinates for selected place.')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching place location: $e')),
          );
        }
      } finally {
        _searchFocusNode.unfocus();
      }
    }
  }

  Future<void> _fetchCurrentGpsLocation({bool isAuto = false}) async {
    if (mounted) setState(() => _isLocatingUser = true);
    try {
      Position? position;

      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            try {
              position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 4),
                ),
              );
            } catch (_) {}

            position ??= await Geolocator.getLastKnownPosition();
          } else {
            _hasLocationPermission = false;
          }
        } else {
          _hasLocationPermission = false;
        }
      } catch (_) {
        _hasLocationPermission = false;
      }

      if (position != null && mounted) {
        await _applyGpsCoordinates(position.latitude, position.longitude);
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 16.0),
        );
        if (!isAuto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Updated to current GPS location'), duration: Duration(seconds: 2)),
          );
        }
        return;
      }

      // IP Geolocation Fallback
      double? ipLat;
      double? ipLng;
      String ipCity = '';
      String ipRegion = '';

      try {
        final ipUrl = Uri.parse('https://ipapi.co/json/');
        final ipResp = await http.get(ipUrl).timeout(const Duration(seconds: 4));
        if (ipResp.statusCode == 200) {
          final ipData = jsonDecode(ipResp.body);
          ipLat = double.tryParse(ipData['latitude']?.toString() ?? '');
          ipLng = double.tryParse(ipData['longitude']?.toString() ?? '');
          ipCity = (ipData['city'] ?? '').toString();
          ipRegion = (ipData['region'] ?? ipData['country_name'] ?? '').toString();
        }
      } catch (_) {}

      if (ipLat == null || ipLng == null) {
        try {
          final ipUrl2 = Uri.parse('http://ip-api.com/json/');
          final ipResp2 = await http.get(ipUrl2).timeout(const Duration(seconds: 4));
          if (ipResp2.statusCode == 200) {
            final ipData2 = jsonDecode(ipResp2.body);
            ipLat = double.tryParse(ipData2['lat']?.toString() ?? '');
            ipLng = double.tryParse(ipData2['lon']?.toString() ?? '');
            ipCity = (ipData2['city'] ?? '').toString();
            ipRegion = (ipData2['regionName'] ?? ipData2['country'] ?? '').toString();
          }
        } catch (_) {}
      }

      if (ipLat != null && ipLng != null && mounted) {
        await _applyGpsCoordinates(ipLat, ipLng);
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(ipLat, ipLng), 15.0),
        );
        if (!isAuto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Located area: ${ipCity.isNotEmpty ? "$ipCity, $ipRegion" : "Current Location"}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (!isAuto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location service unavailable. You can search or drag map to select location.')),
        );
      }
    } catch (e) {
      if (!isAuto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location notice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingUser = false);
    }
  }

  Future<void> _applyGpsCoordinates(double lat, double lng) async {
    String name = 'Current Location';
    String addr = 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';

    // 1. Google Reverse Geocoding
    if (_googleMapsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey',
        );
        final resp = await http.get(url).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          if (data['status'] == 'OK') {
            final results = data['results'] as List<dynamic>? ?? [];
            if (results.isNotEmpty) {
              final formattedAddr = (results.first['formatted_address'] ?? '').toString();
              final parts = formattedAddr.split(',');
              name = parts.isNotEmpty ? parts.first.trim() : 'Current Location';
              addr = parts.length > 1 ? parts.sublist(1).join(',').trim() : formattedAddr;
            }
          }
        }
      } catch (_) {}
    }

    // 2. OpenStreetMap Nominatim Reverse Geocoding Fallback
    if (name == 'Current Location' || name.startsWith('Current GPS Location')) {
      try {
        final nomUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1',
        );
        final nomResp = await http.get(
          nomUrl,
          headers: {'User-Agent': 'GreenTechnologyApp/1.0'},
        ).timeout(const Duration(seconds: 4));

        if (nomResp.statusCode == 200) {
          final nomData = jsonDecode(nomResp.body);
          final displayName = (nomData['display_name'] ?? '').toString();
          if (displayName.isNotEmpty) {
            final parts = displayName.split(',');
            name = parts.isNotEmpty ? parts.first.trim() : 'Current Location';
            addr = parts.length > 1 ? parts.sublist(1).join(',').trim() : displayName;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _selectedLat = lat;
        _selectedLng = lng;
        _selectedName = name;
        _selectedAddress = addr;
        if (!_searchFocusNode.hasFocus) {
          _searchController.text = name;
        }
        _isApplied = false;
      });
    }
  }

  Future<void> _showManualCoordinatesDialog() async {
    final latController = TextEditingController(text: _selectedLat?.toStringAsFixed(6) ?? '');
    final lngController = TextEditingController(text: _selectedLng?.toStringAsFixed(6) ?? '');

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_location_alt_rounded, color: Color(0xFF9CC70A), size: 22),
            SizedBox(width: 8),
            Text(
              'Enter Exact Coordinates',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste or type exact latitude & longitude for the site location:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: latController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g. 13.024993',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lngController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g. 80.157596',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9CC70A),
              foregroundColor: const Color(0xFF414A51),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () {
              final lat = double.tryParse(latController.text.trim());
              final lng = double.tryParse(lngController.text.trim());
              if (lat != null && lng != null) {
                Navigator.pop(ctx, {'lat': lat, 'lng': lng});
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Invalid latitude or longitude coordinates')),
                );
              }
            },
            child: const Text('Set Location', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLat = result['lat'];
        _selectedLng = result['lng'];
        _selectedAddress = 'Exact Coordinates: ${result['lat']!.toStringAsFixed(6)}, ${result['lng']!.toStringAsFixed(6)}';
        _isApplied = false;
      });
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(result['lat']!, result['lng']!), 16.0),
      );
    }
  }

  void _applyDestination() {
    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination first.')),
      );
      return;
    }

    final dest = SelectedDestination(
      name: _selectedName.isNotEmpty ? _selectedName : _searchController.text.trim(),
      address: _selectedAddress,
      latitude: _selectedLat!,
      longitude: _selectedLng!,
      radius: _selectedRadius,
    );

    setState(() => _isApplied = true);
    widget.onDestinationSelected(dest);
  }

  void _editDestination() {
    setState(() {
      _isApplied = false;
    });
  }

  void _nudgeLocation(double latDelta, double lngDelta) {
    final curLat = _selectedLat ?? 13.0827;
    final curLng = _selectedLng ?? 80.2707;
    final newLat = (curLat + latDelta).clamp(-50.0, 50.0);
    final newLng = (curLng + lngDelta).clamp(-180.0, 180.0);
    _applyGpsCoordinates(newLat, newLng);
    _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(newLat, newLng), _zoomLevel),
    );
  }

  Widget _buildArrowNudgeBtn({required IconData icon, required VoidCallback onPressed, String? tooltip}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Icon(icon, size: 16, color: const Color(0xFF414A51)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFullScreen) {
      if (_isApplied && _selectedLat != null && _selectedLng != null) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Text(
                        'Destination Selected',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildAppliedSummary(),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: widget.darkTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final dest = SelectedDestination(
                          name: _selectedName,
                          address: _selectedAddress,
                          latitude: _selectedLat!,
                          longitude: _selectedLng!,
                          radius: _selectedRadius,
                        );
                        widget.onDestinationSelected(dest);
                      },
                      child: const Text('Confirm & Return', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: const Color(0xFFE2E8F0),
        body: SafeArea(
          child: Stack(
            children: [
              // 1. Full-Screen Interactive Map Canvas (Background)
              Positioned.fill(
                child: _buildInteractiveMapCanvas(),
              ),

              // 2. Floating Top Search Card (Overlaying Map)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _buildFloatingSearchCard(context),
              ),

              // 3. Floating Autocomplete Search Suggestions Dropdown Overlay
              if (_suggestions.isNotEmpty)
                Positioned(
                  top: 72,
                  left: 12,
                  right: 12,
                  child: _buildSuggestionsOverlay(),
                ),

              // 4. Floating Map Type Controls (Top Right overlay under search card)
              if (_suggestions.isEmpty)
                Positioned(
                  top: 74,
                  right: 12,
                  child: _buildFloatingMapTypeSwitcher(),
                ),

              // 5. Floating Controls Column on Right (Current Location + Zoom Buttons)
              Positioned(
                bottom: 220,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingLocationButton(),
                    const SizedBox(height: 10),
                    _buildFloatingZoomControls(),
                  ],
                ),
              ),

              // 6. Floating Bottom Target Destination & Geofence Control Sheet Card
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomControlSheet(),
              ),
            ],
          ),
        ),
      );
    }

    if (_isApplied && _selectedLat != null && _selectedLng != null) {
      return _buildAppliedSummary();
    }

    return SizedBox(
      height: 600,
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildInteractiveMapCanvas(),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _buildFloatingSearchCard(context),
          ),
          if (_suggestions.isNotEmpty)
            Positioned(
              top: 72,
              left: 12,
              right: 12,
              child: _buildSuggestionsOverlay(),
            ),
          if (_suggestions.isEmpty)
            Positioned(
              top: 74,
              right: 12,
              child: _buildFloatingMapTypeSwitcher(),
            ),
          Positioned(
            bottom: 220,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingLocationButton(),
                const SizedBox(height: 10),
                _buildFloatingZoomControls(),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControlSheet(),
          ),
        ],
      ),
    );
  }

  /// Floating Google Maps style search bar card
  Widget _buildFloatingSearchCard(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51), size: 22),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: const InputDecoration(
                  hintText: 'Search destination, site, place...',
                  hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF9CC70A)),
                ),
              )
            else if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _suggestions = [];
                    _sessionToken = null;
                  });
                },
                tooltip: 'Clear search',
              ),
            IconButton(
              icon: _isLocatingUser
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF414A51)),
                    )
                  : const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF414A51)),
              tooltip: 'Current GPS Location',
              onPressed: _isLocatingUser ? null : _fetchCurrentGpsLocation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsOverlay() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _suggestions.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (ctx, i) {
            final item = _suggestions[i];
            final isError = item['isError'] == true;
            final isInfo = item['isInfo'] == true;

            final IconData icon = isError
                ? Icons.warning_amber_rounded
                : (isInfo ? Icons.search_off_rounded : Icons.location_on_rounded);
            final Color iconColor = isError
                ? const Color(0xFFDC2626)
                : (isInfo ? const Color(0xFF64748B) : const Color(0xFFE11D48));

            return ListTile(
              dense: true,
              leading: Icon(icon, size: 18, color: iconColor),
              title: Text(
                item['name'].toString(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isError ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item['address'].toString(),
                style: TextStyle(fontSize: 11, color: isError ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: (isError || isInfo) ? null : () => _selectSuggestion(item),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingMapTypeSwitcher() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMapTypeTab('Map', 'roadmap'),
            _buildMapTypeTab('Satellite', 'satellite'),
            _buildMapTypeTab('Terrain', 'terrain'),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingLocationButton() {
    return Material(
      elevation: 5,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        onTap: _isLocatingUser ? null : () => _fetchCurrentGpsLocation(),
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _isLocatingUser
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF414A51)),
                )
              : const Icon(Icons.gps_fixed_rounded, size: 20, color: Color(0xFF414A51)),
        ),
      ),
    );
  }

  Widget _buildFloatingZoomControls() {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF414A51)),
            tooltip: 'Zoom In',
            onPressed: () => _animateZoomTo(_zoomLevel + 0.5),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            padding: EdgeInsets.zero,
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 20, color: Color(0xFF414A51)),
            tooltip: 'Zoom Out',
            onPressed: () => _animateZoomTo(_zoomLevel - 0.5),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMapCanvas() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE2E8F0),
      child: Stack(
        children: [
          // Layer 1: Guaranteed Interactive Google Map Renderer Engine
          Positioned.fill(
            child: _RealTileMapWidget(
              lat: _selectedLat ?? 13.0827,
              lng: _selectedLng ?? 80.2707,
              zoom: _zoomLevel,
              mapType: _mapType,
              radius: _selectedRadius,
              primaryColor: widget.primaryColor,
              onCameraMoved: (newLat, newLng, newZoom) {
                setState(() {
                  _selectedLat = newLat;
                  _selectedLng = newLng;
                  _zoomLevel = newZoom;
                });
              },
              onCameraIdle: () {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  if (mounted && _selectedLat != null && _selectedLng != null) {
                    _applyGpsCoordinates(_selectedLat!, _selectedLng!);
                  }
                });
              },
            ),
          ),

          // Layer 2: Fixed Destination Pin at Screen Center
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF414A51),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _selectedName.isNotEmpty ? _selectedName : 'Target Location',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.location_pin,
                    size: 38,
                    color: Color(0xFFDC2626),
                  ),
                ],
              ),
            ),
          ),

          // Layer 3: Open in Google Maps Floating Button (Bottom Left over map)
          Positioned(
            bottom: 220,
            left: 12,
            child: InkWell(
              onTap: _openInGoogleMaps,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF414A51)),
                    SizedBox(width: 4),
                    Text(
                      'Open Google Maps',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF414A51),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Target Destination & Geofence Control Sheet Overlay
  Widget _buildBottomControlSheet() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Target Destination Pin Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedName.isNotEmpty ? _selectedName : 'Selected Target Location',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedAddress.isNotEmpty
                            ? _selectedAddress
                            : (_selectedLat != null && _selectedLng != null
                                ? '${_selectedLat!.toStringAsFixed(5)}, ${_selectedLng!.toStringAsFixed(5)}'
                                : 'Select location on map'),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Arrow Nudge Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildArrowNudgeBtn(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Nudge Left (West)',
                        onPressed: () => _nudgeLocation(0.0, -0.0001),
                      ),
                      _buildArrowNudgeBtn(
                        icon: Icons.arrow_upward_rounded,
                        tooltip: 'Nudge Up (North)',
                        onPressed: () => _nudgeLocation(0.0001, 0.0),
                      ),
                      _buildArrowNudgeBtn(
                        icon: Icons.arrow_downward_rounded,
                        tooltip: 'Nudge Down (South)',
                        onPressed: () => _nudgeLocation(-0.0001, 0.0),
                      ),
                      _buildArrowNudgeBtn(
                        icon: Icons.arrow_forward_rounded,
                        tooltip: 'Nudge Right (East)',
                        onPressed: () => _nudgeLocation(0.0, 0.0001),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: _showManualCoordinatesDialog,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF414A51)),
                  label: const Text('Edit', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Allowed Geofence Radius Selector (50m, 100m, 200m, 500m)
          Row(
            children: [
              const Text(
                'Allowed Radius:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _radiusOptions.map((r) {
                      final isSel = _selectedRadius == r;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(() => _selectedRadius = r),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSel ? widget.primaryColor : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSel ? widget.primaryColor : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              '$r m',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                color: isSel ? widget.darkTextColor : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // APPLY DESTINATION Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selectedLat != null && _selectedLng != null) ? _applyDestination : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: widget.darkTextColor,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text(
                '[ APPLY DESTINATION ]',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTypeTab(String title, String type) {
    final isSel = _mapType == type;
    return InkWell(
      onTap: () => setState(() => _mapType = type),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? widget.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
            color: isSel ? widget.darkTextColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildAppliedSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Destination Selected ✓',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF15803D),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _editDestination,
                icon: const Icon(Icons.edit_location_alt, size: 14, color: Color(0xFF414A51)),
                label: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const Divider(height: 14, color: Color(0xFFBBF7D0)),
          Text(
            _selectedName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          if (_selectedAddress.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _selectedAddress,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  'GPS: ${_selectedLat!.toStringAsFixed(4)}°, ${_selectedLng!.toStringAsFixed(4)}°',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  'Geofence: within $_selectedRadius m',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _openInGoogleMaps,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 14, color: Color(0xFF414A51)),
                    SizedBox(width: 4),
                    Text(
                      'View on Map',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RealTileMapWidget extends StatefulWidget {
  const _RealTileMapWidget({
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.mapType,
    required this.radius,
    required this.primaryColor,
    required this.onCameraMoved,
    required this.onCameraIdle,
  });

  final double lat;
  final double lng;
  final double zoom;
  final String mapType;
  final int radius;
  final Color primaryColor;
  final Function(double newLat, double newLng, double newZoom) onCameraMoved;
  final VoidCallback onCameraIdle;

  @override
  State<_RealTileMapWidget> createState() => _RealTileMapWidgetState();
}

class _RealTileMapWidgetState extends State<_RealTileMapWidget> {
  double _baseScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final double zoom = widget.zoom;
        final double lat = widget.lat;
        final double lng = widget.lng;

        final int z = zoom.floor().clamp(2, 19);
        final double tileSize = 256.0 * math.pow(2, zoom - z);

        final double sinLat = math.sin(lat * math.pi / 180.0);
        final double worldX = ((lng + 180.0) / 360.0) * math.pow(2, z);
        final double worldY = ((0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi))) * math.pow(2, z);

        final int centerTileX = worldX.floor();
        final int centerTileY = worldY.floor();

        final int numTilesX = (width / tileSize).ceil() + 2;
        final int numTilesY = (height / tileSize).ceil() + 2;

        final int startX = centerTileX - (numTilesX / 2).floor();
        final int startY = centerTileY - (numTilesY / 2).floor();

        String lyrs = 'm';
        if (widget.mapType == 'satellite') {
          lyrs = 'y';
        } else if (widget.mapType == 'terrain') {
          lyrs = 'p';
        }

        final List<Widget> tileWidgets = [];

        for (int x = startX; x <= startX + numTilesX; x++) {
          for (int y = startY; y <= startY + numTilesY; y++) {
            if (y < 0 || y >= (1 << z)) continue;
            final int wrappedX = (x % (1 << z) + (1 << z)) % (1 << z);

            final double left = (width / 2.0) + (x - worldX) * tileSize;
            final double top = (height / 2.0) + (y - worldY) * tileSize;

            tileWidgets.add(
              Positioned(
                left: left,
                top: top,
                width: tileSize + 0.5,
                height: tileSize + 0.5,
                child: Image.network(
                  'https://mt1.google.com/vt/lyrs=$lyrs&x=$wrappedX&y=$y&z=$z',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE2E8F0)),
                ),
              ),
            );
          }
        }

        return GestureDetector(
          onDoubleTap: () {
            widget.onCameraMoved(lat, lng, (zoom + 1.0).clamp(3.0, 19.0));
            widget.onCameraIdle();
          },
          onScaleStart: (_) {
            _baseScale = 1.0;
          },
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              final double newZoom = (zoom + (details.scale > _baseScale ? 0.08 : -0.08)).clamp(3.0, 19.0);
              _baseScale = details.scale;
              widget.onCameraMoved(lat, lng, newZoom);
            } else if (details.focalPointDelta != Offset.zero) {
              final double metersPerPixel = (156543.03392 * math.cos(lat * math.pi / 180.0)) / math.pow(2, zoom);
              final double latDelta = (details.focalPointDelta.dy * metersPerPixel) / 111320.0;
              final double lngDelta = -(details.focalPointDelta.dx * metersPerPixel) / (111320.0 * math.cos(lat * math.pi / 180.0));

              final double newLat = (lat + latDelta).clamp(-85.0, 85.0);
              final double newLng = (lng + lngDelta).clamp(-180.0, 180.0);
              widget.onCameraMoved(newLat, newLng, zoom);
            }
          },
          onScaleEnd: (_) {
            widget.onCameraIdle();
          },
          child: Stack(
            children: [
              ...tileWidgets,
              Positioned.fill(
                child: CustomPaint(
                  painter: _GeofenceCirclePainter(
                    radiusMeters: widget.radius.toDouble(),
                    zoom: zoom,
                    lat: lat,
                    primaryColor: widget.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GeofenceCirclePainter extends CustomPainter {
  _GeofenceCirclePainter({
    required this.radiusMeters,
    required this.zoom,
    required this.lat,
    required this.primaryColor,
  });

  final double radiusMeters;
  final double zoom;
  final double lat;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double metersPerPixel = (156543.03392 * math.cos(lat * math.pi / 180.0)) / math.pow(2, zoom);
    final double radiusPixels = radiusMeters / metersPerPixel;

    final fillPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radiusPixels, fillPaint);
    canvas.drawCircle(center, radiusPixels, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _GeofenceCirclePainter oldDelegate) {
    return oldDelegate.radiusMeters != radiusMeters ||
        oldDelegate.zoom != zoom ||
        oldDelegate.lat != lat ||
        oldDelegate.primaryColor != primaryColor;
  }
}
