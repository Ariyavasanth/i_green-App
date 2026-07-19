import '../domain/vendor.dart';
import '../domain/vendor_repository.dart';

class FirebaseVendorRepository implements VendorRepository {
  @override
  Future<List<Vendor>> getVendors() => throw UnimplementedError(
    'Firebase vendor repository is not configured yet.',
  );
}
