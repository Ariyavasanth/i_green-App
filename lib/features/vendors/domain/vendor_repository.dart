import 'vendor.dart';

abstract interface class VendorRepository {
  Future<List<Vendor>> getVendors();
}
