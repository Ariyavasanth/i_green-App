import '../domain/bill.dart';
import '../domain/bill_repository.dart';

class FirebaseBillRepository implements BillRepository {
  @override Future<List<Bill>> getBills() => throw UnimplementedError('Firebase bill repository is not configured yet.');
  @override Future<void> addBill(BillDraft bill) => throw UnimplementedError('Firebase bill repository is not configured yet.');
  @override Future<void> deleteBill(int id) => throw UnimplementedError('Firebase bill repository is not configured yet.');
}
