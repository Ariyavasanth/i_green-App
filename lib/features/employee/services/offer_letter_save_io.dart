import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> saveAndDownloadOfferLetter({
  required BuildContext context,
  required List<int> bytes,
  required String fileName,
}) async {
  final dir = await getApplicationDocumentsDirectory();
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
            launchUrl(Uri.file(file.path));
          },
        ),
      ),
    );
  }
}
