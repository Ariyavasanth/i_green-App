import 'dart:html' as html;
import 'package:flutter/material.dart';

Future<void> saveAndDownloadOfferLetter({
  required BuildContext context,
  required List<int> bytes,
  required String fileName,
}) async {
  final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Offer Letter ($fileName) downloaded successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
