import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../../employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../../employee/services/offer_letter_save_io.dart';
import '../../../projects/domain/models/project_document.dart';

class TenderDocumentActions {
  static bool isImage(String name, String url) {
    final lowerName = name.toLowerCase();
    final lowerUrl = url.toLowerCase();
    return lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.gif') ||
        lowerUrl.contains('image/png') ||
        lowerUrl.contains('image/jpeg');
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<void> viewDocument(
    BuildContext context,
    ProjectDocument doc,
  ) async {
    final url = doc.downloadUrl.trim();

    if (url.isEmpty) {
      _showEmptyUrlNotice(context, doc);
      return;
    }

    // If it's an image, show full in-app preview dialog
    if (isImage(doc.name, url)) {
      _showImagePreviewDialog(context, doc);
      return;
    }

    // If it's a PDF or other file
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // For data URI or fallback download/view
      await downloadDocument(context, doc);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open document: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  static Future<void> downloadDocument(
    BuildContext context,
    ProjectDocument doc,
  ) async {
    final url = doc.downloadUrl.trim();

    if (url.isEmpty) {
      _showEmptyUrlNotice(context, doc);
      return;
    }

    try {
      await downloadFileFromUrl(
        context: context,
        url: url,
        fileName: doc.name.isNotEmpty ? doc.name : 'tender_document.pdf',
        docTitle: doc.category.isNotEmpty ? doc.category : 'Tender Document',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  static void _showEmptyUrlNotice(BuildContext context, ProjectDocument doc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Document File Status',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document: ${doc.name}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text(
              'This document record exists in Firestore, but its file URL is empty because the Firebase Storage bucket billing is currently disabled on this project.\n\nPlease edit this tender and re-upload the document. It will automatically save with our new high-availability embedded storage fallback so you can view and download it immediately on any device.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF4A5568)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showImagePreviewDialog(
    BuildContext context,
    ProjectDocument doc,
  ) {
    final url = doc.downloadUrl.trim();
    Uint8List? memoryBytes;
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final b64 = comma != -1 ? url.substring(comma + 1) : url;
      try {
        memoryBytes = base64Decode(b64);
      } catch (_) {}
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined,
                        size: 20, color: Color(0xFF9CC70A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        doc.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF414A51),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded,
                          size: 20, color: Color(0xFF414A51)),
                      tooltip: 'Download Image',
                      onPressed: () => downloadDocument(context, doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: Container(
                  color: const Color(0xFFF8F9FA),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: memoryBytes != null
                        ? Image.memory(memoryBytes, fit: BoxFit.contain)
                        : Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('Unable to preview image'),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TenderDocumentChip extends StatelessWidget {
  const TenderDocumentChip({
    super.key,
    required this.document,
    this.onDelete,
    this.showDelete = true,
  });

  final ProjectDocument document;
  final VoidCallback? onDelete;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final isImg = TenderDocumentActions.isImage(
        document.name, document.downloadUrl);
    final isPdf = document.name.toLowerCase().endsWith('.pdf');
    final formattedSize = TenderDocumentActions.formatBytes(document.size);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isPdf
                  ? Colors.red.shade50
                  : (isImg
                      ? const Color(0xFF9CC70A).withValues(alpha: 0.15)
                      : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isPdf
                  ? Icons.picture_as_pdf_outlined
                  : (isImg
                      ? Icons.image_outlined
                      : Icons.insert_drive_file_outlined),
              size: 18,
              color: isPdf
                  ? Colors.red.shade700
                  : (isImg
                      ? const Color(0xFF414A51)
                      : const Color(0xFF718096)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                if (formattedSize.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    formattedSize,
                    style: const TextStyle(
                        fontSize: 10.5, color: Color(0xFF718096)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          // View Button
          IconButton(
            icon: const Icon(Icons.visibility_outlined,
                size: 18, color: Color(0xFF414A51)),
            tooltip: 'View Document',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () =>
                TenderDocumentActions.viewDocument(context, document),
          ),
          const SizedBox(width: 6),
          // Download Button
          IconButton(
            icon: const Icon(Icons.download_rounded,
                size: 18, color: Color(0xFF9CC70A)),
            tooltip: 'Download Document',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () =>
                TenderDocumentActions.downloadDocument(context, document),
          ),
          // Optional Delete Button
          if (showDelete && onDelete != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
              tooltip: 'Remove',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

