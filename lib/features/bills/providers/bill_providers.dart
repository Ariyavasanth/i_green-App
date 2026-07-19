import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sqlite_bill_repository.dart';
import '../domain/bill.dart';
import '../domain/bill_repository.dart';

final billRepositoryProvider = Provider<BillRepository>((ref) => SqliteBillRepository());
final billsProvider = FutureProvider<List<Bill>>((ref) => ref.watch(billRepositoryProvider).getBills());
