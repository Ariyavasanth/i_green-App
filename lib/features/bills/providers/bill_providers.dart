import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firebase_bill_repository.dart';
import '../domain/bill.dart';
import '../domain/bill_repository.dart';

// Firestore implementation active.
final billRepositoryProvider = Provider<BillRepository>((ref) => FirebaseBillRepository());
final billsProvider = FutureProvider<List<Bill>>((ref) => ref.watch(billRepositoryProvider).getBills());
