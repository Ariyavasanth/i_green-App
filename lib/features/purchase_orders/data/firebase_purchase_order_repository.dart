import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

/// Firestore stub — returns safe empty values until fully implemented.
class FirebasePurchaseOrderRepository implements PurchaseOrderRepository {
  @override Future<List<PurchaseOrder>> getPurchaseOrders() async => [];
  @override Future<void> addPurchaseOrder(PurchaseOrderDraft draft) async {}
  @override Future<void> deletePurchaseOrder(int id) async {}
}
