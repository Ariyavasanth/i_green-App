import 'expense.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> getExpenses();
  Stream<List<Expense>> watchExpenses();
  Future<void> addExpense({
    required DateTime date,
    required String account,
    required String reference,
    required String vendor,
    required String paidThrough,
    required String customer,
    required String status,
    required double amount,
    String? projectCode,
    String? projectId,
  });
}

