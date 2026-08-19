import 'purchase_order.dart';

abstract interface class PurchaseOrderRepository {
  Future<List<PurchaseOrder>> getPurchaseOrders();
  Future<PurchaseOrder?> getPurchaseOrderById(int id);
  Future<void> addPurchaseOrder(PurchaseOrderDraft draft);
  Future<void> updatePurchaseOrder(int id, PurchaseOrderDraft draft);
  Future<void> updatePoStatus(int id, String newStatus);
  Future<void> deletePurchaseOrder(int id);
  Future<String> generateNextPoNumber();
}
