import 'purchase_order.dart';

abstract interface class PurchaseOrderRepository {
  Future<List<PurchaseOrder>> getPurchaseOrders();
  Future<void> addPurchaseOrder(PurchaseOrderDraft draft);
  Future<void> deletePurchaseOrder(int id);
}
