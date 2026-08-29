import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/smart_network_image.dart';
import '../../features/books/domain/books_repository.dart';
import '../../features/employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../features/employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../features/employee/services/offer_letter_save_io.dart';
import 'process_flow_screen.dart';

/// Displays the BOM record for the single part selected in the exploded view.
class BomDetailsScreen extends StatelessWidget {
  const BomDetailsScreen({
    required this.partIdentifier,
    this.itemPart,
    this.drawingFileName,
    super.key,
  });

  final String partIdentifier;
  final ItemPart? itemPart;
  final String? drawingFileName;

  @override
  Widget build(BuildContext context) {
    final _BomPart part;
    final bool hasProcessFlow;
    if (itemPart != null) {
      part = _BomPart(
        '${itemPart!.slNo}',
        itemPart!.partName,
        itemPart!.partNo,
        itemPart!.rmGrade.isNotEmpty ? itemPart!.rmGrade : '-',
        itemPart!.rmSize.isNotEmpty ? itemPart!.rmSize : '-',
        '${itemPart!.rmWeight} kg',
        '${itemPart!.fgWeight} kg',
        '${itemPart!.quantity}',
      );
      hasProcessFlow = itemPart!.hasProcessFlow && itemPart!.operations.isNotEmpty;
    } else {
      part = _bomParts[partIdentifier] ?? _BomPart.fallback(partIdentifier);
      hasProcessFlow = processFlowByPart[partIdentifier]?.isNotEmpty ?? false;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'BOM Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppLayout.gutter(constraints.maxWidth),
                  16,
                  AppLayout.gutter(constraints.maxWidth),
                  20,
                ),
                child: ResponsiveContent(
                  maxWidth: AppLayout.maxFormWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BomImageSection(imagePath: itemPart?.partImage ?? ''),
                      const SizedBox(height: 16),
                      BomInfoCard(part: part),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E5EA))),
              ),
              child: ResponsiveContent(
                maxWidth: AppLayout.maxFormWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        String targetPdfUrl = itemPart?.partPdf.trim() ?? '';
                        if (targetPdfUrl.isEmpty && drawingFileName != null) {
                          targetPdfUrl = drawingFileName!.trim();
                        }

                        if (targetPdfUrl.isNotEmpty) {
                          try {
                            List<int>? pdfBytes;
                            if (targetPdfUrl.startsWith('http://') || targetPdfUrl.startsWith('https://')) {
                              final res = await http.get(Uri.parse(targetPdfUrl));
                              if (res.statusCode == 200) {
                                pdfBytes = res.bodyBytes;
                              }
                            } else if (targetPdfUrl.startsWith('data:application/pdf;base64,')) {
                              pdfBytes = base64Decode(targetPdfUrl.split(',').last);
                            }
                            if (pdfBytes != null && context.mounted) {
                              String cleanFileName = '${part.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_Drawing.pdf';
                              if (targetPdfUrl.contains('/')) {
                                final namePart = targetPdfUrl.split('/').last.split('?').first;
                                final decoded = Uri.decodeComponent(namePart).replaceAll(RegExp(r'^\d+_'), '');
                                if (decoded.toLowerCase().endsWith('.pdf')) {
                                  cleanFileName = decoded;
                                }
                              }
                              await saveAndDownloadOfferLetter(
                                context: context,
                                bytes: pdfBytes,
                                fileName: cleanFileName,
                                docTitle: 'Drawing PDF',
                              );
                              return;
                            }
                          } catch (_) {}
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No uploaded PDF drawing found for this part. Please upload a PDF in the item/parts form.'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download PDF'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    if (hasProcessFlow) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProcessFlowScreen(
                              partIdentifier: partIdentifier,
                              partName: part.name,
                              customOperations: itemPart?.operations,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.account_tree_outlined),
                        label: const Text('View Process Flow'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BomImageSection extends StatelessWidget {
  const BomImageSection({this.imagePath = '', super.key});

  final String imagePath;

  Widget _buildContent(BuildContext context) {
    if (imagePath.isNotEmpty) {
      if (imagePath.startsWith('data:')) {
        try {
          final data = Uri.parse(imagePath).data;
          if (data != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                data.contentAsBytes(),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _placeholder(context),
              ),
            );
          }
        } catch (_) {}
      }
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SmartNetworkImage(
            url: imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context) => _placeholder(context),
          ),
        );
      }
      if (imagePath.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _placeholder(context),
          ),
        );
      }
      final cleanName = imagePath.contains('/') ? imagePath.split('/').last : imagePath;
      final encodedName = Uri.encodeComponent(cleanName);
      final rawMaterialUrl = 'https://firebasestorage.googleapis.com/v0/b/i-green-tech.firebasestorage.app/o/Raw%20Material%20Images%2F$encodedName?alt=media';
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SmartNetworkImage(
          url: rawMaterialUrl,
          fit: BoxFit.contain,
          errorBuilder: (context) => _placeholder(context),
        ),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.image_outlined,
        size: 40,
        color: Theme.of(context).colorScheme.outline,
      ),
      const SizedBox(height: 8),
      Text(
        'No BOM Image Attached',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('BOM Image', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: _buildContent(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class BomInfoCard extends StatelessWidget {
  const BomInfoCard({required this.part, super.key});

  final _BomPart part;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BomInfoRow(label: 'Sl. No.', value: part.serialNumber),
          BomInfoRow(label: 'Part Name', value: part.name),
          BomInfoRow(label: 'Part No.', value: part.partNumber),
          BomInfoRow(label: 'RM Grade', value: part.rmGrade),
          BomInfoRow(label: 'RM Size', value: part.rmSize),
          BomInfoRow(label: 'RM Weight', value: part.rmWeight),
          BomInfoRow(label: 'FG Weight', value: part.fgWeight),
          BomInfoRow(label: 'Quantity', value: part.quantity),
        ],
      ),
    ),
  );
}

