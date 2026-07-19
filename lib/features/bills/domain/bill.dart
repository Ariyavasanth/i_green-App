class Bill {
  const Bill({required this.id, required this.number, required this.vendorName, required this.date, required this.dueDate, required this.amount, this.reference = '', this.status = 'DRAFT'});
  final int id;
  final String number, vendorName, reference, status;
  final DateTime date, dueDate;
  final double amount;
}

class BillDraft {
  const BillDraft({required this.number, required this.vendorName, required this.date, required this.dueDate, required this.amount, this.reference = ''});
  final String number, vendorName, reference;
  final DateTime date, dueDate;
  final double amount;
}
