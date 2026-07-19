import 'bill.dart';

abstract interface class BillRepository {
  Future<List<Bill>> getBills();
  Future<void> addBill(BillDraft bill);
  Future<void> deleteBill(int id);
}
