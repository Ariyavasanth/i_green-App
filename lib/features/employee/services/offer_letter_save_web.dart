import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Future<void> saveAndDownloadOfferLetter({
  required BuildContext context,
  required List<int> bytes,
  required String fileName,
  String? docTitle,
}) async {
  final mimeType = fileName.toLowerCase().endsWith('.pdf')
      ? 'application/pdf'
      : (fileName.toLowerCase().endsWith('.docx')
          ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          : 'application/octet-stream');
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName);
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
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

Future<void> downloadFileFromUrl({
  required BuildContext context,
  required String url,
  required String fileName,
  String? docTitle,
}) async {
  final titleStr = docTitle ?? (fileName.startsWith('BOM') ? 'BOM Details' : 'Drawing PDF');

  // Method 1: Fetch via HttpRequest as Blob (downloads directly to local disk without opening a viewer tab)
  try {
    final xhr = html.HttpRequest();
    xhr.open('GET', url);
    xhr.responseType = 'blob';
    final completer = Completer<html.Blob?>();
    xhr.onLoad.listen((_) {
      if (xhr.status == 200 && xhr.response != null) {
        completer.complete(xhr.response as html.Blob);
      } else {
        completer.complete(null);
      }
    });
    xhr.onError.listen((_) => completer.complete(null));
    xhr.send();
    final blob = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );

    if (blob != null && context.mounted) {
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: blobUrl)
        ..setAttribute('download', fileName);
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(blobUrl);

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
      return;
    }
  } catch (e) {
    debugPrint('XHR Blob download error: $e');
  }

  // Method 2: Fetch via http package
  try {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200 && context.mounted) {
      await saveAndDownloadOfferLetter(
        context: context,
        bytes: res.bodyBytes,
        fileName: fileName,
        docTitle: docTitle,
      );
      return;
    }
  } catch (e) {
    debugPrint('HTTP get download error: $e');
  }

  // Method 3: Direct anchor download (without target="_blank" to prevent tab navigation failure)
  try {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName);
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$titleStr ($fileName) download started!',
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
  } catch (e) {
    debugPrint('Direct anchor download error: $e');
  }
}
