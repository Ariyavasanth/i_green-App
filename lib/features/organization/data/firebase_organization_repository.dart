import 'dart:convert';
import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../domain/business_unit.dart';
import '../domain/column_preference.dart';
import '../domain/department.dart';
import '../domain/designation.dart';
import '../domain/location.dart';
import '../domain/organization.dart';
import '../domain/organization_band.dart';
import '../domain/organization_repository.dart';

/// Robust Firestore implementation of OrganizationRepository.
class FirebaseOrganizationRepository implements OrganizationRepository {
  final FirebaseFirestore? _customFirestore;
  final FirebaseStorage? _customStorage;

  FirebaseOrganizationRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _customFirestore = firestore,
       _customStorage = storage;

  FirebaseFirestore? get _firestore {
    try {
      return _customFirestore ?? FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>>? get _orgsRef =>
      _firestore?.collection('organizations');
  CollectionReference<Map<String, dynamic>>? get _buRef =>
      _firestore?.collection('business_units');
  CollectionReference<Map<String, dynamic>>? get _locationsRef =>
      _firestore?.collection('locations');
  CollectionReference<Map<String, dynamic>>? get _deptsRef =>
      _firestore?.collection('departments');
  CollectionReference<Map<String, dynamic>>? get _designationsRef =>
      _firestore?.collection('designations');
  CollectionReference<Map<String, dynamic>>? get _bandsRef =>
      _firestore?.collection('organization_bands');
  CollectionReference<Map<String, dynamic>>? get _bandLocksRef =>
      _firestore?.collection('organization_band_locks');
  CollectionReference<Map<String, dynamic>>? get _colPrefRef =>
      _firestore?.collection('column_preferences');

  static String _generateLockKey(String orgId, String type, String value) {
    final input = '${orgId.trim()}|$type|${value.trim().toLowerCase()}';
    final digest = sha256.convert(utf8.encode(input)).toString();
    return 'lock_${type}_$digest';
  }

  static String _generateLegacyLockKey(
    String orgId,
    String type,
    String value,
  ) {
    final cleanOrgId = orgId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final sanitizedValue = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return 'lock_${cleanOrgId}_${type}_$sanitizedValue';
  }

  final List<Organization> _memoryOrgs = [];
  final List<BusinessUnit> _memoryBUs = [];
  final List<Location> _memoryLocations = [];
  final List<Department> _memoryDepts = [];
  final List<Designation> _memoryDesignations = [];
  final List<OrganizationBand> _memoryBands = [];

  // --- Organization ---
  @override
  Future<List<Organization>> getOrganizations({
    bool includeInactive = true,
  }) async {
    try {
      final ref = _orgsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final orgs = <Organization>[];
        for (final doc in snapshot.docs) {
          final o = Organization.fromMap(doc.data(), doc.id);
          if (includeInactive || o.isActive) {
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
    return includeInactive
        ? List.from(_memoryOrgs)
        : _memoryOrgs.where((o) => o.isActive).toList();
  }

  @override
  Future<void> addOrganization(Organization organization) async {
    final nextId = organization.id != 0
        ? organization.id
        : DateTime.now().millisecondsSinceEpoch;
    final docKey = organization.docId.isNotEmpty
        ? organization.docId
        : 'org_$nextId';
    final orgWithId = organization.copyWith(id: nextId, docId: docKey);

    _memoryOrgs.add(orgWithId);
    try {
      final ref = _orgsRef;
      if (ref != null) {
        await ref.doc(docKey).set(orgWithId.toMap());
      }
    } catch (e) {
      debugPrint('Error adding organization: $e');
    }
  }

  @override
  Future<void> updateOrganization(Organization organization) async {
    final idx = _memoryOrgs.indexWhere(
      (o) =>
          (o.docId.isNotEmpty && o.docId == organization.docId) ||
          o.id == organization.id,
    );
    if (idx != -1)
      _memoryOrgs[idx] = organization;
    else
      _memoryOrgs.add(organization);
    try {
      final ref = _orgsRef;
      if (ref != null) {
        final docKey = organization.docId.isNotEmpty
            ? organization.docId
            : 'org_${organization.id}';
        await ref
            .doc(docKey)
            .set(organization.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error updating organization: $e');
    }
  }

  @override
  Future<void> deactivateOrganization(int id, [String? docId]) async {
    final docKey = docId ?? (id != 0 ? 'org_$id' : '');
    final idx = _memoryOrgs.indexWhere(
      (o) => (docKey.isNotEmpty && o.docId == docKey) || o.id == id,
    );
    if (idx != -1) {
      _memoryOrgs[idx] = _memoryOrgs[idx].copyWith(status: 'inactive');
    }
    try {
      final ref = _orgsRef;
      if (ref != null && docKey.isNotEmpty) {
        await ref.doc(docKey).set({
          'status': 'inactive',
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error deactivating organization: $e');
    }
  }

  @override
  Future<void> reactivateOrganization(int id, [String? docId]) async {
    final docKey = docId ?? (id != 0 ? 'org_$id' : '');
    final idx = _memoryOrgs.indexWhere(
      (o) => (docKey.isNotEmpty && o.docId == docKey) || o.id == id,
    );
    if (idx != -1) {
      _memoryOrgs[idx] = _memoryOrgs[idx].copyWith(status: 'active');
    }
    try {
      final ref = _orgsRef;
      if (ref != null && docKey.isNotEmpty) {
        await ref.doc(docKey).set({
          'status': 'active',
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error reactivating organization: $e');
    }
  }

  @override
  Future<Map<String, int>> checkOrganizationDependencies(
    String orgCanonicalId, [
    String? orgName,
  ]) async {
    final counts = <String, int>{
      'employees': 0,
      'departments': 0,
      'designations': 0,
      'business_units': 0,
      'locations': 0,
      'registration_links': 0,
    };
    final fs = _firestore;
    if (fs == null) return counts;

    final trimmedId = orgCanonicalId.trim();
    final trimmedName = (orgName ?? '').trim().toLowerCase();

    Future<int> countMatching(String collectionName) async {
      try {
        final snap = await fs.collection(collectionName).get();
        int c = 0;
        for (final d in snap.docs) {
          final data = d.data();
          final storedId =
              (data['organization_id'] ??
                      data['organizationId'] ??
                      data['org_id'])
                  ?.toString()
                  .trim();
          final storedName =
              (data['organization_name'] ?? data['organizationName'])
                  ?.toString()
                  .trim()
                  .toLowerCase();
          final bool matchId =
              trimmedId.isNotEmpty && storedId != null && storedId == trimmedId;
          final bool matchName =
              trimmedName.isNotEmpty &&
              storedName != null &&
              storedName == trimmedName;
          if (matchId || matchName) {
            c++;
          }
        }
        return c;
      } catch (_) {
        return 0;
      }
    }

    counts['employees'] = await countMatching('employees');
    counts['departments'] = await countMatching('departments');
    counts['designations'] = await countMatching('designations');
    counts['business_units'] = await countMatching('business_units');
    counts['locations'] = await countMatching('locations');
    counts['registration_links'] = await countMatching('registration_links');

    return counts;
  }

  @override
  Future<void> deleteOrganization(int id, [String? docId]) async {
    final docKey = docId ?? (id != 0 ? 'org_$id' : '');

    // Safety audit
    final org = _memoryOrgs
        .where((o) => (docKey.isNotEmpty && o.docId == docKey) || o.id == id)
        .firstOrNull;
    final deps = await checkOrganizationDependencies(docKey, org?.name);
    final totalDeps = deps.values.fold<int>(0, (sum, val) => sum + val);
    if (totalDeps > 0) {
      throw Exception(
        'Cannot permanently delete this organization because it has $totalDeps associated records '
        '(${deps.entries.where((e) => e.value > 0).map((e) => '${e.value} ${e.key}').join(', ')}). '
        'Please deactivate the organization instead.',
      );
    }

    _memoryOrgs.removeWhere(
      (o) => (docKey.isNotEmpty && o.docId == docKey) || o.id == id,
    );
    try {
      final ref = _orgsRef;
      if (ref != null && docKey.isNotEmpty) {
        await ref.doc(docKey).delete();
      }
    } catch (e) {
      debugPrint('Error deleting organization: $e');
    }
  }

  // --- Business Units ---
  @override
  Future<List<BusinessUnit>> getBusinessUnits({
    String? organizationName,
    String? organizationId,
  }) async {
    try {
      final ref = _buRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final list = snapshot.docs
            .map((doc) => BusinessUnit.fromMap(doc.data()))
            .toList();
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
        final buNames = org.businessUnits
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        for (final buName in buNames) {
          if (!combinedBUs.any(
            (b) =>
                b.organizationName.trim().toLowerCase() ==
                    org.name.trim().toLowerCase() &&
                b.unitName.trim().toLowerCase() == buName.toLowerCase(),
          )) {
            combinedBUs.add(
              BusinessUnit(
                id: extraId++,
                organizationId: org.canonicalId,
                organizationName: org.name,
                unitName: buName,
                description: 'Business unit under ${org.name}',
              ),
            );
          }
        }
      }
    }

    var res = combinedBUs;
    if (organizationId != null &&
        organizationId.isNotEmpty &&
        organizationId != 'All') {
      res = res
          .where(
            (bu) =>
                bu.organizationId.isEmpty ||
                bu.organizationId == organizationId,
          )
          .toList();
    } else if (organizationName != null &&
        organizationName.isNotEmpty &&
        organizationName != 'All') {
      res = res
          .where(
            (bu) =>
                bu.organizationName.isEmpty ||
                bu.organizationName.trim().toLowerCase() ==
                    organizationName.trim().toLowerCase(),
          )
          .toList();
    }
    return res;
  }

  @override
  Future<void> addBusinessUnit(BusinessUnit businessUnit) async {
    final nextId = businessUnit.id != 0
        ? businessUnit.id
        : DateTime.now().millisecondsSinceEpoch;
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
    if (idx != -1)
      _memoryBUs[idx] = businessUnit;
    else
      _memoryBUs.add(businessUnit);
    try {
      final ref = _buRef;
      if (ref != null)
        await ref
            .doc('bu_${businessUnit.id}')
            .set(businessUnit.toMap(), SetOptions(merge: true));
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
  Future<List<Location>> getLocations({
    String? organizationName,
    String? organizationId,
    String? businessUnitName,
  }) async {
    try {
      final ref = _locationsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final list = snapshot.docs
            .map((doc) => Location.fromMap(doc.data()))
            .toList();
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
        final locNames = org.locations
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        for (final locName in locNames) {
          if (!combinedLocations.any(
            (l) =>
                l.organizationName.trim().toLowerCase() ==
                    org.name.trim().toLowerCase() &&
                l.locationName.trim().toLowerCase() == locName.toLowerCase(),
          )) {
            combinedLocations.add(
              Location(
                id: extraId++,
                organizationId: org.canonicalId,
                organizationName: org.name,
                businessUnitName: '',
                locationName: locName,
                address: org.address,
              ),
            );
          }
        }
      }
    }

    var res = combinedLocations;
    if (organizationId != null &&
        organizationId.isNotEmpty &&
        organizationId != 'All') {
      res = res
          .where(
            (l) =>
                l.organizationId.isEmpty || l.organizationId == organizationId,
          )
          .toList();
    } else if (organizationName != null &&
        organizationName.isNotEmpty &&
        organizationName != 'All') {
      res = res
          .where(
            (l) =>
                l.organizationName.isEmpty ||
                l.organizationName.trim().toLowerCase() ==
                    organizationName.trim().toLowerCase(),
          )
          .toList();
    }
    if (businessUnitName != null &&
        businessUnitName.isNotEmpty &&
        businessUnitName != 'All') {
      res = res
          .where(
            (l) =>
                l.businessUnitName.isEmpty ||
                l.businessUnitName.trim().toLowerCase() ==
                    businessUnitName.trim().toLowerCase(),
          )
          .toList();
    }
    return List.from(res);
  }

  @override
  Future<void> addLocation(Location location) async {
    final nextId = location.id != 0
        ? location.id
        : DateTime.now().millisecondsSinceEpoch;
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
    if (idx != -1)
      _memoryLocations[idx] = location;
    else
      _memoryLocations.add(location);
    try {
      final ref = _locationsRef;
      if (ref != null)
        await ref
            .doc('loc_${location.id}')
            .set(location.toMap(), SetOptions(merge: true));
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
  Future<List<Department>> getDepartments({
    String? organizationName,
    String? organizationId,
    String? businessUnitName,
    String? workLocation,
  }) async {
    try {
      final ref = _deptsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final list = snapshot.docs
            .map((doc) => Department.fromMap(doc.data()))
            .toList();
        list.sort((a, b) => a.id.compareTo(b.id));
        _memoryDepts.clear();
        _memoryDepts.addAll(list);
      }
    } catch (e) {
      debugPrint('Error getting departments: $e');
    }
    var res = _memoryDepts;
    final hasOrgId =
        organizationId != null &&
        organizationId.isNotEmpty &&
        organizationId != 'All';
    final hasOrgName =
        organizationName != null &&
        organizationName.isNotEmpty &&
        organizationName != 'All';

    if (hasOrgId || hasOrgName) {
      res = res.where((d) {
        final dOrgId = d.organizationId.trim();
        final dOrgName = d.organizationName.trim().toLowerCase();

        final matchesId =
            hasOrgId && dOrgId.isNotEmpty && dOrgId == organizationId;
        final matchesName =
            hasOrgName &&
            dOrgName.isNotEmpty &&
            dOrgName == organizationName.trim().toLowerCase();

        return matchesId || matchesName;
      }).toList();
    }
    if (businessUnitName != null &&
        businessUnitName.isNotEmpty &&
        businessUnitName != 'All') {
      res = res
          .where(
            (d) =>
                d.businessUnitName.isNotEmpty &&
                d.businessUnitName == businessUnitName,
          )
          .toList();
    }
    if (workLocation != null &&
        workLocation.isNotEmpty &&
        workLocation != 'All') {
      res = res
          .where(
            (d) => d.workLocation.isNotEmpty && d.workLocation == workLocation,
          )
          .toList();
    }
    return List.from(res);
  }

  @override
  Future<void> addDepartment(Department department) async {
    final nextId = department.id != 0
        ? department.id
        : DateTime.now().millisecondsSinceEpoch;
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
    if (idx != -1)
      _memoryDepts[idx] = department;
    else
      _memoryDepts.add(department);
    try {
      final ref = _deptsRef;
      if (ref != null)
        await ref
            .doc('dept_${department.id}')
            .set(department.toMap(), SetOptions(merge: true));
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
  Future<List<Designation>> getDesignations({
    String? organizationName,
    String? organizationId,
    String? departmentName,
  }) async {
    try {
      final ref = _designationsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        final list = snapshot.docs.map((doc) {
          final desig = Designation.fromMap(doc.data());
          if (desig.organizationName.isEmpty) {
            final dept = _memoryDepts
                .where((dept) => dept.departmentName == desig.departmentName)
                .firstOrNull;
            final org = (dept != null && dept.organizationName.isNotEmpty)
                ? dept.organizationName
                : '';
            final oId = (dept != null && dept.organizationId.isNotEmpty)
                ? dept.organizationId
                : '';
            return desig.copyWith(organizationName: org, organizationId: oId);
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
    return _memoryDesignations
        .map((d) {
          if (d.organizationName.isEmpty) {
            final dept = _memoryDepts
                .where((dept) => dept.departmentName == d.departmentName)
                .firstOrNull;
            final org = (dept != null && dept.organizationName.isNotEmpty)
                ? dept.organizationName
                : '';
            final oId = (dept != null && dept.organizationId.isNotEmpty)
                ? dept.organizationId
                : '';
            return d.copyWith(organizationName: org, organizationId: oId);
          }
          return d;
        })
        .where((d) {
          if (organizationId != null &&
              organizationId.isNotEmpty &&
              organizationId != 'All' &&
              d.organizationId.isNotEmpty &&
              d.organizationId != organizationId) {
            return false;
          }
          if (organizationName != null &&
              organizationName.isNotEmpty &&
              organizationName != 'All' &&
              d.organizationName.isNotEmpty &&
              d.organizationName.trim().toLowerCase() !=
                  organizationName.trim().toLowerCase()) {
            return false;
          }
          if (departmentName != null &&
              departmentName.isNotEmpty &&
              departmentName != 'All' &&
              d.departmentName.trim().toLowerCase() !=
                  departmentName.trim().toLowerCase()) {
            return false;
          }
          return true;
        })
        .toList();
  }

  @override
  Future<void> addDesignation(Designation designation) async {


    final nextId = designation.id != 0
        ? designation.id
        : DateTime.now().millisecondsSinceEpoch;
    final item = designation.copyWith(id: nextId);
    _memoryDesignations.add(item);

    // In-memory reference count update
    if (designation.bandId.isNotEmpty) {
      final bIdx = _memoryBands.indexWhere((b) => b.id == designation.bandId);
      if (bIdx != -1) {
        final b = _memoryBands[bIdx];
        _memoryBands[bIdx] = b.copyWith(
          designationCount: b.designationCount + 1,
        );
      }
    }

    try {
      final firestore = _firestore;
      final desigRef = _designationsRef?.doc('desig_$nextId');
      final bandsRef = _bandsRef;

      if (firestore != null && desigRef != null && bandsRef != null) {
        if (designation.bandId.isNotEmpty) {
          final bandDocRef = bandsRef.doc(designation.bandId);
          await firestore.runTransaction((transaction) async {
            final bSnap = await transaction.get(bandDocRef);
            if (bSnap.exists) {
              final currentCount =
                  (bSnap.data()?['designation_count'] as num?)?.toInt() ?? 0;
              transaction.update(bandDocRef, {
                'designation_count': currentCount + 1,
              });
            }

            final currentCount =
                (bSnap.data()?['designation_count'] as num?)?.toInt() ?? 0;
            transaction.update(bandDocRef, {
              'designation_count': currentCount + 1,
            });
            transaction.set(desigRef, item.toMap());
          });
        } else {
          await desigRef.set(item.toMap());
        }
      }
    } catch (e) {
      debugPrint('Error adding designation: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateDesignation(Designation designation) async {


    final idx = _memoryDesignations.indexWhere((d) => d.id == designation.id);
    final oldDesig = idx != -1 ? _memoryDesignations[idx] : null;
    final oldBandId = oldDesig?.bandId ?? '';
    final newBandId = designation.bandId;

    if (idx != -1) {
      _memoryDesignations[idx] = designation;
    } else {
      _memoryDesignations.add(designation);
    }

    // In-memory reference count adjustments:
    // Only adjust when the previous designation record was known in cache and the Band genuinely changed.
    // If the cache was missing the record, in-memory counters remain untouched to prevent corrupt increments.
    if (oldDesig != null && oldBandId != newBandId) {
      if (oldBandId.isNotEmpty) {
        final oldBIdx = _memoryBands.indexWhere((b) => b.id == oldBandId);
        if (oldBIdx != -1) {
          final b = _memoryBands[oldBIdx];
          _memoryBands[oldBIdx] = b.copyWith(
            designationCount: b.designationCount > 0
                ? b.designationCount - 1
                : 0,
          );
        }
      }
      if (newBandId.isNotEmpty) {
        final newBIdx = _memoryBands.indexWhere((b) => b.id == newBandId);
        if (newBIdx != -1) {
          final b = _memoryBands[newBIdx];
          _memoryBands[newBIdx] = b.copyWith(
            designationCount: b.designationCount + 1,
          );
        }
      }
    }

    try {
      final firestore = _firestore;
      final desigRef = _designationsRef?.doc('desig_${designation.id}');
      final bandsRef = _bandsRef;

      if (firestore != null && desigRef != null && bandsRef != null) {
        await firestore.runTransaction((transaction) async {
          final desigSnap = await transaction.get(desigRef);
          final storedOldBandId = desigSnap.exists
              ? ((desigSnap.data()?['band_id'] ?? desigSnap.data()?['bandId'])
                        ?.toString() ??
                    '')
              : oldBandId;

          // Only modify Band counters when storedOldBandId and newBandId genuinely differ.
          // If the IDs are identical (same-Band update or cache-miss re-saving same Band),
          // Band counters are left completely untouched.
          if (storedOldBandId != newBandId) {
            DocumentSnapshot<Map<String, dynamic>>? oldBSnap;
            DocumentSnapshot<Map<String, dynamic>>? newBSnap;

            final oldBDocRef = storedOldBandId.isNotEmpty
                ? bandsRef.doc(storedOldBandId)
                : null;
            final newBDocRef = newBandId.isNotEmpty
                ? bandsRef.doc(newBandId)
                : null;

            // All transaction reads MUST precede all transaction writes
            if (oldBDocRef != null) {
              oldBSnap = await transaction.get(oldBDocRef);
            }
            if (newBDocRef != null) {
              newBSnap = await transaction.get(newBDocRef);
            }

            // Transaction writes
            if (oldBDocRef != null && oldBSnap != null && oldBSnap.exists) {
              final oldCount =
                  (oldBSnap.data()?['designation_count'] as num?)?.toInt() ?? 0;
              transaction.update(oldBDocRef, {
                'designation_count': oldCount > 0 ? oldCount - 1 : 0,
              });
            }

            if (newBDocRef != null && newBSnap != null && newBSnap.exists) {
              final newCount =
                  (newBSnap.data()?['designation_count'] as num?)?.toInt() ?? 0;
              transaction.update(newBDocRef, {
                'designation_count': newCount + 1,
              });
            }
          }

          transaction.set(
            desigRef,
            designation.toMap(),
            SetOptions(merge: true),
          );
        });
      }
    } catch (e) {
      debugPrint('Error updating designation: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDesignation(int id) async {
    final desigIndex = _memoryDesignations.indexWhere((d) => d.id == id);
    final currentDesig = desigIndex != -1
        ? _memoryDesignations[desigIndex]
        : null;
    final bandId = currentDesig?.bandId ?? '';

    _memoryDesignations.removeWhere((d) => d.id == id);

    // Decrement in-memory reference count
    if (bandId.isNotEmpty) {
      final bIdx = _memoryBands.indexWhere((b) => b.id == bandId);
      if (bIdx != -1) {
        final currentB = _memoryBands[bIdx];
        _memoryBands[bIdx] = currentB.copyWith(
          designationCount: currentB.designationCount > 0
              ? currentB.designationCount - 1
              : 0,
        );
      }
    }

    try {
      final firestore = _firestore;
      final desigRef = _designationsRef?.doc('desig_$id');
      final bandsRef = _bandsRef;

      if (firestore != null && desigRef != null && bandsRef != null) {
        await firestore.runTransaction((transaction) async {
          final dSnap = await transaction.get(desigRef);
          if (dSnap.exists) {
            final storedBandId =
                (dSnap.data()?['band_id'] ?? dSnap.data()?['bandId'])
                    ?.toString() ??
                '';
            if (storedBandId.isNotEmpty) {
              final bDocRef = bandsRef.doc(storedBandId);
              final bSnap = await transaction.get(bDocRef);
              if (bSnap.exists) {
                final currentCount =
                    (bSnap.data()?['designation_count'] as num?)?.toInt() ?? 0;
                transaction.update(bDocRef, {
                  'designation_count': currentCount > 0 ? currentCount - 1 : 0,
                });
              }
            }
            transaction.delete(desigRef);
          }
        });
      }
    } catch (e) {
      debugPrint('Error deleting designation: $e');
      rethrow;
    }
  }

  // --- Organization Bands ---
  @override
  Future<List<OrganizationBand>> getBands({
    String? organizationId,
    String? organizationName,
  }) async {
    final hasOrgId =
        organizationId != null &&
        organizationId.isNotEmpty &&
        organizationId != 'All';
    final hasOrgName =
        organizationName != null &&
        organizationName.isNotEmpty &&
        organizationName != 'All';

    try {
      final ref = _bandsRef;
      if (ref != null) {
        final Query<Map<String, dynamic>> query = hasOrgId
            ? ref.where('organization_id', isEqualTo: organizationId.trim())
            : ref;
        final snapshot = await query.get();
        final list = snapshot.docs
            .map((doc) => OrganizationBand.fromMap(doc.data(), doc.id))
            .toList();
        list.sort(); // Natural sort descending by level (Band 7 down to Band 1)
        if (hasOrgId) {
          _memoryBands.removeWhere(
            (b) => b.organizationId.trim() == organizationId.trim(),
          );
          _memoryBands.addAll(list);
        } else {
          _memoryBands.clear();
          _memoryBands.addAll(list);
        }
      }
    } catch (e) {
      debugPrint('Error getting organization bands: $e');
    }

    var res = _memoryBands;

    if (hasOrgId) {
      // Strict canonical organizationId filter — never merged with organizationName
      res = res
          .where((b) => b.organizationId.trim() == organizationId.trim())
          .toList();
    } else if (hasOrgName) {
      // Isolated legacy fallback by organizationName only when organizationId is NOT provided
      res = res
          .where(
            (b) =>
                b.organizationName.trim().toLowerCase() ==
                organizationName.trim().toLowerCase(),
          )
          .toList();
    }

    res.sort(); // Highest level first (7 down to 1)
    return List.from(res);
  }

  @override
  Future<void> addBand(OrganizationBand band) async {
    if (band.organizationId.trim().isEmpty) {
      throw ArgumentError(
        'A valid canonical organizationId is required to create a Band.',
      );
    }
    if (band.level < 1 || band.level > 7) {
      throw ArgumentError(
        'Band level must be between 1 and 7 (Band 7 is highest, Band 1 is entry level).',
      );
    }
    if (band.bandCode.trim().isEmpty) {
      throw ArgumentError('Band code cannot be empty.');
    }

    // In-memory duplicate checks against existing bands in the same organization
    final existingBands = await getBands(organizationId: band.organizationId);
    if (existingBands.any((b) => b.level == band.level)) {
      throw ArgumentError(
        'Band level ${band.level} already exists in this organization.',
      );
    }
    final codeLower = band.bandCode.trim().toLowerCase();
    if (existingBands.any(
      (b) => b.bandCode.trim().toLowerCase() == codeLower,
    )) {
      throw ArgumentError(
        'Band code "${band.bandCode}" already exists in this organization.',
      );
    }

    final lvlLockKey = _generateLockKey(
      band.organizationId,
      'lvl',
      '${band.level}',
    );
    final codeLockKey = _generateLockKey(
      band.organizationId,
      'code',
      codeLower,
    );
    final legacyLvlLockKey = _generateLegacyLockKey(
      band.organizationId,
      'lvl',
      '${band.level}',
    );
    final legacyCodeLockKey = _generateLegacyLockKey(
      band.organizationId,
      'code',
      codeLower,
    );

    final cleanOrgId = band.organizationId.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final docId = band.id.isNotEmpty
        ? band.id
        : 'band_${cleanOrgId}_lvl_${band.level}';
    final bandWithId = band.copyWith(id: docId);

    // Firestore transactional uniqueness enforcement using collision-resistant lock documents
    final firestore = _firestore;
    final bandsRef = _bandsRef;
    final locksRef = _bandLocksRef;

    if (firestore != null && bandsRef != null && locksRef != null) {
      final lvlLockRef = locksRef.doc(lvlLockKey);
      final codeLockRef = locksRef.doc(codeLockKey);
      final legacyLvlLockRef = locksRef.doc(legacyLvlLockKey);
      final legacyCodeLockRef = locksRef.doc(legacyCodeLockKey);
      final bandDocRef = bandsRef.doc(docId);

      await firestore.runTransaction((transaction) async {
        final lvlSnap = await transaction.get(lvlLockRef);
        if (lvlSnap.exists && lvlSnap.data()?['band_id'] != docId) {
          throw ArgumentError(
            'Band level ${band.level} already exists in this organization.',
          );
        }

        final legacyLvlSnap = await transaction.get(legacyLvlLockRef);
        if (legacyLvlSnap.exists && legacyLvlSnap.data()?['band_id'] != docId) {
          throw ArgumentError(
            'Band level ${band.level} already exists in this organization.',
          );
        }

        final codeSnap = await transaction.get(codeLockRef);
        if (codeSnap.exists && codeSnap.data()?['band_id'] != docId) {
          throw ArgumentError(
            'Band code "${band.bandCode}" already exists in this organization.',
          );
        }

        final legacyCodeSnap = await transaction.get(legacyCodeLockRef);
        if (legacyCodeSnap.exists &&
            legacyCodeSnap.data()?['band_id'] != docId) {
          throw ArgumentError(
            'Band code "${band.bandCode}" already exists in this organization.',
          );
        }

        final bandSnap = await transaction.get(bandDocRef);
        if (bandSnap.exists) {
          throw StateError(
            'A band record with ID "$docId" already exists in this organization.',
          );
        }

        transaction.set(lvlLockRef, {
          'org_id': band.organizationId,
          'level': band.level,
          'band_id': docId,
          'created_at': FieldValue.serverTimestamp(),
        });

        transaction.set(codeLockRef, {
          'org_id': band.organizationId,
          'band_code': codeLower,
          'band_id': docId,
          'created_at': FieldValue.serverTimestamp(),
        });

        transaction.set(bandDocRef, bandWithId.toMap());
      });
    }

    _memoryBands.removeWhere((b) => b.id == docId);
    _memoryBands.add(bandWithId);
    _memoryBands.sort();
  }

  @override
  Future<void> updateBand(OrganizationBand band) async {
    if (band.id.trim().isEmpty) {
      throw ArgumentError('Band ID cannot be empty when updating a Band.');
    }
    if (band.organizationId.trim().isEmpty) {
      throw ArgumentError(
        'A valid canonical organizationId is required to update a Band.',
      );
    }
    if (band.level < 1 || band.level > 7) {
      throw ArgumentError('Band level must be between 1 and 7.');
    }
    if (band.bandCode.trim().isEmpty) {
      throw ArgumentError('Band code cannot be empty.');
    }

    // In-memory uniqueness check against other bands in the same organization
    final existingBands = await getBands(organizationId: band.organizationId);
    if (existingBands.any((b) => b.id != band.id && b.level == band.level)) {
      throw ArgumentError(
        'Another band in this organization already has level ${band.level}.',
      );
    }
    final codeLower = band.bandCode.trim().toLowerCase();
    if (existingBands.any(
      (b) => b.id != band.id && b.bandCode.trim().toLowerCase() == codeLower,
    )) {
      throw ArgumentError(
        'Another band in this organization already has band code "${band.bandCode}".',
      );
    }

    final newLvlLockKey = _generateLockKey(
      band.organizationId,
      'lvl',
      '${band.level}',
    );
    final newCodeLockKey = _generateLockKey(
      band.organizationId,
      'code',
      codeLower,
    );
    final newLegacyLvlLockKey = _generateLegacyLockKey(
      band.organizationId,
      'lvl',
      '${band.level}',
    );
    final newLegacyCodeLockKey = _generateLegacyLockKey(
      band.organizationId,
      'code',
      codeLower,
    );

    final firestore = _firestore;
    final bandsRef = _bandsRef;
    final locksRef = _bandLocksRef;

    if (firestore != null && bandsRef != null && locksRef != null) {
      final bandDocRef = bandsRef.doc(band.id);

      await firestore.runTransaction((transaction) async {
        final currentSnap = await transaction.get(bandDocRef);
        if (!currentSnap.exists) {
          throw StateError(
            'Cannot update band "${band.id}": document does not exist.',
          );
        }

        final currentData = currentSnap.data()!;
        final oldLevel = (currentData['level'] as num?)?.toInt() ?? 0;
        final oldCodeLower = (currentData['band_code']?.toString() ?? '')
            .trim()
            .toLowerCase();

        final newLvlLockRef = locksRef.doc(newLvlLockKey);
        final newCodeLockRef = locksRef.doc(newCodeLockKey);
        final newLegacyLvlLockRef = locksRef.doc(newLegacyLvlLockKey);
        final newLegacyCodeLockRef = locksRef.doc(newLegacyCodeLockKey);

        if (band.level != oldLevel) {
          final lvlSnap = await transaction.get(newLvlLockRef);
          if (lvlSnap.exists && lvlSnap.data()?['band_id'] != band.id) {
            throw ArgumentError(
              'Another band in this organization already has level ${band.level}.',
            );
          }
          final legacyLvlSnap = await transaction.get(newLegacyLvlLockRef);
          if (legacyLvlSnap.exists &&
              legacyLvlSnap.data()?['band_id'] != band.id) {
            throw ArgumentError(
              'Another band in this organization already has level ${band.level}.',
            );
          }
        }

        if (codeLower != oldCodeLower) {
          final codeSnap = await transaction.get(newCodeLockRef);
          if (codeSnap.exists && codeSnap.data()?['band_id'] != band.id) {
            throw ArgumentError(
              'Another band in this organization already has band code "${band.bandCode}".',
            );
          }
          final legacyCodeSnap = await transaction.get(newLegacyCodeLockRef);
          if (legacyCodeSnap.exists &&
              legacyCodeSnap.data()?['band_id'] != band.id) {
            throw ArgumentError(
              'Another band in this organization already has band code "${band.bandCode}".',
            );
          }
        }

        // Clean up old lock documents if level or code changed
        if (oldLevel != 0 && oldLevel != band.level) {
          final oldLvlLockKey = _generateLockKey(
            band.organizationId,
            'lvl',
            '$oldLevel',
          );
          final oldLegacyLvlLockKey = _generateLegacyLockKey(
            band.organizationId,
            'lvl',
            '$oldLevel',
          );
          transaction.delete(locksRef.doc(oldLvlLockKey));
          transaction.delete(locksRef.doc(oldLegacyLvlLockKey));
        }
        if (oldCodeLower.isNotEmpty && oldCodeLower != codeLower) {
          final oldCodeLockKey = _generateLockKey(
            band.organizationId,
            'code',
            oldCodeLower,
          );
          final oldLegacyCodeLockKey = _generateLegacyLockKey(
            band.organizationId,
            'code',
            oldCodeLower,
          );
          transaction.delete(locksRef.doc(oldCodeLockKey));
          transaction.delete(locksRef.doc(oldLegacyCodeLockKey));
        }

        // Set or update new locks
        transaction.set(newLvlLockRef, {
          'org_id': band.organizationId,
          'level': band.level,
          'band_id': band.id,
          'updated_at': FieldValue.serverTimestamp(),
        });
        transaction.set(newCodeLockRef, {
          'org_id': band.organizationId,
          'band_code': codeLower,
          'band_id': band.id,
          'updated_at': FieldValue.serverTimestamp(),
        });

        transaction.set(bandDocRef, band.toMap(), SetOptions(merge: true));
      });
    }

    final idx = _memoryBands.indexWhere((b) => b.id == band.id);
    if (idx != -1) {
      _memoryBands[idx] = band;
    } else {
      _memoryBands.add(band);
    }
    _memoryBands.sort();
  }

  @override
  Future<void> deleteBand(String id, {String? organizationId}) async {
    // Check if any designation references this band
    final allDesignations = await getDesignations(
      organizationId: organizationId,
    );
    final isReferenced = allDesignations.any((d) => d.bandId == id);
    if (isReferenced) {
      throw StateError(
        'Cannot delete band "$id": it is currently assigned to one or more designations.',
      );
    }

    // Check in-memory designationCount
    final matchingMemBand = _memoryBands.where((b) => b.id == id).firstOrNull;
    if (matchingMemBand != null && matchingMemBand.designationCount > 0) {
      throw StateError(
        'Cannot delete band "$id": it is currently assigned to ${matchingMemBand.designationCount} designation(s).',
      );
    }

    final firestore = _firestore;
    final bandsRef = _bandsRef;
    final locksRef = _bandLocksRef;

    if (firestore != null && bandsRef != null && locksRef != null) {
      final bandDocRef = bandsRef.doc(id);

      await firestore.runTransaction((transaction) async {
        final currentSnap = await transaction.get(bandDocRef);
        if (currentSnap.exists) {
          final data = currentSnap.data()!;
          final designationCount =
              (data['designation_count'] as num?)?.toInt() ?? 0;
          if (designationCount > 0) {
            throw StateError(
              'Cannot delete band "$id": it is currently assigned to $designationCount designation(s).',
            );
          }

          final orgId =
              data['organization_id']?.toString() ?? organizationId ?? '';
          final level = (data['level'] as num?)?.toInt() ?? 0;
          final code = (data['band_code']?.toString() ?? '')
              .trim()
              .toLowerCase();

          if (orgId.isNotEmpty) {
            if (level != 0) {
              transaction.delete(
                locksRef.doc(_generateLockKey(orgId, 'lvl', '$level')),
              );
              transaction.delete(
                locksRef.doc(_generateLegacyLockKey(orgId, 'lvl', '$level')),
              );
            }
            if (code.isNotEmpty) {
              transaction.delete(
                locksRef.doc(_generateLockKey(orgId, 'code', code)),
              );
              transaction.delete(
                locksRef.doc(_generateLegacyLockKey(orgId, 'code', code)),
              );
            }
          }
          transaction.delete(bandDocRef);
        }
      });
    }

    _memoryBands.removeWhere((b) => b.id == id);
  }

  /// Explicit migration and maintenance routine to reconcile `designation_count`
  /// on [OrganizationBand] documents against actual designation references.
  ///
  /// CRITICAL ARCHITECTURAL CONSTRAINTS:
  /// 1. DO NOT invoke automatically on application startup or within background providers.
  /// 2. This scan-and-update process is NOT safe under concurrent designation mutations.
  ///    It must only be executed as an explicit administrative maintenance operation
  ///    during a maintenance window when designation mutations are paused/coordinated.
  @override
  Future<Map<String, int>> reconcileBandReferenceCounts({
    String? organizationId,
  }) async {
    final allDesignations = await getDesignations(
      organizationId: organizationId,
    );
    final countMap = <String, int>{};
    for (final d in allDesignations) {
      if (d.bandId.isNotEmpty) {
        countMap[d.bandId] = (countMap[d.bandId] ?? 0) + 1;
      }
    }

    final bands = await getBands(organizationId: organizationId);
    final firestore = _firestore;
    final bandsRef = _bandsRef;

    for (final band in bands) {
      final actualCount = countMap[band.id] ?? 0;
      if (band.designationCount != actualCount) {
        final idx = _memoryBands.indexWhere((b) => b.id == band.id);
        if (idx != -1) {
          _memoryBands[idx] = _memoryBands[idx].copyWith(
            designationCount: actualCount,
          );
        }
        if (firestore != null && bandsRef != null) {
          try {
            await bandsRef.doc(band.id).update({
              'designation_count': actualCount,
            });
          } catch (e) {
            debugPrint('Failed to reconcile band count for ${band.id}: $e');
          }
        }
      }
    }
    return countMap;
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
        await ref
            .doc(preference.tableId)
            .set(preference.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving column preference: $e');
    }
  }

  // --- Document & Image Upload ---
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
      if (bytes == null &&
          platformFile?.path != null &&
          platformFile!.path!.isNotEmpty) {
        if (!kIsWeb) {
          final f = io.File(platformFile.path!);
          if (await f.exists()) {
            bytes = await f.readAsBytes();
          }
        }
      }

      if (bytes != null) {
        final ext = platformFile?.extension?.toLowerCase();
        final isImage = _isImageExtension(ext);
        final folderCategory = isImage ? 'images' : 'documents';

        final cleanFileName = fileName.replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );
        final cleanDocTitle = docTitle.replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );

        final storagePath =
            'organizations/$orgId/$cleanDocTitle/${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';
        final storageRef = _storage.ref().child(storagePath);

        try {
          final uploadTask = await storageRef.putData(
            bytes,
            SettableMetadata(contentType: _getContentType(ext)),
          );
          downloadUrl = await uploadTask.ref.getDownloadURL();
        } catch (e) {
          debugPrint(
            'Firebase Storage upload failed ($e), falling back to base64 Data URI',
          );
          final mime = _getContentType(ext);
          final base64Data = base64Encode(bytes);
          downloadUrl = 'data:$mime;base64,$base64Data';
        }
      }
    } catch (e) {
      debugPrint(
        'Error uploading organization document/image: $e',
      );
    }

    return OrgDocument(
      title: docTitle,
      fileName: fileName,
      fileUrl: downloadUrl,
      uploadedAt: DateTime.now().toIso8601String(),
    );
  }

  bool _isImageExtension(String? extension) {
    if (extension == null) return false;
    final ext = extension.toLowerCase();
    return ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'png' ||
        ext == 'webp' ||
        ext == 'gif' ||
        ext == 'svg' ||
        ext == 'bmp';
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
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }
}
