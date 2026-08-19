import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firebase_purchase_order_repository.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

// Firestore implementation active as requested by user
final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>(
  (ref) => FirebasePurchaseOrderRepository(),
);

final purchaseOrdersProvider = FutureProvider<List<PurchaseOrder>>(
  (ref) => ref.watch(purchaseOrderRepositoryProvider).getPurchaseOrders(),
);

final nextPoNumberProvider = FutureProvider<String>(
  (ref) => ref.watch(purchaseOrderRepositoryProvider).generateNextPoNumber(),
);
