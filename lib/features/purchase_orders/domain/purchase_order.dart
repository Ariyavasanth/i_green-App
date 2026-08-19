class PurchaseOrderItem {
  const PurchaseOrderItem({
    this.id,
    this.purchaseOrderId,
    this.itemId,
    required this.itemName,
    this.account = 'Cost of Goods Sold',
    this.quantity = 1.0,
    this.unit = 'pcs',
    this.rate = 0.0,
    this.tax = 'GST 18%',
    this.taxRate = 18.0,
    this.amount = 0.0,
  });

  final int? id;
  final int? purchaseOrderId;
  final int? itemId;
  final String itemName;
  final String account;
  final double quantity;
  final String unit;
  final double rate;
  final String tax;
  final double taxRate;
  final double amount;

  double get taxAmount => amount * taxRate / 100;
}

class PurchaseOrderItemDraft {
  const PurchaseOrderItemDraft({
    this.itemId,
    required this.itemName,
    this.account = 'Cost of Goods Sold',
    required this.quantity,
    this.unit = 'pcs',
    required this.rate,
    this.tax = 'GST 18%',
    this.taxRate = 18.0,
    required this.amount,
  });

  final int? itemId;
  final String itemName;
  final String account;
  final double quantity;
  final String unit;
  final double rate;
  final String tax;
  final double taxRate;
  final double amount;

  double get taxAmount => amount * taxRate / 100;
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.number,
    this.vendorId,
    required this.vendorName,
    required this.date,
    required this.amount,
    this.reference = '',
    this.status = 'DRAFT',
    this.billedStatus = 'YET TO BE BILLED',
    this.deliveryDate,
    this.deliveryAddressType = 'Organization',
    this.deliveryAddress = '',
    this.customerId,
    this.customerName = '',
    this.shipmentPreference = '',
    this.paymentTerms = 'Due on Receipt',
    this.reverseCharge = false,
    this.notes = '',
    this.terms = '',
    this.subTotal = 0.0,
    this.discountType = '%',
    this.discountValue = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.tdsRate = 0.0,
    this.tdsAmount = 0.0,
    this.tcsRate = 0.0,
    this.tcsAmount = 0.0,
    this.roundOff = 0.0,
    this.attachments = const [],
    this.items = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  final int id;
  final int? vendorId;
  final String number;
  final String vendorName;
  final String reference;
  final String status;
  final String billedStatus;
  final DateTime date;
  final DateTime? deliveryDate;
  final String deliveryAddressType;
  final String deliveryAddress;
  final int? customerId;
  final String customerName;
  final String shipmentPreference;
  final String paymentTerms;
  final bool reverseCharge;
  final String notes;
  final String terms;
  final double subTotal;
  final String discountType;
  final double discountValue;
  final double discountAmount;
  final double taxAmount;
  final double tdsRate;
  final double tdsAmount;
  final double tcsRate;
  final double tcsAmount;
  final double roundOff;
  final double amount;
  final List<String> attachments;
  final List<PurchaseOrderItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;

  bool get isEditable => status.toUpperCase() == 'DRAFT';
  bool get isLimitedEditable => status.toUpperCase() == 'SENT';
  bool get isReadOnly => !isEditable && !isLimitedEditable;
  bool get isBilled => billedStatus.toUpperCase() != 'YET TO BE BILLED' || status.toUpperCase() == 'BILLED';

  double get calculatedGstTotal => items.fold<double>(0, (sum, i) => sum + i.taxAmount);
}

class PurchaseOrderDraft {
  const PurchaseOrderDraft({
    required this.number,
    this.vendorId,
    required this.vendorName,
    required this.date,
    required this.amount,
    this.reference = '',
    this.status = 'DRAFT',
    this.deliveryDate,
    this.deliveryAddressType = 'Organization',
    this.deliveryAddress = '',
    this.customerId,
    this.customerName = '',
    this.shipmentPreference = '',
    this.paymentTerms = 'Due on Receipt',
    this.reverseCharge = false,
    this.notes = '',
    this.terms = '',
    this.subTotal = 0.0,
    this.discountType = '%',
    this.discountValue = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.tdsRate = 0.0,
    this.tdsAmount = 0.0,
    this.tcsRate = 0.0,
    this.tcsAmount = 0.0,
    this.roundOff = 0.0,
    this.attachments = const [],
    this.items = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  final int? vendorId;
  final String number;
  final String vendorName;
  final String reference;
  final String status;
  final DateTime date;
  final DateTime? deliveryDate;
  final String deliveryAddressType;
  final String deliveryAddress;
  final int? customerId;
  final String customerName;
  final String shipmentPreference;
  final String paymentTerms;
  final bool reverseCharge;
  final String notes;
  final String terms;
  final double subTotal;
  final String discountType;
  final double discountValue;
  final double discountAmount;
  final double taxAmount;
  final double tdsRate;
  final double tdsAmount;
  final double tcsRate;
  final double tcsAmount;
  final double roundOff;
  final double amount;
  final List<String> attachments;
  final List<PurchaseOrderItemDraft> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;
}
