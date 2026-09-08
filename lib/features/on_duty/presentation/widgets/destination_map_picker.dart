import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SelectedDestination {
  const SelectedDestination({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.radius = 100,
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

class DestinationMapPicker extends StatefulWidget {
  const DestinationMapPicker({
    super.key,
    this.initialDestination,
    required this.onDestinationSelected,
    this.primaryColor = const Color(0xFF9CC70A),
    this.darkTextColor = const Color(0xFF414A51),
  });

  final SelectedDestination? initialDestination;
  final ValueChanged<SelectedDestination?> onDestinationSelected;
  final Color primaryColor;
  final Color darkTextColor;

  @override
  State<DestinationMapPicker> createState() => _DestinationMapPickerState();
}

class _DestinationMapPickerState extends State<DestinationMapPicker> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isSearching = false;
  bool _isLocatingUser = false;
  List<Map<String, dynamic>> _suggestions = [];

  // Currently selected / draft location
  String _selectedName = '';
  String _selectedAddress = '';
  double? _selectedLat;
  double? _selectedLng;
  int _selectedRadius = 100;
  bool _isApplied = false;

  // Map view state
  static const String _googleMapsApiKey = 'AIzaSyAUjhxMMfOFsi6mmwz2mn0ADjfLKnUY4wk';
  String _mapType = 'roadmap'; // roadmap, satellite, hybrid, terrain
  double _zoomLevel = 15.0;
  final List<int> _radiusOptions = [50, 100, 200, 500];

  String _buildGoogleMapsUrl({int width = 600, int height = 300}) {
    final lat = _selectedLat ?? 12.9249;
    final lng = _selectedLng ?? 80.1000;
    final zoom = _zoomLevel.toInt().clamp(10, 20);
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&scale=2'
        '&maptype=$_mapType'
        '&markers=color:red%7Clabel:D%7C$lat,$lng'
        '&key=$_googleMapsApiKey';
  }

  Future<void> _openInGoogleMaps() async {
    final lat = _selectedLat ?? 12.9249;
    final lng = _selectedLng ?? 80.1000;
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDestination != null) {
      _selectedName = widget.initialDestination!.name;
      _selectedAddress = widget.initialDestination!.address;
      _selectedLat = widget.initialDestination!.latitude;
      _selectedLng = widget.initialDestination!.longitude;
      _selectedRadius = widget.initialDestination!.radius;
      _searchController.text = _selectedName;
      _isApplied = true;
    } else {
      // Default to standard site or current location
      _selectedName = 'Tambaram Site';
      _selectedAddress = 'GST Road, Tambaram, Chennai, Tamil Nadu';
      _selectedLat = 12.9249;
      _selectedLng = 80.1000;
      _searchController.text = 'Tambaram Site, Chennai';
    }
  }

  @override
  void dispose() {
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
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performPlaceSearch(query.trim());
    });
  }

  Future<void> _performPlaceSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      final List<Map<String, dynamic>> results = [];

      // 1. Check local predefined landmarks / sites first for instant matching
      final localMatches = _getLocalPresetMatches(query);
      results.addAll(localMatches);

      // 2. Fetch from OpenStreetMap Nominatim Geocoding API
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&addressdetails=1&limit=5',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'IGreenTechHRMS/1.0'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (final item in data) {
          final displayName = (item['display_name'] ?? '').toString();
          final parts = displayName.split(',');
          final name = parts.isNotEmpty ? parts.first.trim() : query;
          final address = parts.length > 1 ? parts.sublist(1).join(',').trim() : displayName;
          final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;

          if (lat != 0.0 && lon != 0.0) {
            results.add({
              'name': name,
              'address': address,
              'lat': lat,
              'lng': lon,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = _getLocalPresetMatches(query);
          _isSearching = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getLocalPresetMatches(String query) {
    final q = query.toLowerCase();
    final presets = [
      {'name': 'ABC Customer Office', 'address': 'Tambaram Main Road, Chennai, Tamil Nadu', 'lat': 12.9249, 'lng': 80.1000},
      {'name': 'Tambaram Site Project', 'address': 'GST Road, Tambaram Sanatorium, Chennai', 'lat': 12.9290, 'lng': 80.1200},
      {'name': 'Guindy Industrial Estate', 'address': 'Guindy, Chennai, Tamil Nadu', 'lat': 13.0067, 'lng': 80.2025},
      {'name': 'Ambattur Industrial Estate', 'address': 'Ambattur, Chennai, Tamil Nadu', 'lat': 13.0983, 'lng': 80.1620},
      {'name': 'SIPCOT IT Park', 'address': 'Siruseri, Old Mahabalipuram Rd, Chennai', 'lat': 12.8310, 'lng': 80.2220},
      {'name': 'DLF Cybercity', 'address': 'Manapakkam, Mount Poonamallee Rd, Chennai', 'lat': 13.0230, 'lng': 80.1700},
      {'name': 'Tidel Park', 'address': 'Rajiv Gandhi Salai, Taramani, Chennai', 'lat': 12.9897, 'lng': 80.2470},
      {'name': 'Sholinganallur Junction', 'address': 'OMR - Medavakkam Link Rd, Chennai', 'lat': 12.9010, 'lng': 80.2279},
      {'name': 'Bangalore Branch Site', 'address': 'Electronic City Phase 1, Bangalore, Karnataka', 'lat': 12.8399, 'lng': 77.6770},
      {'name': 'Hyderabad Client Facility', 'address': 'HITEC City, Madhapur, Hyderabad, Telangana', 'lat': 17.4483, 'lng': 78.3915},
    ];

    return presets.where((p) {
      final name = p['name'].toString().toLowerCase();
      final addr = p['address'].toString().toLowerCase();
      return name.contains(q) || addr.contains(q);
    }).toList();
  }

  void _selectSuggestion(Map<String, dynamic> item) {
    setState(() {
      _selectedName = item['name'].toString();
      _selectedAddress = item['address'].toString();
      _selectedLat = (item['lat'] as num).toDouble();
      _selectedLng = (item['lng'] as num).toDouble();
      _searchController.text = _selectedName;
      _suggestions = [];
      _isApplied = false;
    });
    _searchFocusNode.unfocus();
  }

  Future<void> _fetchCurrentGpsLocation() async {
    setState(() => _isLocatingUser = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable device location services.')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final lat = position.latitude;
      final lng = position.longitude;

      String name = 'Current GPS Location';
      String addr = 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';

      // Reverse geocode via Nominatim
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
        );
        final resp = await http
            .get(url, headers: {'User-Agent': 'IGreenTechHRMS/1.0'})
            .timeout(const Duration(seconds: 3));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final displayName = (data['display_name'] ?? '').toString();
          if (displayName.isNotEmpty) {
            final parts = displayName.split(',');
            name = parts.first.trim();
            addr = parts.length > 1 ? parts.sublist(1).join(',').trim() : displayName;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _selectedLat = lat;
          _selectedLng = lng;
          _selectedName = name;
          _selectedAddress = addr;
          _searchController.text = name;
          _isApplied = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get GPS location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingUser = false);
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

  @override
  Widget build(BuildContext context) {
    if (_isApplied && _selectedLat != null && _selectedLng != null) {
      return _buildAppliedSummary();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Search Destination Field
        Row(
          children: [
            const Icon(Icons.search_rounded, size: 18, color: Color(0xFF414A51)),
            const SizedBox(width: 6),
            const Text(
              'Search Destination *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF414A51),
              ),
            ),
            const Spacer(),
            if (_selectedLat != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_selectedLat!.toStringAsFixed(3)}, ${_selectedLng!.toStringAsFixed(3)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.darkTextColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Search Bar Input
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search customer, site, address, landmark...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.location_searching_rounded, size: 20, color: Color(0xFF64748B)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9CC70A)),
                    ),
                  )
                else if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _suggestions = []);
                    },
                  ),
                IconButton(
                  icon: _isLocatingUser
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF414A51)),
                        )
                      : const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF414A51)),
                  tooltip: 'Use My Current Location',
                  onPressed: _isLocatingUser ? null : _fetchCurrentGpsLocation,
                ),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
            ),
          ),
        ),

        // Autocomplete Suggestions Dropdown
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, i) {
                final item = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on, size: 18, color: Color(0xFFE11D48)),
                  title: Text(
                    item['name'].toString(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item['address'].toString(),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectSuggestion(item),
                );
              },
            ),
          ),

        const SizedBox(height: 12),

        // 2. Live Google Maps Interactive Container
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Real Google Maps Static Imagery
                Positioned.fill(
                  child: Image.network(
                    _buildGoogleMapsUrl(width: 600, height: 360),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFFF1F5F9),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: widget.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Loading Google Maps...',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.darkTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // Graceful fallback if offline or API quota
                      return Stack(
                        children: [
                          CustomPaint(
                            size: const Size(double.infinity, 200),
                            painter: _MapCanvasPainter(
                              lat: _selectedLat ?? 12.9249,
                              lng: _selectedLng ?? 80.1000,
                              radius: _selectedRadius,
                              primaryColor: widget.primaryColor,
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Preview Mode',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Geofence Circle Overlay in Center
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GeofenceCirclePainter(
                      radius: _selectedRadius,
                      primaryColor: widget.primaryColor,
                    ),
                  ),
                ),

                // Map Pin Marker in Center
                Center(
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
                          _selectedName.isNotEmpty ? _selectedName : 'Selected Destination',
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

                // Top Left: Geofence Radius Badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radar, size: 14, color: widget.darkTextColor),
                        const SizedBox(width: 4),
                        Text(
                          'Radius: $_selectedRadius m',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Right: Map Type Switcher (Roadmap / Satellite / Terrain)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
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
                ),

                // Bottom Left: Open in Google Maps Link
                Positioned(
                  bottom: 10,
                  left: 10,
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
                          Icon(Icons.open_in_new, size: 13, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'Open Google Maps',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Right: Map Zoom Controls
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Column(
                    children: [
                      _buildMapIconButton(
                        icon: Icons.add,
                        tooltip: 'Zoom In',
                        onPressed: () => setState(() => _zoomLevel = (_zoomLevel + 1).clamp(10.0, 20.0)),
                      ),
                      const SizedBox(height: 4),
                      _buildMapIconButton(
                        icon: Icons.remove,
                        tooltip: 'Zoom Out',
                        onPressed: () => setState(() => _zoomLevel = (_zoomLevel - 1).clamp(10.0, 20.0)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 3. Geofence Radius Selector Chips
        Row(
          children: [
            const Text(
              'Allowed Geofence Radius:',
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

        const SizedBox(height: 14),

        // 4. APPLY DESTINATION Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_selectedLat != null && _selectedLng != null) ? _applyDestination : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: widget.darkTextColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              '[ APPLY DESTINATION ]',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ),
      ],
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

  Widget _buildMapIconButton({required IconData icon, required VoidCallback onPressed, String? tooltip}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 16, color: const Color(0xFF414A51)),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }

  // 5. Applied Destination Summary State
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
                    Icon(Icons.map_outlined, size: 14, color: Color(0xFF2563EB)),
                    SizedBox(width: 4),
                    Text(
                      'View on Map',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
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

/// Geofence circle overlay painter centered on the map
class _GeofenceCirclePainter extends CustomPainter {
  _GeofenceCirclePainter({
    required this.radius,
    required this.primaryColor,
  });

  final int radius;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final double visualRadius = (radius / 500.0 * 60).clamp(28.0, 75.0);

    final geofenceFill = Paint()
      ..color = primaryColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final geofenceBorder = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, visualRadius, geofenceFill);
    canvas.drawCircle(center, visualRadius, geofenceBorder);
  }

  @override
  bool shouldRepaint(covariant _GeofenceCirclePainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.primaryColor != primaryColor;
  }
}

/// Fallback custom painter for interactive vector map preview if offline
class _MapCanvasPainter extends CustomPainter {
  _MapCanvasPainter({
    required this.lat,
    required this.lng,
    required this.radius,
    required this.primaryColor,
  });

  final double lat;
  final double lng;
  final int radius;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final roadPaint2 = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.7, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.8), roadPaint2);

    final greenAreaPaint = Paint()..color = const Color(0xFFDCFCE7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.08, size.width * 0.2, size.height * 0.25),
        const Radius.circular(8),
      ),
      greenAreaPaint,
    );

    final center = Offset(size.width / 2, size.height / 2 + 10);
    final double visualRadius = (radius / 500.0 * 60).clamp(28.0, 75.0);

    final geofenceFill = Paint()
      ..color = primaryColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final geofenceBorder = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, visualRadius, geofenceFill);
    canvas.drawCircle(center, visualRadius, geofenceBorder);
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.lat != lat ||
        oldDelegate.lng != lng ||
        oldDelegate.radius != radius ||
        oldDelegate.primaryColor != primaryColor;
  }
}
