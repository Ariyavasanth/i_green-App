import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sqlite_expense_repository.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';

// Change only this provider line when the Firebase implementation is ready.
final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => SqliteExpenseRepository(),
);

final expensesProvider = FutureProvider<List<Expense>>(
  (ref) => ref.watch(expenseRepositoryProvider).getExpenses(),
);

