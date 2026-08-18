import '../domain/vendor.dart';
import '../domain/vendor_repository.dart';

/// Firestore repository implementation for Vendors.
class FirebaseVendorRepository implements VendorRepository {
  @override
  Future<List<Vendor>> getVendors() async => const [
        Vendor(id: 1, name: 'ABC Suppliers', companyName: 'ABC Suppliers', gstTreatment: 'Registered Business - Regular'),
        Vendor(id: 2, name: 'Sri Murugan Traders', companyName: 'Sri Murugan Traders', gstTreatment: 'Registered Business - Regular'),
        Vendor(id: 3, name: 'Global Enterprises', companyName: 'Global Enterprises', gstTreatment: 'Registered Business - Regular'),
        Vendor(id: 4, name: 'ABC Distributors', companyName: 'ABC Distributors', gstTreatment: 'Registered Business - Regular'),
        Vendor(id: 5, name: 'Local Supplier', companyName: 'Local Supplier', gstTreatment: 'Registered Business - Regular'),
        Vendor(id: 6, name: 'IGreen Technologies', companyName: 'IGreen Technologies', gstTreatment: 'Registered Business - Regular'),
        Vendor(id: 7, name: 'RS Industrial Equipments', companyName: 'RS Industrial Equipments', gstTreatment: 'Registered Business - Regular'),
      ];
}
