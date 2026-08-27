import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/column_preference.dart';
import '../domain/department.dart';
import '../domain/organization.dart';
import '../domain/organization_repository.dart';

/// Robust Firestore implementation of OrganizationRepository with auto-seeding
/// and safe fallback for offline / uninitialized environments.
class FirebaseOrganizationRepository implements OrganizationRepository {
  final FirebaseFirestore? _customFirestore;
  bool _seeded = false;

  FirebaseOrganizationRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore? get _firestore {
    try {
      return _customFirestore ?? FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _orgsRef {
    try {
      return _firestore?.collection('organizations');
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _deptsRef {
    try {
      return _firestore?.collection('departments');
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _colPrefRef {
    try {
      return _firestore?.collection('column_preferences');
    } catch (_) {
      return null;
    }
  }

  static final Organization _initialSeedOrg = const Organization(
    id: 1,
    name: 'IGreentec Engg. India Pvt. Ltd.',
    businessType: 'Private Limited Company',
    industryType: 'Engineering & Manufacturing',
    businessUnits: 'Engineering & Manufacturing, Projects & Services, Corporate Operations',
    locations: 'Chennai Head Office, Chennai Manufacturing Plant',
    address: 'No. 25, Industrial Estate, Ambattur, Chennai, Tamil Nadu - 600058',
    phoneNumber: '+91 44 4567 8900',
    emailAddress: 'info@igreentec.example',
    website: 'www.igreentec.example',
    taxId: '33ABCDE1234F1Z5',
  );

  static final List<Department> _initialSeedDepts = [
    const Department(
      id: 1,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Engineering',
      departmentHead: 'Arun Kumar',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Manufacturing Plant',
    ),
    const Department(
      id: 2,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Production',
      departmentHead: 'Suresh Kumar',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Manufacturing Plant',
    ),
    const Department(
      id: 3,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Quality Assurance',
      departmentHead: 'Priya Raj',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Manufacturing Plant',
    ),
    const Department(
      id: 4,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Projects',
      departmentHead: 'Karthik M',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Manufacturing Plant',
    ),
    const Department(
      id: 5,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Purchase & Procurement',
      departmentHead: 'Divya S',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Manufacturing Plant',
    ),
    const Department(
      id: 6,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Sales & Marketing',
      departmentHead: 'Naveen Kumar',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Head Office',
    ),
    const Department(
      id: 7,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Human Resources',
      departmentHead: 'Meena R',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Head Office',
    ),
    const Department(
      id: 8,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Finance & Accounts',
      departmentHead: 'Ravi Shankar',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Head Office',
    ),
    const Department(
      id: 9,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Administration',
      departmentHead: 'Anitha P',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Head Office',
    ),
    const Department(
      id: 10,
      organizationName: 'IGreentec Engg. India Pvt. Ltd.',
      departmentName: 'Information Technology',
      departmentHead: 'Vijay Kumar',
      reportingHierarchy: 'Manager',
      workLocation: 'Chennai Head Office',
    ),
  ];

  final List<Organization> _memoryOrgs = [_initialSeedOrg];
  final List<Department> _memoryDepts = List.from(_initialSeedDepts);

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    _seeded = true;

    try {
      final ref = _orgsRef;
      if (ref != null) {
        final orgSnapshot = await ref.limit(1).get();
        if (orgSnapshot.docs.isEmpty) {
          await ref.doc('org_1').set(_initialSeedOrg.toMap());
        }
      }

      final dRef = _deptsRef;
      if (dRef != null) {
        final deptSnapshot = await dRef.limit(1).get();
        if (deptSnapshot.docs.isEmpty) {
          for (final dept in _initialSeedDepts) {
            await dRef.doc('dept_${dept.id}').set(dept.toMap());
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore Organization seeding check warning: $e');
    }
  }

  @override
  Future<List<Organization>> getOrganizations() async {
    await _ensureSeeded();
    try {
      final ref = _orgsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        if (snapshot.docs.isNotEmpty) {
          final orgs = snapshot.docs
              .map((doc) => Organization.fromMap(doc.data()))
              .toList();
          _memoryOrgs.clear();
          _memoryOrgs.addAll(orgs);
          return orgs;
        }
      }
    } catch (e) {
      debugPrint('Error getting organizations from Firestore: $e');
    }
    return List.from(_memoryOrgs);
  }

  @override
  Future<void> addOrganization(Organization organization) async {
    final nextId = organization.id != 0
        ? organization.id
        : DateTime.now().millisecondsSinceEpoch;
    final orgWithId = organization.copyWith(id: nextId);

    _memoryOrgs.add(orgWithId);

    try {
      final ref = _orgsRef;
      if (ref != null) {
        await ref.doc('org_$nextId').set(orgWithId.toMap());
      }
    } catch (e) {
      debugPrint('Error adding organization to Firestore: $e');
    }
  }

  @override
  Future<void> updateOrganization(Organization organization) async {
    final idx = _memoryOrgs.indexWhere((o) => o.id == organization.id);
    if (idx != -1) {
      _memoryOrgs[idx] = organization;
    } else {
      _memoryOrgs.add(organization);
    }

    try {
      final ref = _orgsRef;
      if (ref != null) {
        await ref.doc('org_${organization.id}').set(
              organization.toMap(),
              SetOptions(merge: true),
            );
      }
    } catch (e) {
      debugPrint('Error updating organization in Firestore: $e');
    }
  }

  @override
  Future<void> deleteOrganization(int id) async {
    _memoryOrgs.removeWhere((o) => o.id == id);

    try {
      final ref = _orgsRef;
      if (ref != null) {
        await ref.doc('org_$id').delete();
      }
    } catch (e) {
      debugPrint('Error deleting organization in Firestore: $e');
    }
  }

  @override
  Future<List<Department>> getDepartments() async {
    await _ensureSeeded();
    try {
      final ref = _deptsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs
              .map((doc) => Department.fromMap(doc.data()))
              .toList();
          list.sort((a, b) => a.id.compareTo(b.id));
          _memoryDepts.clear();
          _memoryDepts.addAll(list);
          return list;
        }
      }
    } catch (e) {
      debugPrint('Error getting departments from Firestore: $e');
    }
    return List.from(_memoryDepts);
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
      if (ref != null) {
        await ref.doc('dept_$nextId').set(deptWithId.toMap());
      }
    } catch (e) {
      debugPrint('Error adding department to Firestore: $e');
    }
  }

  @override
  Future<void> updateDepartment(Department department) async {
    final idx = _memoryDepts.indexWhere((d) => d.id == department.id);
    if (idx != -1) {
      _memoryDepts[idx] = department;
    } else {
      _memoryDepts.add(department);
    }

    try {
      final ref = _deptsRef;
      if (ref != null) {
        await ref.doc('dept_${department.id}').set(
              department.toMap(),
              SetOptions(merge: true),
            );
      }
    } catch (e) {
      debugPrint('Error updating department in Firestore: $e');
    }
  }

  @override
  Future<void> deleteDepartment(int id) async {
    _memoryDepts.removeWhere((d) => d.id == id);

    try {
      final ref = _deptsRef;
      if (ref != null) {
        await ref.doc('dept_$id').delete();
      }
    } catch (e) {
      debugPrint('Error deleting department in Firestore: $e');
    }
  }

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
}
