import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> downloadFileFromUrl({
  required BuildContext context,
  required String url,
  required String fileName,
  String? docTitle,
}) async {
  try {
    List<int>? bytes;
    if (url.startsWith('data:')) {
      final commaIdx = url.indexOf(',');
      final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
      bytes = base64Decode(base64Str);
    } else {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        bytes = res.bodyBytes;
      }
    }

    if (bytes != null) {
      await saveAndDownloadOfferLetter(
        context: context,
        bytes: bytes,
        fileName: fileName,
        docTitle: docTitle,
      );
      return;
    }
  } catch (e) {
    debugPrint('IO download from URL failed: $e');
  }

  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}
}

Future<void> saveAndDownloadOfferLetter({
  required BuildContext context,
  required List<int> bytes,
  required String fileName,
  String? docTitle,
}) async {
  File? file;
  String locationLabel = 'Downloads';

  if (Platform.isAndroid) {
    // 1. Try public Downloads folder
    try {
      final downloadsFolder = Directory('/storage/emulated/0/Download');
      if (downloadsFolder.existsSync()) {
        final candidate = File('${downloadsFolder.path}/$fileName');
        await candidate.writeAsBytes(bytes);
        file = candidate;
        locationLabel = 'Downloads';
      }
    } catch (_) {}

    // 2. Fallback to external storage directory
    if (file == null) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final candidate = File('${extDir.path}/$fileName');
          await candidate.writeAsBytes(bytes);
          file = candidate;
          locationLabel = 'External Storage';
        }
      } catch (_) {}
    }

    // 3. Fallback to application documents directory
    if (file == null) {
      final docDir = await getApplicationDocumentsDirectory();
      final candidate = File('${docDir.path}/$fileName');
      await candidate.writeAsBytes(bytes);
      file = candidate;
      locationLabel = 'Documents';
    }
  } else if (Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    final candidate = File('${dir.path}/$fileName');
    await candidate.writeAsBytes(bytes);
    file = candidate;
    locationLabel = 'Files / Documents';
  } else {
    final dir =
        (await getDownloadsDirectory()) ??
        await getApplicationDocumentsDirectory();
    final candidate = File('${dir.path}/$fileName');
    await candidate.writeAsBytes(bytes);
    file = candidate;
    locationLabel = 'Downloads';
  }

  final titleStr =
      docTitle ?? (fileName.startsWith('BOM') ? 'BOM Details' : 'File');

  if (context.mounted && file != null) {
    final targetFile = file;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_done_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Download Complete',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$titleStr saved to $locationLabel: $fileName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'OPEN',
          textColor: const Color(0xFF9CC70A),
          onPressed: () async {
            try {
              final uri = Uri.file(targetFile.path);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('File location: ${targetFile.path}')),
                  );
                }
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('File saved at: ${targetFile.path}')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