class BomInfoRow extends StatelessWidget {
  const BomInfoRow({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 550;
      if (isMobile) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 160, child: Text(label, style: AppTextStyles.caption)),
            const SizedBox(width: 12),
            Expanded(child: Text(value, style: AppTextStyles.body)),
          ],
        ),
      );
    },
  );
}

class _BomPart {
  const _BomPart(this.serialNumber, this.name, this.partNumber, this.rmGrade,
      this.rmSize, this.rmWeight, this.fgWeight, this.quantity);

  factory _BomPart.fallback(String identifier) =>
      _BomPart('-', identifier, '-', '-', '-', '-', '-', '-');

  final String serialNumber;
  final String name;
  final String partNumber;
  final String rmGrade;
  final String rmSize;
  final String rmWeight;
  final String fgWeight;
  final String quantity;
}

const _bomParts = <String, _BomPart>{
  'Shaft': _BomPart('1', 'Shaft', 'IG-PS-3.5-SH', 'EN8',
      'Dia 50 x 250L', '4kg', '3kg', '1'),
  'Bearing Shaft': _BomPart('2', 'Bearing Shaft', 'IG-PS-3.5-BRS', 'EN8',
      'Dia 76 × 185L', '8 kg', '5 kg', '1'),
  'Bearing Housing': _BomPart('3', 'Bearing Housing', 'IG-PS-3.5-BRH', 'EN8',
      'Dia 89 × 135L', '15 kg', '8 kg', '1'),
  'Oil Seal': _BomPart('3', 'Oil Seal', 'IG-PS-3.5-OS', 'NBR',
      '50 x 72 x 10', '0.2kg', '0.2kg', '1'),
  'Bearing': _BomPart('4', 'Bearing', 'IG-PS-3.5-BR', 'Bearing Steel',
      '50 x 90 x 20', '0.8kg', '0.8kg', '1'),
  'Lock Nut': _BomPart('1', 'Lock Nut', 'IG-PS-3.5-BRLN', 'EN8',
      'Dia 50 × 25L', '2 kg', '1 kg', '1'),
  'Depth Screw R15': _BomPart('6', 'Depth Screw R15', 'IG-PS-3.5-DSR15',
      'EN8', 'Dia 20 x 45L', '0.3kg', '0.2kg', '1'),
  'Housing Lock Nut': _BomPart('4', 'Housing Lock Nut', 'IG-PS-3.5-HLN',
      'EN8', 'Dia 90 × 140L', '16 kg', '9 kg', '1'),
};
