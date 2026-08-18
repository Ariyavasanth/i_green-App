import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/vendor.dart';
import '../domain/vendor_repository.dart';

/// Firebase Firestore implementation for VendorRepository.
class FirebaseVendorRepository implements VendorRepository {
  final FirebaseFirestore? _customFirestore;

  FirebaseVendorRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _vendorsRef =>
      _firestore.collection('vendors');

  static final List<Vendor> _seedVendors = [
    const Vendor(
      id: 1,
      vendorCode: 'VEN-0001',
      displayName: 'IGreen Technologies',
      companyName: 'IGreen Technologies',
      gstTreatment: 'Registered Business - Regular',
      sourceOfSupply: 'Tamil Nadu',
      status: 'Active',
    ),
    const Vendor(
      id: 2,
      vendorCode: 'VEN-0002',
      displayName: 'RS Industrial Equipments',
      companyName: 'RS Industrial Equipments',
      gstTreatment: 'Registered Business - Regular',
      sourceOfSupply: 'Tamil Nadu',
      status: 'Active',
    ),
    const Vendor(
      id: 3,
      vendorCode: 'VEN-0003',
      displayName: 'RAJLAXMI METAL SUPPLYS',
      companyName: 'RAJLAXMI METAL SUPPLYS',
      gstTreatment: 'Registered Business - Regular',
      sourceOfSupply: 'Tamil Nadu',
      status: 'Active',
    ),
    const Vendor(
      id: 4,
      vendorCode: 'VEN-0004',
      displayName: 'MAHAVIR METAL CORP/RAJLAXMI METALS SUPPLYS',
      companyName: 'MAHAVIR METAL CORP',
      gstTreatment: 'Registered Business - Regular',
      sourceOfSupply: 'Tamil Nadu',
      status: 'Active',
    ),
    const Vendor(
      id: 5,
      vendorCode: 'VEN-0005',
      displayName: 'Srinivaas Additives & Labs',
      companyName: 'Srinivaas Additives & Labs',
      gstTreatment: 'Registered Business - Regular',
      sourceOfSupply: 'Tamil Nadu',
      status: 'Active',
    ),
    const Vendor(
      id: 6,
      vendorCode: 'VEN-0006',
      displayName: 'Balambiga metal finishers',
      companyName: 'Balambiga metal finishers',
      gstTreatment: 'Registered Business - Regular',
      sourceOfSupply: 'Tamil Nadu',
      status: 'Active',
    ),
    const Vendor(
      id: 7,
      vendorCode: 'VEN-0007',
      displayName: 'The Light Companie',
      companyName: 'The Light Companie',
      gstTreatment: 'Registered Business - Regular',
      sourceOfSupply: 'Tamil Nadu',
      status: 'Active',
    ),
    const Vendor(
      id: 8,
      vendorCode: 'VEN-0008',
      displayName: 'M K Enterprises',
      companyName: 'M K Enterprises',
      gstTreatment: 'Registered Business - Regular',
      sourceOfSupply: 'Tamil Nadu',
      status: 'Active',
    ),
  ];

  static final List<Vendor> _localStore = List<Vendor>.from(_seedVendors);

  @override
  Future<String> generateNextVendorCode() async {
    try {
      final snap = await _vendorsRef.get();
      if (snap.docs.isNotEmpty) {
        int maxNum = 0;
        for (final doc in snap.docs) {
          final code = (doc.data()['vendorCode'] as String?) ?? '';
          final numStr = code.replaceAll(RegExp(r'[^0-9]'), '');
          final n = int.tryParse(numStr) ?? 0;
          if (n > maxNum) maxNum = n;
        }
        return 'VEN-${(maxNum + 1).toString().padLeft(4, '0')}';
      }
    } catch (e) {
      debugPrint('Firestore generateNextVendorCode error: $e');
    }

    int maxNum = 0;
    for (final v in _localStore) {
      final numStr = v.vendorCode.replaceAll(RegExp(r'[^0-9]'), '');
      final n = int.tryParse(numStr) ?? 0;
      if (n > maxNum) maxNum = n;
    }
    return 'VEN-${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  @override
  Future<List<Vendor>> getVendors({bool includeInactive = true}) async {
    try {
      final snap = await _vendorsRef.get();
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => _mapDocToVendor(doc)).toList();
        if (!includeInactive) {
          return list.where((v) => v.status == 'Active').toList();
        }
        return list;
      } else {
        // Populate Firestore initial collection
        for (final vendor in _seedVendors) {
          await _vendorsRef.doc(vendor.id.toString()).set(_mapVendorToData(vendor));
        }
      }
    } catch (e) {
      debugPrint('Firestore getVendors error: $e');
    }

