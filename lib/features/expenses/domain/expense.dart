class Expense {
  const Expense({
    required this.id,
    required this.date,
    required this.account,
    required this.reference,
    required this.vendor,
    required this.paidThrough,
    required this.customer,
    required this.status,
    required this.amount,
  });

  final int id;
  final DateTime date;
  final String account;
  final String reference;
  final String vendor;
  final String paidThrough;
  final String customer;
  final String status;
  final double amount;
}

