import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/purchase_order.dart';
import '../../services/pdf_generator_service.dart';

class PurchaseOrderPdfDialog extends StatelessWidget {
  const PurchaseOrderPdfDialog({super.key, required this.order});

  final PurchaseOrder order;

  static final _moneyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840, maxHeight: 760),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _topBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 550;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _companyHeader(isNarrow),
                            const Divider(height: 24, thickness: 1.5),
                            _vendorAndDeliveryRow(isNarrow),
                            const SizedBox(height: 18),
                            _itemsTableScrollable(),
                            const SizedBox(height: 18),
                            _totalsAndNotesRow(isNarrow),
                            const SizedBox(height: 24),
                            _termsAndSignatureRow(isNarrow),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              _bottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF2C3E50),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'PDF Preview — ${order.number}.pdf',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Close Preview',
            ),
          ],
        ),
      );

  Widget _companyHeader(bool isNarrow) {
    final companyInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'IGREEN TECHNOLOGIES',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        SizedBox(height: 4),
        Text(
          'No. 25, Industrial Estate, Chennai - 600058, Tamil Nadu, India\nGSTIN: 33AAAAA0000A1Z5  |  Phone: +91 98765 43210\nEmail: contact@igreentech.com',
          style: TextStyle(fontSize: 10, height: 1.4, color: Color(0xFF64748B)),
        ),
      ],
    );

    final poBadge = Column(
      crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.active.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'PURCHASE ORDER',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.active),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PO #: ${order.number}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          'Date: ${_dateFormat.format(order.date)}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        if (order.deliveryDate != null)
          Text(
            'Delivery Date: ${_dateFormat.format(order.deliveryDate!)}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
        Text(
          'Payment Terms: ${order.paymentTerms}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
      ],
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          companyInfo,
          const SizedBox(height: 12),
          poBadge,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: companyInfo),
        poBadge,
      ],
    );
  }

  Widget _vendorAndDeliveryRow(bool isNarrow) {
    final vendorBox = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VENDOR DETAILS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(order.vendorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const Text('GSTIN: 33XXXXX1234X1Z5\nPhone: +91 98765 43210', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3)),
        ],
      ),
    );

    final deliveryBox = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DELIVERY DESTINATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            order.deliveryAddressType == 'Organization' ? 'IGreen Technologies Warehouse' : (order.customerName.isNotEmpty ? order.customerName : 'Customer Address'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            order.deliveryAddress.isNotEmpty ? order.deliveryAddress : 'No. 25, Industrial Estate, Chennai - 600058',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );

    if (isNarrow) {
      return Column(
        children: [
          vendorBox,
          const SizedBox(height: 8),
          deliveryBox,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: vendorBox),
        const SizedBox(width: 12),
        Expanded(child: deliveryBox),
      ],
    );
  }

  Widget _itemsTableScrollable() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 680,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(28),
                1: FixedColumnWidth(210),
                2: FixedColumnWidth(140),
                3: FixedColumnWidth(60),
                4: FixedColumnWidth(80),
                5: FixedColumnWidth(60),
                6: FixedColumnWidth(102),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: [
                    _tableCell('#', isHeader: true),
                    _tableCell('ITEM DETAILS', isHeader: true),
                    _tableCell('ACCOUNT', isHeader: true),
                    _tableCell('QTY', isHeader: true, alignRight: true),
                    _tableCell('RATE', isHeader: true, alignRight: true),
                    _tableCell('TAX', isHeader: true, alignRight: true),
                    _tableCell('AMOUNT', isHeader: true, alignRight: true),
                  ],
                ),
                if (order.items.isEmpty)
                  TableRow(
                    children: [
                      _tableCell('1'),
                      _tableCell('Sample Purchase Item'),
                      _tableCell('Cost of Goods Sold'),
                      _tableCell('1 pcs', alignRight: true),
                      _tableCell(_moneyFormat.format(order.amount), alignRight: true),
                      _tableCell('18%', alignRight: true),
                      _tableCell(_moneyFormat.format(order.amount), alignRight: true),
                    ],
                  )
                else
                  ...order.items.asMap().entries.map(
                        (entry) => TableRow(
                          children: [
                            _tableCell('${entry.key + 1}'),
                            _tableCell(entry.value.itemName),
                            _tableCell(entry.value.account),
                            _tableCell('${entry.value.quantity.toStringAsFixed(0)} ${entry.value.unit}'),
                            _tableCell(_moneyFormat.format(entry.value.rate), alignRight: true),
                            _tableCell('${entry.value.taxRate.toInt()}%', alignRight: true),
                            _tableCell(_moneyFormat.format(entry.value.amount), alignRight: true),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ),
      );

  Widget _tableCell(String text, {bool isHeader = false, bool alignRight = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          text,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: isHeader ? 9 : 10,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            color: isHeader ? const Color(0xFF475569) : const Color(0xFF1E293B),
          ),
        ),
      );

  Widget _totalsAndNotesRow(bool isNarrow) {
    final notesWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.notes.isNotEmpty) ...[
          const Text('NOTES:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(order.notes, style: const TextStyle(fontSize: 10, color: AppColors.textPrimary)),
        ],
      ],
    );

    final totalsWidget = SizedBox(
      width: isNarrow ? double.infinity : 280,
      child: Column(
        children: [
          _summaryLine('Sub Total', _moneyFormat.format(order.subTotal > 0 ? order.subTotal : order.amount)),
          if (order.discountAmount > 0)
            _summaryLine('Discount', '-${_moneyFormat.format(order.discountAmount)}'),
          if (order.taxAmount > 0)
            _summaryLine('GST Tax', _moneyFormat.format(order.taxAmount)),
          if (order.tdsAmount > 0)
            _summaryLine('TDS Deduction', '-${_moneyFormat.format(order.tdsAmount)}'),
          if (order.tcsAmount > 0)
            _summaryLine('TCS Addition', '+${_moneyFormat.format(order.tcsAmount)}'),
          if (order.roundOff != 0)
            _summaryLine('Round Off', _moneyFormat.format(order.roundOff)),
          const Divider(height: 12),
          _summaryLine('TOTAL AMOUNT', _moneyFormat.format(order.amount), isBold: true),
        ],
      ),
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          notesWidget,
          if (order.notes.isNotEmpty) const SizedBox(height: 12),
          totalsWidget,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: notesWidget),
        const SizedBox(width: 16),
        totalsWidget,
      ],
    );
  }

  Widget _summaryLine(String label, String value, {bool isBold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isBold ? 12 : 10,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: isBold ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 13 : 10,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: isBold ? AppColors.active : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      );

  Widget _termsAndSignatureRow(bool isNarrow) {
    final termsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TERMS & CONDITIONS:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 3),
        Text(
          order.terms.isNotEmpty
              ? order.terms
              : '1. Payment as per agreed terms.\n2. Inspection upon delivery.\n3. Include PO # on all invoices.',
          style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), height: 1.35),
        ),
      ],
    );

    final signatureWidget = Column(
      crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(width: 130, height: 1, color: Colors.grey.shade400),
        const SizedBox(height: 4),
        const Text('Authorized Signature', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
      ],
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          termsWidget,
          const SizedBox(height: 16),
          signatureWidget,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: termsWidget),
        const SizedBox(width: 24),
        signatureWidget,
      ],
    );
  }

  Widget _bottomBar(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Generating ${order.number}.pdf...')),
                );
                final file = await PdfGeneratorService.downloadPurchaseOrderPdf(order);
                if (context.mounted) {
                  if (file != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 24),
                            SizedBox(width: 10),
                            Text('PDF Downloaded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${order.number}.pdf has been saved to your device:'),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SelectableText(
                                file.path,
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unable to save PDF file to mobile storage.')),
                    );
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Download PDF', style: TextStyle(fontSize: 11)),
            ),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sending ${order.number}.pdf to print queue...')),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.print, size: 14),
              label: const Text('Print', style: TextStyle(fontSize: 11)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.active,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              child: const Text('Close', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
}
