import '../domain/vendor.dart';
import '../domain/vendor_repository.dart';

/// Firestore stub — returns safe empty values until fully implemented.
class FirebaseVendorRepository implements VendorRepository {
  @override Future<List<Vendor>> getVendors() async => [];
}
