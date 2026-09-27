import 'package:flutter/material.dart';
import '../utils/reverse_geocoding_service.dart';

class ReverseGeocodedLocationText extends StatefulWidget {
  const ReverseGeocodedLocationText({
    super.key,
    required this.latitude,
    required this.longitude,
    this.style,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
  });

  final double latitude;
  final double longitude;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  State<ReverseGeocodedLocationText> createState() => _ReverseGeocodedLocationTextState();
}

class _ReverseGeocodedLocationTextState extends State<ReverseGeocodedLocationText> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void didUpdateWidget(covariant ReverseGeocodedLocationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude || oldWidget.longitude != widget.longitude) {
      _loadAddress();
    }
  }

  void _loadAddress() {
    final cached = ReverseGeocodingService.getCachedAddress(widget.latitude, widget.longitude);
    if (cached != null) {
      _address = cached;
      return;
    }

    ReverseGeocodingService.getAddress(widget.latitude, widget.longitude).then((addr) {
      if (mounted) {
        setState(() {
          _address = addr;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1E293B),
      height: 1.3,
    );

    final effectiveStyle = widget.style ?? defaultStyle;
    final displayText = _address ?? '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}';

    return Text(
      displayText,
      style: effectiveStyle,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
