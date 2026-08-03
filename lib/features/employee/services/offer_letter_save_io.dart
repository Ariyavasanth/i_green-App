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
  if (Platform.isAndroid) {
    dir = (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
  } else {
    dir = await getApplicationDocumentsDirectory();
  }
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Offer Letter saved to: ${file.path}'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Open',
          textColor: Colors.white,
          onPressed: () {
            launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }
}
