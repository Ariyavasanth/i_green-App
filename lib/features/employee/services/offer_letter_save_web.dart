import 'dart:html' as html;
import 'package:flutter/material.dart';

Future<void> saveAndDownloadOfferLetter({
  required BuildContext context,
  required List<int> bytes,
  required String fileName,
  String? docTitle,
}) async {
  final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);

  final titleStr = docTitle ?? (fileName.startsWith('BOM') ? 'BOM Details' : 'File');

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$titleStr ($fileName) downloaded successfully!',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
