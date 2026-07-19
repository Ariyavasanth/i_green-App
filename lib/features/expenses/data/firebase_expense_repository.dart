import '../domain/expense.dart';
import '../domain/expense_repository.dart';

class FirebaseExpenseRepository implements ExpenseRepository {
  @override
  Future<List<Expense>> getExpenses() => throw UnimplementedError(
    'Firebase expense repository is not configured yet.',
  );

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
  }) => throw UnimplementedError(
    'Firebase expense repository is not configured yet.',
  );
}

