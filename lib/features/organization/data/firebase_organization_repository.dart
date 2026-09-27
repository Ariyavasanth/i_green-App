import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../domain/business_unit.dart';
import '../domain/column_preference.dart';
import '../domain/department.dart';
import '../domain/designation.dart';
import '../domain/location.dart';
import '../domain/organization.dart';
import '../domain/organization_repository.dart';

/// Robust Firestore implementation of OrganizationRepository.
class FirebaseOrganizationRepository implements OrganizationRepository {
  final FirebaseFirestore? _customFirestore;

  FirebaseOrganizationRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore? get _firestore {
    try {
      return _customFirestore ?? FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _orgsRef => _firestore?.collection('organizations');
  CollectionReference<Map<String, dynamic>>? get _buRef => _firestore?.collection('business_units');
  CollectionReference<Map<String, dynamic>>? get _locationsRef => _firestore?.collection('locations');
  CollectionReference<Map<String, dynamic>>? get _deptsRef => _firestore?.collection('departments');
  CollectionReference<Map<String, dynamic>>? get _designationsRef => _firestore?.collection('designations');
  CollectionReference<Map<String, dynamic>>? get _colPrefRef => _firestore?.collection('column_preferences');

  final List<Organization> _memoryOrgs = [];
  final List<BusinessUnit> _memoryBUs = [];
  final List<Location> _memoryLocations = [];
  final List<Department> _memoryDepts = [];
  final List<Designation> _memoryDesignations = [];

  // --- Organization ---
  @override
  Future<List<Organization>> getOrganizations() async {
    try {
      final ref = _orgsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final orgs = <Organization>[];
        for (final doc in snapshot.docs) {
          final o = Organization.fromMap(doc.data());
          if (o.name.trim().toLowerCase() == 'igreen tech') {
            doc.reference.delete().ignore();
          } else {
            orgs.add(o);
          }
        }
        _memoryOrgs.clear();
        _memoryOrgs.addAll(orgs);
        return orgs;
      }
    } catch (e) {
      debugPrint('Error getting organizations from Firestore: $e');
    }
    _memoryOrgs.removeWhere((o) => o.name.trim().toLowerCase() == 'igreen tech');
    return List.from(_memoryOrgs);
  }

  @override
  Future<void> addOrganization(Organization organization) async {
    final nextId = organization.id != 0 ? organization.id : DateTime.now().millisecondsSinceEpoch;
    final orgWithId = organization.copyWith(id: nextId);

    _memoryOrgs.add(orgWithId);
    try {
      final ref = _orgsRef;
      if (ref != null) {
        await ref.doc('org_$nextId').set(orgWithId.toMap());
      }
    } catch (e) {
      debugPrint('Error adding organization: $e');
    }
  }

  @override
  Future<void> updateOrganization(Organization organization) async {
    final idx = _memoryOrgs.indexWhere((o) => o.id == organization.id);
    if (idx != -1) _memoryOrgs[idx] = organization; else _memoryOrgs.add(organization);
    try {
      final ref = _orgsRef;
      if (ref != null) {
        await ref.doc('org_${organization.id}').set(organization.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error updating organization: $e');
    }
  }

  @override
  Future<void> deleteOrganization(int id) async {
    _memoryOrgs.removeWhere((o) => o.id == id);
    try {
      final ref = _orgsRef;
      if (ref != null) await ref.doc('org_$id').delete();
    } catch (e) {
      debugPrint('Error deleting organization: $e');
    }
  }

  // --- Business Units ---
  @override
  Future<List<BusinessUnit>> getBusinessUnits({String? organizationName}) async {
    try {
      final ref = _buRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final list = snapshot.docs.map((doc) => BusinessUnit.fromMap(doc.data())).toList();
        _memoryBUs.clear();
        _memoryBUs.addAll(list);
      }
    } catch (e) {
      debugPrint('Error getting business units: $e');
    }

    // Merge business units listed inside Organization documents
    final allOrgs = await getOrganizations();
    final combinedBUs = List<BusinessUnit>.from(_memoryBUs);
    int extraId = 10000;
    for (final org in allOrgs) {
      if (org.businessUnits.isNotEmpty) {
        final buNames = org.businessUnits.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
        for (final buName in buNames) {
          if (!combinedBUs.any((b) => b.organizationName.trim().toLowerCase() == org.name.trim().toLowerCase() && b.unitName.trim().toLowerCase() == buName.toLowerCase())) {
            combinedBUs.add(BusinessUnit(
              id: extraId++,
              organizationName: org.name,
              unitName: buName,
              description: 'Business unit under ${org.name}',
            ));
          }
        }
      }
    }

    if (organizationName != null && organizationName.isNotEmpty) {
      return combinedBUs.where((bu) => bu.organizationName.isEmpty || bu.organizationName.trim().toLowerCase() == organizationName.trim().toLowerCase()).toList();
    }
    return combinedBUs;
  }

  @override
  Future<void> addBusinessUnit(BusinessUnit businessUnit) async {
    final nextId = businessUnit.id != 0 ? businessUnit.id : DateTime.now().millisecondsSinceEpoch;
    final item = businessUnit.copyWith(id: nextId);
    _memoryBUs.add(item);
    try {
      final ref = _buRef;
      if (ref != null) await ref.doc('bu_$nextId').set(item.toMap());
    } catch (e) {
      debugPrint('Error adding business unit: $e');
    }
  }

  @override
  Future<void> updateBusinessUnit(BusinessUnit businessUnit) async {
    final idx = _memoryBUs.indexWhere((b) => b.id == businessUnit.id);
    if (idx != -1) _memoryBUs[idx] = businessUnit; else _memoryBUs.add(businessUnit);
    try {
      final ref = _buRef;
      if (ref != null) await ref.doc('bu_${businessUnit.id}').set(businessUnit.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating business unit: $e');
    }
  }

  @override
  Future<void> deleteBusinessUnit(int id) async {
    _memoryBUs.removeWhere((b) => b.id == id);
    try {
      final ref = _buRef;
      if (ref != null) await ref.doc('bu_$id').delete();
    } catch (e) {
      debugPrint('Error deleting business unit: $e');
    }
  }

  // --- Locations ---
  @override
  Future<List<Location>> getLocations({String? organizationName, String? businessUnitName}) async {
    try {
      final ref = _locationsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final list = snapshot.docs.map((doc) => Location.fromMap(doc.data())).toList();
        _memoryLocations.clear();
        _memoryLocations.addAll(list);
      }
    } catch (e) {
      debugPrint('Error getting locations: $e');
    }

    // Merge locations listed inside Organization documents
    final allOrgs = await getOrganizations();
    final combinedLocations = List<Location>.from(_memoryLocations);
    int extraId = 20000;
    for (final org in allOrgs) {
      if (org.locations.isNotEmpty) {
        final locNames = org.locations.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
        for (final locName in locNames) {
          if (!combinedLocations.any((l) => l.organizationName.trim().toLowerCase() == org.name.trim().toLowerCase() && l.locationName.trim().toLowerCase() == locName.toLowerCase())) {
            combinedLocations.add(Location(
              id: extraId++,
              organizationName: org.name,
              businessUnitName: '',
              locationName: locName,
              address: org.address,
            ));
          }
        }
      }
    }

    var res = combinedLocations;
    if (organizationName != null && organizationName.isNotEmpty) {
      res = res.where((l) => l.organizationName.isEmpty || l.organizationName.trim().toLowerCase() == organizationName.trim().toLowerCase()).toList();
    }
    if (businessUnitName != null && businessUnitName.isNotEmpty) {
      res = res.where((l) => l.businessUnitName.isEmpty || l.businessUnitName.trim().toLowerCase() == businessUnitName.trim().toLowerCase()).toList();
    }
    return List.from(res);
  }

  @override
  Future<void> addLocation(Location location) async {
    final nextId = location.id != 0 ? location.id : DateTime.now().millisecondsSinceEpoch;
    final item = location.copyWith(id: nextId);
    _memoryLocations.add(item);
    try {
      final ref = _locationsRef;
      if (ref != null) await ref.doc('loc_$nextId').set(item.toMap());
    } catch (e) {
      debugPrint('Error adding location: $e');
    }
  }

  @override
  Future<void> updateLocation(Location location) async {
    final idx = _memoryLocations.indexWhere((l) => l.id == location.id);
    if (idx != -1) _memoryLocations[idx] = location; else _memoryLocations.add(location);
    try {
      final ref = _locationsRef;
      if (ref != null) await ref.doc('loc_${location.id}').set(location.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  @override
  Future<void> deleteLocation(int id) async {
    _memoryLocations.removeWhere((l) => l.id == id);
    try {
      final ref = _locationsRef;
      if (ref != null) await ref.doc('loc_$id').delete();
    } catch (e) {
      debugPrint('Error deleting location: $e');
    }
  }

  // --- Departments ---
  @override
  Future<List<Department>> getDepartments({String? organizationName, String? businessUnitName, String? workLocation}) async {
    try {
      final ref = _deptsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final list = snapshot.docs.map((doc) => Department.fromMap(doc.data())).toList();
        list.sort((a, b) => a.id.compareTo(b.id));
        _memoryDepts.clear();
        _memoryDepts.addAll(list);
      }
    } catch (e) {
      debugPrint('Error getting departments: $e');
    }
    var res = _memoryDepts;
    if (organizationName != null && organizationName.isNotEmpty) {
      res = res.where((d) => d.organizationName.isEmpty || d.organizationName == organizationName).toList();
    }
    if (businessUnitName != null && businessUnitName.isNotEmpty) {
      res = res.where((d) => d.businessUnitName.isEmpty || d.businessUnitName == businessUnitName).toList();
    }
    if (workLocation != null && workLocation.isNotEmpty) {
      res = res.where((d) => d.workLocation.isEmpty || d.workLocation == workLocation).toList();
    }
    return List.from(res);
  }

  @override
  Future<void> addDepartment(Department department) async {
    final nextId = department.id != 0 ? department.id : DateTime.now().millisecondsSinceEpoch;
    final deptWithId = department.copyWith(id: nextId);
    _memoryDepts.add(deptWithId);
    try {
      final ref = _deptsRef;
      if (ref != null) await ref.doc('dept_$nextId').set(deptWithId.toMap());
    } catch (e) {
      debugPrint('Error adding department: $e');
    }
  }

  @override
  Future<void> updateDepartment(Department department) async {
    final idx = _memoryDepts.indexWhere((d) => d.id == department.id);
    if (idx != -1) _memoryDepts[idx] = department; else _memoryDepts.add(department);
    try {
      final ref = _deptsRef;
      if (ref != null) await ref.doc('dept_${department.id}').set(department.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating department: $e');
    }
  }

  @override
  Future<void> deleteDepartment(int id) async {
    _memoryDepts.removeWhere((d) => d.id == id);
    try {
      final ref = _deptsRef;
      if (ref != null) await ref.doc('dept_$id').delete();
    } catch (e) {
      debugPrint('Error deleting department: $e');
    }
  }

  // --- Designations ---
  @override
  Future<List<Designation>> getDesignations({String? organizationName, String? departmentName}) async {
    try {
      final ref = _designationsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final list = snapshot.docs.map((doc) {
          final desig = Designation.fromMap(doc.data());
          if (desig.organizationName.isEmpty) {
            final dept = _memoryDepts.where((dept) => dept.departmentName == desig.departmentName).firstOrNull;
            final org = (dept != null && dept.organizationName.isNotEmpty) ? dept.organizationName : '';
            return desig.copyWith(organizationName: org);
          }
          return desig;
        }).toList();
        list.sort((a, b) => a.id.compareTo(b.id));
        _memoryDesignations.clear();
        _memoryDesignations.addAll(list);
      }
    } catch (e) {
      debugPrint('Error getting designations: $e');
    }
    return _memoryDesignations.map((d) {
      if (d.organizationName.isEmpty) {
        final dept = _memoryDepts.where((dept) => dept.departmentName == d.departmentName).firstOrNull;
        final org = (dept != null && dept.organizationName.isNotEmpty) ? dept.organizationName : '';
        return d.copyWith(organizationName: org);
      }
      return d;
    }).where((d) {
      if (organizationName != null &&
          organizationName.isNotEmpty &&
          organizationName != 'All' &&
          d.organizationName.isNotEmpty &&
          d.organizationName.trim().toLowerCase() != organizationName.trim().toLowerCase()) {
        return false;
      }
      if (departmentName != null &&
          departmentName.isNotEmpty &&
          departmentName != 'All' &&
          d.departmentName.trim().toLowerCase() != departmentName.trim().toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<void> addDesignation(Designation designation) async {
    final nextId = designation.id != 0 ? designation.id : DateTime.now().millisecondsSinceEpoch;
    final item = designation.copyWith(id: nextId);
    _memoryDesignations.add(item);
    try {
      final ref = _designationsRef;
      if (ref != null) await ref.doc('desig_$nextId').set(item.toMap());
    } catch (e) {
      debugPrint('Error adding designation: $e');
    }
  }

  @override
  Future<void> updateDesignation(Designation designation) async {
    final idx = _memoryDesignations.indexWhere((d) => d.id == designation.id);
    if (idx != -1) _memoryDesignations[idx] = designation; else _memoryDesignations.add(designation);
    try {
      final ref = _designationsRef;
      if (ref != null) await ref.doc('desig_${designation.id}').set(designation.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating designation: $e');
    }
  }

  @override
  Future<void> deleteDesignation(int id) async {
    _memoryDesignations.removeWhere((d) => d.id == id);
    try {
      final ref = _designationsRef;
      if (ref != null) await ref.doc('desig_$id').delete();
    } catch (e) {
      debugPrint('Error deleting designation: $e');
    }
  }

  // --- Column Preferences ---
  @override
  Future<ColumnPreference?> getColumnPreference(String tableId) async {
    try {
      final ref = _colPrefRef;
      if (ref != null) {
        final doc = await ref.doc(tableId).get();
        if (doc.exists && doc.data() != null) {
          return ColumnPreference.fromMap(doc.data()!);
        }
      }
    } catch (e) {
      debugPrint('Error getting column preference: $e');
    }
    return null;
  }

  @override
  Future<void> saveColumnPreference(ColumnPreference preference) async {
    try {
      final ref = _colPrefRef;
      if (ref != null) {
        await ref.doc(preference.tableId).set(preference.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving column preference: $e');
    }
  }

  // --- Document Upload ---
  @override
  Future<OrgDocument> uploadDocument({
    required int orgId,
    required String docTitle,
    required dynamic file,
  }) async {
    String downloadUrl = '';
    String fileName = 'document';

    try {
      final platformFile = file is PlatformFile ? file : null;
      fileName = platformFile?.name ?? 'document';

      Uint8List? bytes = platformFile?.bytes;
      if (bytes == null && platformFile?.path != null && platformFile!.path!.isNotEmpty) {
        if (!kIsWeb) {
          final f = io.File(platformFile.path!);
          if (await f.exists()) {
            bytes = await f.readAsBytes();
          }
        }
      }

      if (bytes != null) {
        final storage = FirebaseStorage.instance;
        final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final cleanDocTitle = docTitle.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final storageRef = storage.ref().child('organizations/$orgId/$cleanDocTitle/${DateTime.now().millisecondsSinceEpoch}_$cleanFileName');
        
        final uploadTask = await storageRef.putData(
          bytes,
          SettableMetadata(contentType: _getContentType(platformFile?.extension)),
        );
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Error uploading organization document to Firebase Storage: $e');
    }

    return OrgDocument(
      title: docTitle,
      fileName: fileName,
      fileUrl: downloadUrl,
      uploadedAt: DateTime.now().toIso8601String(),
    );
  }

  String _getContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
