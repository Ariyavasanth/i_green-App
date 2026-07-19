class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.number,
    required this.vendorName,
    required this.date,
    required this.amount,
    this.reference = '',
    this.status = 'DRAFT',
    this.billedStatus = 'YET TO BE BILLED',
    this.deliveryDate,
  });

  final int id;
  final String number, vendorName, reference, status, billedStatus;
  final DateTime date;
  final DateTime? deliveryDate;
  final double amount;
}

class PurchaseOrderDraft {
  const PurchaseOrderDraft({
    required this.number,
    required this.vendorName,
    required this.date,
    required this.amount,
    this.reference = '',
    this.deliveryDate,
  });

  final String number, vendorName, reference;
  final DateTime date;
  final DateTime? deliveryDate;
  final double amount;
}
