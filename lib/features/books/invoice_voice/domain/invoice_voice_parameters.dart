class InvoiceVoiceItem {
  const InvoiceVoiceItem({
    this.name,
    this.description,
    this.quantity,
    this.rate,
    this.tax,
  });

  final String? name;
  final String? description;
  final double? quantity;
  final double? rate;
  final String? tax;

  factory InvoiceVoiceItem.fromJson(Map<String, dynamic> json) => InvoiceVoiceItem(
    name: _optionalString(json['name']),
    description: _optionalString(json['description']),
    quantity: _optionalNumber(json['quantity']),
    rate: _optionalNumber(json['rate']),
    tax: _optionalString(json['tax']),
  );
}

class InvoiceVoiceParameters {
  const InvoiceVoiceParameters({
    this.customerName,
    this.invoiceNumber,
    this.orderNumber,
    this.invoiceDate,
    this.paymentTerms,
    this.dueDate,
    this.items = const [],
    this.appendItems = false,
    this.duplicateItem = false,
    this.discount,
    this.discountType,
    this.taxMode,
    this.invoiceTax,
    this.advanceReceived,
    this.notes,
    this.termsAndConditions,
  });

  final String? customerName;
  final String? invoiceNumber;
  final String? orderNumber;
  final DateTime? invoiceDate;
  final String? paymentTerms;
  final DateTime? dueDate;
  final List<InvoiceVoiceItem> items;
  final bool appendItems;
  final bool duplicateItem;
  final double? discount;
  final String? discountType;
  final String? taxMode;
  final String? invoiceTax;
  final double? advanceReceived;
  final String? notes;
  final String? termsAndConditions;

  factory InvoiceVoiceParameters.fromJson(Map<String, dynamic> json) {
    const allowedKeys = {
      'customerName', 'invoiceNumber', 'orderNumber', 'invoiceDate',
      'paymentTerms', 'dueDate', 'items', 'discount', 'discountType',
      'appendItems', 'duplicateItem', 'taxMode', 'invoiceTax',
      'advanceReceived', 'notes', 'termsAndConditions',
    };
    if (json.keys.any((key) => !allowedKeys.contains(key))) {
      throw const FormatException('The AI response contained unsupported fields.');
    }
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List) {
      throw const FormatException('Invoice items must be a list.');
    }
    if (rawItems is List && rawItems.length > 25) {
      throw const FormatException('A maximum of 25 voice items is supported.');
    }
    return InvoiceVoiceParameters(
      customerName: _optionalString(json['customerName']),
      invoiceNumber: _optionalString(json['invoiceNumber']),
      orderNumber: _optionalString(json['orderNumber']),
      invoiceDate: _optionalDate(json['invoiceDate']),
      paymentTerms: _optionalString(json['paymentTerms']),
      dueDate: _optionalDate(json['dueDate']),
      items: rawItems is List
          ? rawItems.map((value) {
              if (value is! Map<String, dynamic>) {
                throw const FormatException('An invoice item is invalid.');
              }
              return InvoiceVoiceItem.fromJson(value);
            }).toList()
          : const [],
      appendItems: _optionalBool(json['appendItems']),
      duplicateItem: _optionalBool(json['duplicateItem']),
      discount: _optionalNumber(json['discount']),
      discountType: _optionalString(json['discountType']),
      taxMode: _optionalString(json['taxMode']),
      invoiceTax: _optionalString(json['invoiceTax']),
      advanceReceived: _optionalNumber(json['advanceReceived']),
      notes: _optionalString(json['notes']),
      termsAndConditions: _optionalString(json['termsAndConditions']),
    );
  }

  InvoiceVoiceParameters validated() {
    const terms = {'Due on Receipt', 'Net 15', 'Net 30', 'Net 45', 'Net 60'};
    const taxes = {'No Tax', 'GST 5%', 'GST 12%', 'GST 18%', 'GST 28%'};
    if (paymentTerms != null && !terms.contains(paymentTerms)) {
      throw const FormatException('Unsupported payment terms.');
    }
    if (discountType != null && !{'%', 'Amount'}.contains(discountType)) {
      throw const FormatException('Unsupported discount type.');
    }
    if (taxMode != null && !{'TDS', 'TCS'}.contains(taxMode)) {
      throw const FormatException('Unsupported tax mode.');
    }
    if (invoiceTax != null && !taxes.contains(invoiceTax)) {
      throw const FormatException('Unsupported invoice tax.');
    }
    if (discount != null && discount! < 0 || advanceReceived != null && advanceReceived! < 0) {
      throw const FormatException('Invoice amounts cannot be negative.');
    }
    if (invoiceDate != null && dueDate != null && dueDate!.isBefore(invoiceDate!)) {
      throw const FormatException('Due date cannot be before invoice date.');
    }
    for (final item in items) {
      if (item.quantity != null && item.quantity! <= 0) {
        throw const FormatException('Item quantity must be greater than zero.');
      }
      if (item.rate != null && item.rate! < 0) {
        throw const FormatException('Item rate cannot be negative.');
      }
      if (item.tax != null && !taxes.contains(item.tax)) {
        throw const FormatException('Unsupported item tax.');
      }
    }
    return this;
  }
}

bool _optionalBool(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  throw const FormatException('Expected boolean value.');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Expected text value.');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _optionalNumber(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw const FormatException('Expected numeric value.');
}

DateTime? _optionalDate(Object? value) {
  final text = _optionalString(value);
  if (text == null) return null;
  return DateTime.tryParse(text) ?? (throw const FormatException('Invalid date.'));
}
