import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_vendor_repository.dart';
import '../domain/vendor.dart';
import '../domain/vendor_repository.dart';

// Firestore implementation active.
final vendorRepositoryProvider = Provider<VendorRepository>(
  (ref) => FirebaseVendorRepository(),
);

final vendorsProvider = FutureProvider<List<Vendor>>(
  (ref) => ref.watch(vendorRepositoryProvider).getVendors(),
);
