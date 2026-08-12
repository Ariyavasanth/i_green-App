import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_expense_repository.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';

// Firestore implementation active.
final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => FirebaseExpenseRepository(),
);

final expensesProvider = FutureProvider<List<Expense>>(
  (ref) => ref.watch(expenseRepositoryProvider).getExpenses(),
);