    if (!includeInactive) {
      return _localStore.where((v) => v.status == 'Active').toList();
    }
    return List.unmodifiable(_localStore);
  }

  @override
  Future<Vendor?> getVendorById(int id) async {
    try {
      final doc = await _vendorsRef.doc(id.toString()).get();
      if (doc.exists) {
        return _mapDocToVendor(doc);
      }
    } catch (e) {
      debugPrint('Firestore getVendorById error: $e');
    }
    final index = _localStore.indexWhere((v) => v.id == id);
    return index != -1 ? _localStore[index] : null;
  }

  @override
  Future<int> createVendor(Vendor vendor) async {
    var code = vendor.vendorCode.trim();
    if (code.isEmpty) {
      code = await generateNextVendorCode();
    }

    final id = vendor.id == 0
        ? DateTime.now().millisecondsSinceEpoch
        : vendor.id;

    final newVendor = vendor.copyWith(id: id, vendorCode: code);
    _localStore.insert(0, newVendor);

    try {
      await _vendorsRef.doc(id.toString()).set(_mapVendorToData(newVendor));
    } catch (e) {
      debugPrint('Firestore createVendor error: $e');
    }
    return id;
  }

  @override
  Future<void> updateVendor(Vendor vendor) async {
    final index = _localStore.indexWhere((v) => v.id == vendor.id);
    if (index != -1) {
      _localStore[index] = vendor;
    } else {
      _localStore.insert(0, vendor);
    }

    try {
      await _vendorsRef.doc(vendor.id.toString()).set(_mapVendorToData(vendor), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updateVendor error: $e');
    }
  }

  @override
  Future<void> deleteVendor(int id) async {
    _localStore.removeWhere((v) => v.id == id);
    try {
      await _vendorsRef.doc(id.toString()).delete();
    } catch (e) {
      debugPrint('Firestore deleteVendor error: $e');
    }
  }

  Map<String, dynamic> _mapVendorToData(Vendor vendor) {
    return {
      'id': vendor.id,
      'vendorCode': vendor.vendorCode,
      'displayName': vendor.displayName,
      'companyName': vendor.companyName,
      'salutation': vendor.salutation,
      'firstName': vendor.firstName,
      'lastName': vendor.lastName,
      'email': vendor.email,
      'workPhone': vendor.workPhone,
      'mobile': vendor.mobile,
      'gstTreatment': vendor.gstTreatment,
      'sourceOfSupply': vendor.sourceOfSupply,
      'pan': vendor.pan,
      'msmeRegistered': vendor.msmeRegistered,
      'currency': vendor.currency,
      'openingBalance': vendor.openingBalance,
      'paymentTerms': vendor.paymentTerms,
      'tds': vendor.tds,
      'status': vendor.status,
      'remarks': vendor.remarks,
      'payables': vendor.payables,
      'createdAt': vendor.createdAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'primaryAddress': vendor.primaryAddress != null
          ? {
              'addressLine1': vendor.primaryAddress!.addressLine1,
              'addressLine2': vendor.primaryAddress!.addressLine2,
              'city': vendor.primaryAddress!.city,
              'state': vendor.primaryAddress!.state,
              'country': vendor.primaryAddress!.country,
              'pinCode': vendor.primaryAddress!.pinCode,
            }
          : null,
      'contactPersons': vendor.contactPersons
          .map((c) => {
                'salutation': c.salutation,
                'firstName': c.firstName,
                'lastName': c.lastName,
                'designation': c.designation,
                'department': c.department,
                'email': c.email,
                'phone': c.phone,
                'mobile': c.mobile,
                'isPrimary': c.isPrimary,
              })
          .toList(),
      'bankAccounts': vendor.bankAccounts
          .map((b) => {
                'bankName': b.bankName,
                'accountHolderName': b.accountHolderName,
                'accountNumber': b.accountNumber,
                'ifscCode': b.ifscCode,
                'branch': b.branch,
                'accountType': b.accountType,
              })
          .toList(),
      'documentPaths': vendor.documentPaths,
    };
  }

  Vendor _mapDocToVendor(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final id = (data['id'] as num?)?.toInt() ?? doc.id.hashCode;

    VendorAddress? address;
    if (data['primaryAddress'] != null && data['primaryAddress'] is Map) {
      final addrMap = data['primaryAddress'] as Map;
      address = VendorAddress(
        addressLine1: addrMap['addressLine1'] as String? ?? '',
        addressLine2: addrMap['addressLine2'] as String? ?? '',
        city: addrMap['city'] as String? ?? '',
        state: addrMap['state'] as String? ?? '',
        country: addrMap['country'] as String? ?? 'India',
        pinCode: addrMap['pinCode'] as String? ?? '',
      );
    }

    final contactsList = <VendorContactPerson>[];
    if (data['contactPersons'] != null && data['contactPersons'] is List) {
      for (final item in data['contactPersons'] as List) {
        if (item is Map) {
          contactsList.add(VendorContactPerson(
            salutation: item['salutation'] as String? ?? '',
            firstName: item['firstName'] as String? ?? '',
            lastName: item['lastName'] as String? ?? '',
            designation: item['designation'] as String? ?? '',
            department: item['department'] as String? ?? '',
            email: item['email'] as String? ?? '',
            phone: item['phone'] as String? ?? '',
            mobile: item['mobile'] as String? ?? '',
            isPrimary: item['isPrimary'] as bool? ?? false,
          ));
        }
      }
    }

    final bankList = <VendorBankAccount>[];
    if (data['bankAccounts'] != null && data['bankAccounts'] is List) {
      for (final item in data['bankAccounts'] as List) {
        if (item is Map) {
          bankList.add(VendorBankAccount(
            bankName: item['bankName'] as String? ?? '',
            accountHolderName: item['accountHolderName'] as String? ?? '',
            accountNumber: item['accountNumber'] as String? ?? '',
            ifscCode: item['ifscCode'] as String? ?? '',
            branch: item['branch'] as String? ?? '',
            accountType: item['accountType'] as String? ?? '',
          ));
        }
      }
    }

    final docPaths = <String>[];
    if (data['documentPaths'] != null && data['documentPaths'] is List) {
      for (final item in data['documentPaths'] as List) {
        if (item is String) docPaths.add(item);
      }
    }

    return Vendor(
      id: id,
      vendorCode: data['vendorCode'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      companyName: data['companyName'] as String? ?? '',
      salutation: data['salutation'] as String? ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      workPhone: data['workPhone'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
      gstTreatment: data['gstTreatment'] as String? ?? 'Registered Business - Regular',
      sourceOfSupply: data['sourceOfSupply'] as String? ?? '',
      pan: data['pan'] as String? ?? '',
      msmeRegistered: data['msmeRegistered'] as bool? ?? false,
      currency: data['currency'] as String? ?? 'INR - Indian Rupee',
      openingBalance: (data['openingBalance'] as num?)?.toDouble() ?? 0.0,
      paymentTerms: data['paymentTerms'] as String? ?? 'Due on Receipt',
      tds: data['tds'] as String?,
      status: data['status'] as String? ?? 'Active',
      remarks: data['remarks'] as String? ?? '',
      payables: (data['payables'] as num?)?.toDouble() ?? 0.0,
      primaryAddress: address,
      contactPersons: contactsList,
      bankAccounts: bankList,
      documentPaths: docPaths,
    );
  }
}
