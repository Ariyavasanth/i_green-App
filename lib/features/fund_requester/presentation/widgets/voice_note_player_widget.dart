import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';

class VoiceNotePlayerWidget extends StatefulWidget {
  final bool isRecording;
  final bool hasVoiceNote;
  final String? audioUrl;
  final VoidCallback onStartRecord;
  final VoidCallback onStopRecord;
  final VoidCallback onDelete;
  final VoidCallback? onReRecord;

  const VoiceNotePlayerWidget({
    super.key,
    required this.isRecording,
    required this.hasVoiceNote,
    this.audioUrl,
    required this.onStartRecord,
    required this.onStopRecord,
    required this.onDelete,
    this.onReRecord,
  });

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget>
    with SingleTickerProviderStateMixin {
  Timer? _recordTimer;
  int _recordSeconds = 0;

  Timer? _playTimer;
  bool _isPlaying = false;
  int _playProgressSeconds = 0;
  final int _totalDurationSeconds = 15;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    if (widget.isRecording) {
      _startRecordingTimer();
    }
  }

  @override
  void didUpdateWidget(covariant VoiceNotePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _startRecordingTimer();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopRecordingTimer();
    }
  }

  void _startRecordingTimer() {
    _recordSeconds = 0;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _recordSeconds++;
        if (_recordSeconds >= 120) {
          // Auto-stop at 2 minutes
          widget.onStopRecord();
        }
      });
    });
  }

  void _stopRecordingTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseAudio();
    } else {
      _playAudio();
    }
  }

  void _playAudio() {
    setState(() => _isPlaying = true);
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) return;
      setState(() {
        _playProgressSeconds++;
        if (_playProgressSeconds >= _totalDurationSeconds * 4) {
          _isPlaying = false;
          _playProgressSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  void _pauseAudio() {
    _playTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _playTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRecording) {
      return _buildRecordingState();
    }

    if (widget.hasVoiceNote) {
      return _buildPlaybackState();
    }

    return const SizedBox.shrink();
  }

  // Active Recording View
  Widget _buildRecordingState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated Pulsing Red Dot
          FadeTransition(
            opacity: _pulseController,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'REC',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFFDC2626),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 12),
          // Timer
          Text(
            _formatTime(_recordSeconds),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF991B1B),
              fontFeatures: [],
            ),
          ),
          const SizedBox(width: 12),
          // Visualizer Bars
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(14, (i) {
                final heights = [10.0, 18.0, 26.0, 14.0, 22.0, 30.0, 16.0, 24.0, 28.0, 18.0, 12.0, 20.0, 24.0, 14.0];
                return Container(
                  width: 3.5,
                  height: heights[i % heights.length],
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          // Stop Button
          ElevatedButton.icon(
            onPressed: widget.onStopRecord,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Stop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // Recorded Playback View (Check & Verify)
  Widget _buildPlaybackState() {
    final currentSec = (_playProgressSeconds / 4).floor();
    final progressFraction = (_playProgressSeconds / (_totalDurationSeconds * 4)).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play / Pause Circle Button
              InkWell(
                onTap: _togglePlayPause,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Waveform Track & Progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Voice Note (Tap to listen)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4C1D95),
                          ),
                        ),
                        Text(
                          _isPlaying ? _formatTime(currentSec) : _formatTime(_totalDurationSeconds),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Soundwave bars with active progress coloring
                    Row(
                      children: List.generate(24, (i) {
                        final heights = [8.0, 14.0, 22.0, 12.0, 20.0, 26.0, 16.0, 10.0, 18.0, 24.0, 14.0, 20.0];
                        final isPassed = (i / 24) <= progressFraction;

                        return Expanded(
                          child: Container(
                            height: heights[i % heights.length],
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: isPassed ? const Color(0xFF7C3AED) : const Color(0xFFC4B5FD),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Re-record
              if (widget.onReRecord != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6D28D9), size: 22),
                  tooltip: 'Record Again',
                  onPressed: widget.onReRecord,
                ),

              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                tooltip: 'Delete Voice Note',
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

