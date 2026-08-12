import '../domain/expense.dart';
import '../domain/expense_repository.dart';

/// Firestore stub — returns safe empty values until fully implemented.
class FirebaseExpenseRepository implements ExpenseRepository {
  @override
  Future<List<Expense>> getExpenses() async => [];

  @override
  Future<void> addExpense({
    required DateTime date,
    required String account,
    required String reference,
    required String vendor,
    required String paidThrough,
    required String customer,
    required String status,
    required double amount,
  }) async {}
}
