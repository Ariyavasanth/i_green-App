import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sqlite_vendor_repository.dart';
import '../domain/vendor.dart';
import '../domain/vendor_repository.dart';

// Change only this provider line when the Firebase implementation is ready.
final vendorRepositoryProvider = Provider<VendorRepository>(
  (ref) => SqliteVendorRepository(),
);

final vendorsProvider = FutureProvider<List<Vendor>>(
  (ref) => ref.watch(vendorRepositoryProvider).getVendors(),
);
