import 'dart:convert';
import 'package:flutter/material.dart';
import 'on_duty_camera_page.dart';

class OdStatusSubmitResult {
  final List<String> photos;
  final String text;

  const OdStatusSubmitResult({
    required this.photos,
    required this.text,
  });
}

/// Modal dialog that allows employees to upload 1 to 4 photos and enter purpose/reason
/// when marking an OD task as Completed or Not Completed.
/// Minimum: 1 photo, Maximum: 4 photos. Purpose/Reason is required.
class WorkProofUploadDialog extends StatefulWidget {
  const WorkProofUploadDialog({
    super.key,
    required this.siteName,
    this.initialPhotos = const [],
    this.isNotCompleted = false,
    this.initialText = '',
  });

  final String siteName;
  final List<String> initialPhotos;
  final bool isNotCompleted;
  final String initialText;

  @override
  State<WorkProofUploadDialog> createState() => _WorkProofUploadDialogState();
}

class _WorkProofUploadDialogState extends State<WorkProofUploadDialog> {
  final List<String?> _photos = [null, null, null, null];
  late final TextEditingController _textController;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    for (int i = 0; i < widget.initialPhotos.length && i < 4; i++) {
      _photos[i] = widget.initialPhotos[i];
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  int get _uploadedCount => _photos.where((p) => p != null && p.isNotEmpty).length;
  bool get _canSubmit => _uploadedCount >= 1 && _uploadedCount <= 4 && _textController.text.trim().isNotEmpty;

  Future<void> _capturePhotoForSlot(int slotIndex) async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final base64Result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => OnDutyCameraPage(
            title: 'Work Proof - Photo ${slotIndex + 1}',
            subtitle: 'Capture proof for ${widget.siteName}',
          ),
        ),
      );

      if (base64Result != null && base64Result.isNotEmpty) {
        setState(() {
          _photos[slotIndex] = base64Result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _removePhotoAt(int index) {
    setState(() {
      _photos[index] = null;
    });
  }

  void _handleSubmit() {
    final textVal = _textController.text.trim();
    if (textVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isNotCompleted
                ? 'Please enter the reason why OD was not completed.'
                : 'Please enter the purpose/details of the completed OD.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final validPhotos = _photos.whereType<String>().where((p) => p.isNotEmpty).toList();
    if (validPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 1 photo proof is mandatory (minimum 1, maximum 4).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (validPhotos.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 4 photos allowed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      OdStatusSubmitResult(photos: validPhotos, text: textVal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF9CC70A);
    final darkAccent = const Color(0xFF414A51);
    final isNotComp = widget.isNotCompleted;
    final headerTitle = isNotComp ? 'Mark OD as Not Completed' : 'Mark OD as Completed';
    final textLabel = isNotComp ? 'Reason for Not Completed *' : 'Purpose / Details of Completed OD *';
    final textHint = isNotComp
        ? 'Enter reason why this On-Duty was not completed...'
        : 'Enter purpose and completed details of this On-Duty...';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isNotComp ? const Color(0xFFDC2626) : darkAccent,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isNotComp ? Colors.white : primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isNotComp ? Icons.cancel_outlined : Icons.check_circle_outline,
                        color: isNotComp ? const Color(0xFFDC2626) : darkAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.siteName,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Purpose / Reason Input Field
                    Text(
                      textLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: textHint,
                        hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isNotComp ? const Color(0xFFDC2626) : primaryColor,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Guideline Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: isNotComp ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                children: [
                                  const TextSpan(text: 'Mandatory: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                  const TextSpan(text: 'Minimum '),
                                  const TextSpan(text: '1 photo', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const TextSpan(text: ', maximum '),
                                  const TextSpan(text: '4 photos', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: isNotComp ? ' showing reason/proof.' : ' showing completed work.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Counter Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'UPLOADED PHOTOS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _uploadedCount >= 1 ? Colors.green.shade100 : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_uploadedCount / 4 Photos',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _uploadedCount >= 1 ? Colors.green.shade900 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2x2 Grid of 4 Photo Slots
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        final photoData = _photos[index];
                        final isMandatory = index == 0;
                        final labelText = isMandatory ? 'Photo 1 * (Required)' : 'Photo ${index + 1} (Optional)';

                        return _buildPhotoSlotCard(
                          index: index,
                          photoData: photoData,
                          isMandatory: isMandatory,
                          labelText: labelText,
                          primaryColor: primaryColor,
                          darkAccent: darkAccent,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _canSubmit ? _handleSubmit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isNotComp ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              disabledBackgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: Icon(isNotComp ? Icons.cancel : Icons.check_circle, size: 18),
                            label: Text(
                              isNotComp ? 'Submit Not Completed' : 'Submit Completion',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSlotCard({
    required int index,
    required String? photoData,
    required bool isMandatory,
    required String labelText,
    required Color primaryColor,
    required Color darkAccent,
  }) {
    final hasPhoto = photoData != null && photoData.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: hasPhoto ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPhoto
              ? const Color(0xFF16A34A)
              : (isMandatory ? Colors.amber.shade600 : Colors.grey.shade300),
          width: hasPhoto || isMandatory ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto) ...[
              // Image Thumbnail
              _buildImageFromData(photoData),

              // Top Gradient Overlay for delete button readability
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Delete button
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.red,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _removePhotoAt(index),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ),

              // Bottom Label
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Photo ${index + 1} ✓',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ] else ...[
              // Empty Slot Action Button
              InkWell(
                onTap: () => _capturePhotoForSlot(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMandatory ? primaryColor.withValues(alpha: 0.15) : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: isMandatory ? darkAccent : Colors.grey.shade700,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labelText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isMandatory ? FontWeight.bold : FontWeight.w500,
                        color: isMandatory ? Colors.amber.shade900 : Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageFromData(String data) {
    try {
      if (data.startsWith('data:image')) {
        final commaIdx = data.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(data.substring(commaIdx + 1));
          return Image.memory(bytes, fit: BoxFit.cover);
        }
      }
      return Image.network(
        data,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } catch (_) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }
  }
}
