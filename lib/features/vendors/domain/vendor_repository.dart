import 'vendor.dart';

abstract interface class VendorRepository {
  Future<List<Vendor>> getVendors({bool includeInactive = true});
  Future<Vendor?> getVendorById(int id);
  Future<int> createVendor(Vendor vendor);
  Future<void> updateVendor(Vendor vendor);
  Future<void> deleteVendor(int id);
  Future<String> generateNextVendorCode();
}
