import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

class FirebasePurchaseOrderRepository implements PurchaseOrderRepository {
  Never _unconfigured() => throw UnimplementedError('Firebase purchase order repository is not configured yet.');
  @override
  Future<List<PurchaseOrder>> getPurchaseOrders() async => _unconfigured();
  @override
  Future<void> addPurchaseOrder(PurchaseOrderDraft draft) async => _unconfigured();
  @override
  Future<void> deletePurchaseOrder(int id) async => _unconfigured();
}
