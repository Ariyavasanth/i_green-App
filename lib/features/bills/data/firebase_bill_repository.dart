import '../domain/bill.dart';
import '../domain/bill_repository.dart';

/// Firestore stub — returns safe empty values until fully implemented.
class FirebaseBillRepository implements BillRepository {
  @override Future<List<Bill>> getBills() async => [];
  @override Future<void> addBill(BillDraft bill) async {}
  @override Future<void> deleteBill(int id) async {}
}
