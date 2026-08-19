import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/purchase_order.dart';

class PdfGeneratorService {
  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _date = DateFormat('dd/MM/yyyy');

  static Future<File?> downloadPurchaseOrderPdf(PurchaseOrder order) async {
    try {
      final content = _generateFormattedDocument(order);

      Directory? dir;
      if (!kIsWeb && Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      }
      dir ??= await getApplicationDocumentsDirectory();

      final filePath = '${dir.path}/${order.number}.pdf';
      final file = File(filePath);
      await file.writeAsString(content);
      return file;
    } catch (e) {
      debugPrint('Error generating PDF file: $e');
      return null;
    }
  }

  static String _generateFormattedDocument(PurchaseOrder order) {
    final buffer = StringBuffer();
    buffer.writeln('================================================================');
    buffer.writeln('                     IGREEN TECHNOLOGIES                        ');
    buffer.writeln('      No. 25, Industrial Estate, Chennai - 600058, Tamil Nadu   ');
    buffer.writeln('    GSTIN: 33AAAAA0000A1Z5 | Phone: +91 98765 43210             ');
    buffer.writeln('================================================================');
    buffer.writeln('                      PURCHASE ORDER                            ');
    buffer.writeln('----------------------------------------------------------------');
    buffer.writeln('PO Number:      ${order.number}');
    buffer.writeln('Date:           ${_date.format(order.date)}');
    buffer.writeln('Delivery Date:  ${order.deliveryDate != null ? _date.format(order.deliveryDate!) : "As agreed"}');
    buffer.writeln('Payment Terms:  ${order.paymentTerms}');
    buffer.writeln('----------------------------------------------------------------');
    buffer.writeln('VENDOR DETAILS:');
    buffer.writeln(order.vendorName);
    buffer.writeln('GSTIN: 33XXXXX1234X1Z5');
    buffer.writeln('----------------------------------------------------------------');
    buffer.writeln('DELIVERY DESTINATION:');
    buffer.writeln(order.deliveryAddressType == 'Organization' ? 'IGreen Technologies Warehouse' : order.customerName);
    buffer.writeln(order.deliveryAddress.isNotEmpty ? order.deliveryAddress : 'No. 25, Industrial Estate, Chennai - 600058');
    buffer.writeln('----------------------------------------------------------------');
    buffer.writeln('ITEM DETAILS:');
    buffer.writeln('----------------------------------------------------------------');
    if (order.items.isEmpty) {
      buffer.writeln('1. Sample Item | Qty: 1 | Rate: ${_money.format(order.amount)} | Amount: ${_money.format(order.amount)}');
    } else {
      for (int i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        buffer.writeln('${i + 1}. ${item.itemName} (${item.account})');
        buffer.writeln('   Qty: ${item.quantity} ${item.unit} | Rate: ${_money.format(item.rate)} | Tax: ${item.taxRate.toInt()}% | Total: ${_money.format(item.amount)}');
      }
    }
    buffer.writeln('----------------------------------------------------------------');
    buffer.writeln('FINANCIAL SUMMARY:');
    buffer.writeln('Sub Total:     ${_money.format(order.subTotal > 0 ? order.subTotal : order.amount)}');
    if (order.discountAmount > 0) {
      buffer.writeln('Discount:      -${_money.format(order.discountAmount)}');
    }
    if (order.taxAmount > 0) {
      buffer.writeln('GST Tax:       ${_money.format(order.taxAmount)}');
    }
    if (order.tdsAmount > 0) {
      buffer.writeln('TDS Deduction: -${_money.format(order.tdsAmount)}');
    }
    if (order.tcsAmount > 0) {
      buffer.writeln('TCS Addition:  +${_money.format(order.tcsAmount)}');
    }
    if (order.roundOff != 0) {
      buffer.writeln('Round Off:     ${_money.format(order.roundOff)}');
    }
    buffer.writeln('GRAND TOTAL:   ${_money.format(order.amount)}');
    buffer.writeln('================================================================');
    buffer.writeln('TERMS & CONDITIONS:');
    buffer.writeln(order.terms.isNotEmpty ? order.terms : '1. Payment as per agreed terms.\n2. Inspection upon delivery.');
    buffer.writeln('================================================================');
    buffer.writeln('Authorized Signature: ___________________________');
    return buffer.toString();
  }
}
