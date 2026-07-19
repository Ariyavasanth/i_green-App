import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sqlite_purchase_order_repository.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

// Change only this provider line when the Firebase implementation is ready.
final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>(
  (ref) => SqlitePurchaseOrderRepository(),
);
final purchaseOrdersProvider = FutureProvider<List<PurchaseOrder>>(
  (ref) => ref.watch(purchaseOrderRepositoryProvider).getPurchaseOrders(),
);
