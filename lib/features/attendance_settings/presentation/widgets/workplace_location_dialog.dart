import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_settings.dart';
import 'attendance_location_fields.dart';

class WorkplaceLocationDialog extends StatefulWidget {
  const WorkplaceLocationDialog({
    super.key,
    this.location,
  });

  final AttendanceLocationItem? location;

  @override
  State<WorkplaceLocationDialog> createState() => _WorkplaceLocationDialogState();
}

class _WorkplaceLocationDialogState extends State<WorkplaceLocationDialog> {
  static const String _defaultApiKey = 'AIzaSyCRV3CEy0trgd_EGdX4L6D1tvhJ_GOKxO0';
  static const String _googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: String.fromEnvironment('MAPS_API_KEY', defaultValue: _defaultApiKey),
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;
  final TextEditingController _searchController = TextEditingController();

  late bool _requireGps;

  // Map state
  double _currentLat = 13.024880;
  double _currentLng = 80.157564;
  double _zoomLevel = 15.0;
  double? _userGpsLat;
  double? _userGpsLng;

  // Search state
  bool _isSearching = false;
  List<Map<String, dynamic>> _placeSuggestions = [];
  Timer? _searchDebounce;
  String? _sessionToken;

  bool _fetchingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    final loc = widget.location;
    _nameController = TextEditingController(text: loc?.name ?? '');

    final initialLat = (loc != null && loc.latitude != 0) ? loc.latitude : 13.024880;
    final initialLng = (loc != null && loc.longitude != 0) ? loc.longitude : 80.157564;
    _currentLat = initialLat;
    _currentLng = initialLng;

    _latController = TextEditingController(
      text: loc != null && loc.latitude != 0 ? loc.latitude.toStringAsFixed(6) : initialLat.toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text: loc != null && loc.longitude != 0 ? loc.longitude.toStringAsFixed(6) : initialLng.toStringAsFixed(6),
    );
    _radiusController = TextEditingController(
      text: (loc?.radiusMeters ?? 500).toString(),
    );
    _requireGps = loc?.requireGpsVerification ?? true;

    _latController.addListener(_onManualCoordinatesChanged);
    _lngController.addListener(_onManualCoordinatesChanged);
    _radiusController.addListener(() {
      if (mounted) setState(() {});
    });

    _fetchUserGpsSilently();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _latController.removeListener(_onManualCoordinatesChanged);
    _lngController.removeListener(_onManualCoordinatesChanged);
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onManualCoordinatesChanged() {
    final lat = AttendanceLocationFields.parseCoordinate(_latController.text);
    final lng = AttendanceLocationFields.parseCoordinate(_lngController.text);
    if (lat != null && lng != null) {
      if ((_currentLat - lat).abs() > 0.000001 || (_currentLng - lng).abs() > 0.000001) {
        setState(() {
          _currentLat = lat;
          _currentLng = lng;
        });
      }
    }
  }

