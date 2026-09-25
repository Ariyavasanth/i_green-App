import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/task_item.dart';
import '../providers/task_providers.dart';

class TaskCompletionDialog extends ConsumerStatefulWidget {
  const TaskCompletionDialog({
    super.key,
    required this.task,
    this.onCompleted,
  });

  final TaskItem task;
  final VoidCallback? onCompleted;

  @override
  ConsumerState<TaskCompletionDialog> createState() => _TaskCompletionDialogState();
}

class _TaskCompletionDialogState extends ConsumerState<TaskCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descController;
  String? _photoBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        setState(() {
          _photoBase64 = 'data:image/$ext;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach photo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF9CC70A)),
              title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF414A51)),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCompletion() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photoBase64 == null || _photoBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a completion photo proof.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(taskRepositoryProvider);
      final now = DateTime.now();
      final totalSeconds = widget.task.duration.inSeconds;

      final completedTask = widget.task.copyWith(
        status: 'COMPLETED',
        endTime: now,
        isPaused: false,
        accumulatedSeconds: totalSeconds > 0 ? totalSeconds : 1,
        completionDescription: _descController.text.trim(),
        completionPhotoUrl: _photoBase64,
        breached: now.isAfter(widget.task.deadline),
      );

      await repo.updateTask(completedTask);

      ref.invalidate(tasksProvider);
      ref.invalidate(taskProjectHoursProvider);

      if (widget.onCompleted != null) {
        widget.onCompleted!();
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completedTask.isBreached
                  ? 'Task marked as Completed (SLA Breached)'
                  : 'Task completed successfully on time! ✓',
            ),
            backgroundColor: completedTask.isBreached ? Colors.orange.shade800 : const Color(0xFF9CC70A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete task: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.task_alt_rounded, color: primaryColor),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Complete Task',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Task details preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.task.projectOrOfficeCode,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF414A51),
                            ),
                          ),
                          Text(
                            'Time Spent: ${widget.task.formattedDuration}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.task.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Description Field
                const Text(
                  'Completion Description *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe what was completed, key outcomes or deliverables...',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a completion description' : null,
                ),
                const SizedBox(height: 16),

                // Photo Upload Box
                const Text(
                  'Completion Photo Proof *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                if (_photoBase64 != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: _buildImagePreview(_photoBase64!),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          radius: 16,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onPressed: () => setState(() => _photoBase64 = null),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: primaryColor),
                    onPressed: _showPhotoSourceSheet,
                    icon: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text('Change Photo'),
                  ),
                ] else ...[
                  InkWell(
                    onTap: _showPhotoSourceSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_a_photo_outlined, color: primaryColor, size: 28),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Upload Photo Proof',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Take photo or choose from gallery',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isLoading ? null : _submitCompletion,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        _isLoading ? 'Completing...' : 'Complete Task',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String base64String) {
    try {
      final clean = base64String.contains(',') ? base64String.split(',').last : base64String;
      return Image.memory(
        base64Decode(clean),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
        ),
      );
    } catch (_) {
      return const Center(
        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
      );
    }
  }
}
