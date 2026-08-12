import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firebase_purchase_order_repository.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

// Firestore implementation active.
final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>(
  (ref) => FirebasePurchaseOrderRepository(),
);
final purchaseOrdersProvider = FutureProvider<List<PurchaseOrder>>(
  (ref) => ref.watch(purchaseOrderRepositoryProvider).getPurchaseOrders(),
);