  Future<void> _fetchUserGpsSilently() async {
    try {
      if (!kIsWeb) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (mounted) {
          setState(() {
            _userGpsLat = pos.latitude;
            _userGpsLng = pos.longitude;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _useCurrentLocation() async {
    if (_fetchingCurrentLocation) return;
    setState(() => _fetchingCurrentLocation = true);

    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled on this device.')),
          );
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission was denied.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      setState(() {
        _userGpsLat = position.latitude;
        _userGpsLng = position.longitude;
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
        _zoomLevel = 16.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordinates updated from current GPS location.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get GPS location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _fetchingCurrentLocation = false);
      }
    }
  }

  void _resetCoordinates() {
    final loc = widget.location;
    final initialLat = (loc != null && loc.latitude != 0) ? loc.latitude : 13.024880;
    final initialLng = (loc != null && loc.longitude != 0) ? loc.longitude : 80.157564;
    setState(() {
      _currentLat = initialLat;
      _currentLng = initialLng;
      _latController.text = initialLat.toStringAsFixed(6);
      _lngController.text = initialLng.toStringAsFixed(6);
      _radiusController.text = (loc?.radiusMeters ?? 500).toString();
      _searchController.clear();
      _placeSuggestions = [];
      _zoomLevel = 15.0;
    });
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _placeSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchGooglePlaces(query.trim());
    });
  }

  Future<void> _searchGooglePlaces(String query) async {
    _sessionToken ??= '${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _isSearching = true);

    try {
      final uri = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
      final Map<String, dynamic> payload = {
        'input': query,
        'includedRegionCodes': ['in'],
        'sessionToken': _sessionToken,
        'locationBias': {
          'circle': {
            'center': {'latitude': _currentLat, 'longitude': _currentLng},
            'radius': 50000.0,
          }
        },
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleMapsApiKey,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestions = data['suggestions'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> results = [];

        for (final item in suggestions) {
          final pred = item['placePrediction'];
          if (pred != null) {
            final placeId = (pred['placeId'] ?? '').toString();
            final fullText = (pred['text']?['text'] ?? '').toString();
            final mainText = (pred['structuredFormat']?['mainText']?['text'] ?? fullText).toString();
            final secondaryText = (pred['structuredFormat']?['secondaryText']?['text'] ?? '').toString();

            if (placeId.isNotEmpty) {
              results.add({
                'place_id': placeId,
                'name': mainText,
                'address': secondaryText.isNotEmpty ? secondaryText : fullText,
              });
            }
          }
        }

        if (mounted) {
          setState(() {
            _placeSuggestions = results;
            _isSearching = false;
          });
        }
      } else {
        if (mounted) setState(() => _isSearching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPlaceSuggestion(Map<String, dynamic> item) async {
    final placeId = item['place_id'] as String;
    final placeName = item['name'] as String;
    setState(() {
      _isSearching = true;
      _placeSuggestions = [];
      _searchController.text = placeName;
    });

    try {
      final detailsUri = Uri.parse(
        'https://places.googleapis.com/v1/places/$placeId?sessionToken=$_sessionToken',
      );
      final resp = await http.get(
        detailsUri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleMapsApiKey,
          'X-Goog-FieldMask': 'id,displayName,location,formattedAddress',
        },
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final location = data['location'];
        final lat = double.tryParse(location?['latitude']?.toString() ?? '');
        final lng = double.tryParse(location?['longitude']?.toString() ?? '');

        if (lat != null && lng != null && mounted) {
          setState(() {
            _currentLat = lat;
            _currentLng = lng;
            _latController.text = lat.toStringAsFixed(6);
            _lngController.text = lng.toStringAsFixed(6);
            if (_nameController.text.trim().isEmpty) {
              _nameController.text = placeName;
            }
            _zoomLevel = 16.0;
            _sessionToken = null;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onMapTapped(double tappedLat, double tappedLng) {
    setState(() {
      _currentLat = tappedLat;
      _currentLng = tappedLng;
      _latController.text = tappedLat.toStringAsFixed(6);
      _lngController.text = tappedLng.toStringAsFixed(6);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final lat = AttendanceLocationFields.parseCoordinate(_latController.text) ?? 0.0;
    final lng = AttendanceLocationFields.parseCoordinate(_lngController.text) ?? 0.0;
    final radius = int.tryParse(_radiusController.text.trim()) ?? 500;

    final id = widget.location?.id.isNotEmpty == true
        ? widget.location!.id
        : 'loc_${DateTime.now().millisecondsSinceEpoch}';

    final result = AttendanceLocationItem(
      id: id,
      name: _nameController.text.trim(),
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
      requireGpsVerification: _requireGps,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.location != null;
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width >= 820;

    final dialogWidth = math.min(mediaQuery.size.width * 0.94, 960.0);
    final dialogMaxHeight = math.min(mediaQuery.size.height * 0.92, 700.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Green circle pin icon + Title + Close Button
            _buildDialogHeader(isEditing),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // Body: Split Columns on Web/Desktop, Scrollable stack on mobile
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Column (Form Inputs)
                        SizedBox(
                          width: 370,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            child: _buildFormFields(),
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                        // Right Column (Interactive Map + Search)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: _buildMapSection(),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormFields(),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 380,
                            child: _buildMapSection(),
                          ),
                        ],
                      ),
                    ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            // Bottom Action Buttons
            _buildFooterActions(isEditing),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isEditing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Edit Workplace Location' : 'Add Workplace Location',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.active,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 22),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workplace Name
          const Text(
            'Workplace Name *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.active,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontSize: 14, color: AppColors.active),
            decoration: InputDecoration(
              hintText: 'e.g. testing, Head Office',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.business_outlined, size: 20, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter a workplace name';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Use Current Location Button
          OutlinedButton.icon(
            onPressed: _fetchingCurrentLocation ? null : _useCurrentLocation,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _fetchingCurrentLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.my_location, size: 18),
            label: Text(
              _fetchingCurrentLocation ? 'Detecting GPS...' : 'Use Current Location',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),

          // Latitude
          const Text(
            'Latitude *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.active,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _latController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: const TextStyle(fontSize: 14, color: AppColors.active),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            validator: AttendanceLocationFields.validateCoordinate,
          ),
          const SizedBox(height: 14),

          // Longitude
          const Text(
            'Longitude *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.active,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _lngController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: const TextStyle(fontSize: 14, color: AppColors.active),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            validator: AttendanceLocationFields.validateCoordinate,
          ),
          const SizedBox(height: 14),

          // Allowed Radius (meters)
          const Text(
            'Allowed Radius (meters) *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.active,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _radiusController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14, color: AppColors.active),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.radar_outlined, size: 20, color: Color(0xFF64748B)),
              suffixIcon: Container(
                width: 44,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'm',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            validator: AttendanceLocationFields.validateRadius,
          ),
          const SizedBox(height: 18),

          // Require GPS Verification Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 22, color: AppColors.active),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Require GPS Verification',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.active,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Employees must be within the allowed radius to check in.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _requireGps,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                  onChanged: (val) => setState(() => _requireGps = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final radiusMeters = int.tryParse(_radiusController.text.trim()) ?? 500;
    final workplaceName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'testing';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search and Action Bar: "Search an address or place", "Locate me", "Reset"
        Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                // Search Input
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchQueryChanged,
                      style: const TextStyle(fontSize: 13, color: AppColors.active),
                      decoration: InputDecoration(
                        hintText: 'Search an address or place',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 19, color: Color(0xFF64748B)),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            : (_searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _placeSuggestions = []);
                                    },
                                    padding: EdgeInsets.zero,
                                  )
                                : null),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Locate me Button
                OutlinedButton.icon(
                  onPressed: _useCurrentLocation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Locate me', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),

                // Reset Button
                OutlinedButton.icon(
                  onPressed: _resetCoordinates,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),

            // Autocomplete Suggestions Dropdown
            if (_placeSuggestions.isNotEmpty)
              Positioned(
                top: 44,
                left: 0,
                right: 170,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _placeSuggestions.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, idx) {
                        final item = _placeSuggestions[idx];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on, size: 18, color: Color(0xFFEA4335)),
                          title: Text(
                            item['name'] ?? '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.active),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item['address'] ?? '',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectPlaceSuggestion(item),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Interactive Map Canvas with Geofence & Controls
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Stack(
                children: [
                  // Real Google Map Tile Renderer
                  Positioned.fill(
                    child: _WorkplaceInteractiveMap(
                      lat: _currentLat,
                      lng: _currentLng,
                      zoom: _zoomLevel,
                      radiusMeters: radiusMeters,
                      workplaceName: workplaceName,
                      userGpsLat: _userGpsLat,
                      userGpsLng: _userGpsLng,
                      onCoordinatesSelected: _onMapTapped,
                      onZoomChanged: (newZoom) => setState(() => _zoomLevel = newZoom),
                    ),
                  ),

                  // Floating Zoom Controls (+ / -) in bottom-right corner
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _zoomLevel = (_zoomLevel + 1.0).clamp(3.0, 19.0)),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Icon(Icons.add, size: 18, color: AppColors.active),
                            ),
                          ),
                          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                          InkWell(
                            onTap: () => setState(() => _zoomLevel = (_zoomLevel - 1.0).clamp(3.0, 19.0)),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Icon(Icons.remove, size: 18, color: AppColors.active),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Bottom Status Banner: "Office location selected"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Office location selected',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Drag the pin or click the map to adjust coordinates.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterActions(bool isEditing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: _submit,
            child: Text(
              isEditing ? 'Save Changes' : 'Add Location',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkplaceInteractiveMap extends StatefulWidget {
  const _WorkplaceInteractiveMap({
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.radiusMeters,
    required this.workplaceName,
    required this.onCoordinatesSelected,
    required this.onZoomChanged,
    this.userGpsLat,
    this.userGpsLng,
  });

  final double lat;
  final double lng;
  final double zoom;
  final int radiusMeters;
  final String workplaceName;
  final double? userGpsLat;
  final double? userGpsLng;
  final Function(double lat, double lng) onCoordinatesSelected;
  final ValueChanged<double> onZoomChanged;

  @override
  State<_WorkplaceInteractiveMap> createState() => _WorkplaceInteractiveMapState();
}

class _WorkplaceInteractiveMapState extends State<_WorkplaceInteractiveMap> {
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
                  'https://mt1.google.com/vt/lyrs=m&x=$wrappedX&y=$y&z=$z',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFE2E8F0)),
                ),
              ),
            );
          }
        }

        // Relative user position if available
        Widget? userLocationDot;
        if (widget.userGpsLat != null && widget.userGpsLng != null) {
          final uLat = widget.userGpsLat!;
          final uLng = widget.userGpsLng!;
          final uSinLat = math.sin(uLat * math.pi / 180.0);
          final uWorldX = ((uLng + 180.0) / 360.0) * math.pow(2, z);
          final uWorldY = ((0.5 - math.log((1.0 + uSinLat) / (1.0 - uSinLat)) / (4.0 * math.pi))) * math.pow(2, z);
          final uLeft = (width / 2.0) + (uWorldX - worldX) * tileSize;
          final uTop = (height / 2.0) + (uWorldY - worldY) * tileSize;

          if (uLeft >= -20 && uLeft <= width + 20 && uTop >= -20 && uTop <= height + 20) {
            userLocationDot = Positioned(
              left: uLeft - 8,
              top: uTop - 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
            );
          }
        }

        // Geofence radius in pixels
        final double metersPerPixel = (156543.03392 * math.cos(lat * math.pi / 180.0)) / math.pow(2, zoom);
        final double radiusPixels = widget.radiusMeters / metersPerPixel;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            // Convert clicked pixel coordinate to Latitude & Longitude
            final clickX = details.localPosition.dx;
            final clickY = details.localPosition.dy;
            final dx = clickX - (width / 2.0);
            final dy = clickY - (height / 2.0);

            final clickedWorldX = worldX + (dx / tileSize);
            final clickedWorldY = worldY + (dy / tileSize);

            final clickedLng = (clickedWorldX / math.pow(2, z)) * 360.0 - 180.0;
            final n = math.pi - 2.0 * math.pi * (clickedWorldY / math.pow(2, z));
            final clickedLat = (180.0 / math.pi) * math.atan(0.5 * (math.exp(n) - math.exp(-n)));

            widget.onCoordinatesSelected(
              clickedLat.clamp(-85.0, 85.0),
              clickedLng.clamp(-180.0, 180.0),
            );
          },
          onScaleStart: (_) => _baseScale = 1.0,
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              final newZoom = (zoom + (details.scale > _baseScale ? 0.08 : -0.08)).clamp(3.0, 19.0);
              _baseScale = details.scale;
              widget.onZoomChanged(newZoom);
            } else if (details.focalPointDelta != Offset.zero) {
              final mpp = (156543.03392 * math.cos(lat * math.pi / 180.0)) / math.pow(2, zoom);
              final latDelta = (details.focalPointDelta.dy * mpp) / 111320.0;
              final lngDelta = -(details.focalPointDelta.dx * mpp) / (111320.0 * math.cos(lat * math.pi / 180.0));

              widget.onCoordinatesSelected(
                (lat + latDelta).clamp(-85.0, 85.0),
                (lng + lngDelta).clamp(-180.0, 180.0),
              );
            }
          },
          child: Stack(
            children: [
              ...tileWidgets,

              // Geofence Radius Circle
              Positioned.fill(
                child: CustomPaint(
                  painter: _WorkplaceGeofencePainter(
                    radiusPixels: radiusPixels,
                    color: AppColors.primary,
                  ),
                ),
              ),

              // Radius Pill Badge on the circle bottom edge
              Positioned(
                left: width / 2.0,
                top: (height / 2.0) + radiusPixels,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.radiusMeters} m allowed radius',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // Optional User GPS blue dot
              ?userLocationDot,

              // Center Marker (Red Pin with Workplace Name Callout Bubble)
              Positioned(
                left: width / 2.0,
                top: height / 2.0,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -1.0),
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Workplace Name Badge Bubble
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x29000000), blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            widget.workplaceName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.active,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Red Pin Icon
                        const Icon(
                          Icons.location_on,
                          size: 36,
                          color: Color(0xFFEA4335),
                        ),
                      ],
                    ),
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

class _WorkplaceGeofencePainter extends CustomPainter {
  const _WorkplaceGeofencePainter({
    required this.radiusPixels,
    required this.color,
  });

  final double radiusPixels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radiusPixels, fillPaint);
    canvas.drawCircle(center, radiusPixels, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _WorkplaceGeofencePainter oldDelegate) {
    return oldDelegate.radiusPixels != radiusPixels || oldDelegate.color != color;
  }
}
