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
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      await saveAndDownloadOfferLetter(
        context: context,
        bytes: res.bodyBytes,
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
  Directory dir;
  String locationLabel = '';

  if (Platform.isAndroid) {
    final downloadsFolder = Directory('/storage/emulated/0/Download');
    if (downloadsFolder.existsSync()) {
      dir = downloadsFolder;
      locationLabel = 'Downloads';
    } else {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        dir = extDir;
        locationLabel = 'External Storage';
      } else {
        dir = await getApplicationDocumentsDirectory();
        locationLabel = 'Documents';
      }
    }
  } else if (Platform.isIOS) {
    dir = await getApplicationDocumentsDirectory();
    locationLabel = 'Files / Documents';
  } else {
    dir = (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
    locationLabel = 'Downloads';
  }

  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);

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
                '$titleStr saved to $locationLabel: $fileName',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Open',
          textColor: Colors.white,
          onPressed: () async {
            try {
              final uri = Uri.file(file.path);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('File saved: ${file.path}'),
                    ),
                  );
                }
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved to: ${file.path}'),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }
}

