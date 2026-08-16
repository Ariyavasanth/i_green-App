import 'dart:io' show Directory, File, Platform;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> saveAndDownloadOfferLetter({
  required BuildContext context,
  required List<int> bytes,
  required String fileName,
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

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Offer Letter saved to $locationLabel: $fileName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
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
                      content: Text('File location: ${file.path}'),
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

