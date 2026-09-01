import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/business_unit.dart';
import '../domain/column_preference.dart';
import '../domain/department.dart';
import '../domain/designation.dart';
import '../domain/location.dart';
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

  CollectionReference<Map<String, dynamic>>? get _orgsRef => _firestore?.collection('organizations');
  CollectionReference<Map<String, dynamic>>? get _buRef => _firestore?.collection('business_units');
  CollectionReference<Map<String, dynamic>>? get _locationsRef => _firestore?.collection('locations');
  CollectionReference<Map<String, dynamic>>? get _deptsRef => _firestore?.collection('departments');
  CollectionReference<Map<String, dynamic>>? get _designationsRef => _firestore?.collection('designations');
  CollectionReference<Map<String, dynamic>>? get _colPrefRef => _firestore?.collection('column_preferences');

  static const String _orgName = 'IGreentec Engg. India Pvt. Ltd.';

  static final Organization _initialSeedOrg = const Organization(
    id: 1,
    name: _orgName,
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

  static final List<BusinessUnit> _initialSeedBUs = [
    const BusinessUnit(id: 1, organizationName: _orgName, unitName: 'Engineering & Manufacturing', description: 'Core engineering, design, and plant manufacturing operations.'),
    const BusinessUnit(id: 2, organizationName: _orgName, unitName: 'Projects & Services', description: 'On-site execution, HDD, trenchless, and utility infrastructure services.'),
    const BusinessUnit(id: 3, organizationName: _orgName, unitName: 'Corporate Operations', description: 'HR, Finance, IT, Administration, Sales and corporate functions.'),
  ];

  static final List<Location> _initialSeedLocations = [
    const Location(id: 1, organizationName: _orgName, businessUnitName: 'Engineering & Manufacturing', locationName: 'Chennai Manufacturing Plant', address: 'Plot No. 45, Ambattur Industrial Estate, Chennai - 600058'),
    const Location(id: 2, organizationName: _orgName, businessUnitName: 'Corporate Operations', locationName: 'Chennai Head Office', address: 'No. 25, Greams Road, Thousand Lights, Chennai - 600006'),
    const Location(id: 3, organizationName: _orgName, businessUnitName: 'Projects & Services', locationName: 'Chennai Manufacturing Plant', address: 'Plot No. 45, Ambattur Industrial Estate, Chennai - 600058'),
  ];

  static final List<Department> _initialSeedDepts = [
    const Department(id: 1, organizationName: _orgName, businessUnitName: 'Engineering & Manufacturing', departmentName: 'Engineering', departmentHead: 'Arun Kumar', reportingHierarchy: 'Manager', workLocation: 'Chennai Manufacturing Plant'),
    const Department(id: 2, organizationName: _orgName, businessUnitName: 'Engineering & Manufacturing', departmentName: 'Production', departmentHead: 'Suresh Kumar', reportingHierarchy: 'Manager', workLocation: 'Chennai Manufacturing Plant'),
    const Department(id: 3, organizationName: _orgName, businessUnitName: 'Engineering & Manufacturing', departmentName: 'Quality Assurance', departmentHead: 'Priya Raj', reportingHierarchy: 'Manager', workLocation: 'Chennai Manufacturing Plant'),
    const Department(id: 4, organizationName: _orgName, businessUnitName: 'Projects & Services', departmentName: 'Projects', departmentHead: 'Karthik M', reportingHierarchy: 'Manager', workLocation: 'Chennai Manufacturing Plant'),
    const Department(id: 5, organizationName: _orgName, businessUnitName: 'Engineering & Manufacturing', departmentName: 'Purchase & Procurement', departmentHead: 'Divya S', reportingHierarchy: 'Manager', workLocation: 'Chennai Manufacturing Plant'),
    const Department(id: 6, organizationName: _orgName, businessUnitName: 'Corporate Operations', departmentName: 'Sales & Marketing', departmentHead: 'Naveen Kumar', reportingHierarchy: 'Manager', workLocation: 'Chennai Head Office'),
    const Department(id: 7, organizationName: _orgName, businessUnitName: 'Corporate Operations', departmentName: 'Human Resources', departmentHead: 'Meena R', reportingHierarchy: 'Manager', workLocation: 'Chennai Head Office'),
    const Department(id: 8, organizationName: _orgName, businessUnitName: 'Corporate Operations', departmentName: 'Finance & Accounts', departmentHead: 'Ravi Shankar', reportingHierarchy: 'Head', workLocation: 'Chennai Head Office'),
    const Department(id: 9, organizationName: _orgName, businessUnitName: 'Corporate Operations', departmentName: 'Administration', departmentHead: 'Anitha P', reportingHierarchy: 'Manager', workLocation: 'Chennai Head Office'),
    const Department(id: 10, organizationName: _orgName, businessUnitName: 'Corporate Operations', departmentName: 'Information Technology', departmentHead: 'Vijay Kumar', reportingHierarchy: 'Manager', workLocation: 'Chennai Head Office'),
  ];

  static final List<Designation> _initialSeedDesignations = [
    // Engineering
    const Designation(id: 1, organizationName: _orgName, departmentName: 'Engineering', designationName: 'Technical Head', hierarchyLevel: HierarchyLevel.head),
    const Designation(id: 2, organizationName: _orgName, departmentName: 'Engineering', designationName: 'Engineering Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 3, organizationName: _orgName, departmentName: 'Engineering', designationName: 'Senior Design Engineer', hierarchyLevel: HierarchyLevel.senior),
    const Designation(id: 4, organizationName: _orgName, departmentName: 'Engineering', designationName: 'Design Engineer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 5, organizationName: _orgName, departmentName: 'Engineering', designationName: 'Mechanical Engineer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 6, organizationName: _orgName, departmentName: 'Engineering', designationName: 'Electrical Engineer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 7, organizationName: _orgName, departmentName: 'Engineering', designationName: 'Junior Engineer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 8, organizationName: _orgName, departmentName: 'Engineering', designationName: 'CAD Engineer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 9, organizationName: _orgName, departmentName: 'Engineering', designationName: 'CAD Designer', hierarchyLevel: HierarchyLevel.employee),

    // Production
    const Designation(id: 10, organizationName: _orgName, departmentName: 'Production', designationName: 'Factory Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 11, organizationName: _orgName, departmentName: 'Production', designationName: 'Production Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 12, organizationName: _orgName, departmentName: 'Production', designationName: 'Production Engineer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 13, organizationName: _orgName, departmentName: 'Production', designationName: 'Production Supervisor', hierarchyLevel: HierarchyLevel.supervisor),
    const Designation(id: 14, organizationName: _orgName, departmentName: 'Production', designationName: 'Factory Coordinator', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 15, organizationName: _orgName, departmentName: 'Production', designationName: 'Machine Operator', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 16, organizationName: _orgName, departmentName: 'Production', designationName: 'Operator', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 17, organizationName: _orgName, departmentName: 'Production', designationName: 'Production Trainee', hierarchyLevel: HierarchyLevel.trainee),

    // Quality Assurance
    const Designation(id: 18, organizationName: _orgName, departmentName: 'Quality Assurance', designationName: 'Quality Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 19, organizationName: _orgName, departmentName: 'Quality Assurance', designationName: 'Quality Engineer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 20, organizationName: _orgName, departmentName: 'Quality Assurance', designationName: 'Quality Inspector', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 21, organizationName: _orgName, departmentName: 'Quality Assurance', designationName: 'QA Executive', hierarchyLevel: HierarchyLevel.employee),

    // Projects
    const Designation(id: 22, organizationName: _orgName, departmentName: 'Projects', designationName: 'Technical Head', hierarchyLevel: HierarchyLevel.head),
    const Designation(id: 23, organizationName: _orgName, departmentName: 'Projects', designationName: 'Project Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 24, organizationName: _orgName, departmentName: 'Projects', designationName: 'Project Lead', hierarchyLevel: HierarchyLevel.lead),
    const Designation(id: 25, organizationName: _orgName, departmentName: 'Projects', designationName: 'Project Engineer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 26, organizationName: _orgName, departmentName: 'Projects', designationName: 'Sr. Project Coordinator', hierarchyLevel: HierarchyLevel.senior),
    const Designation(id: 27, organizationName: _orgName, departmentName: 'Projects', designationName: 'Project Coordinator', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 28, organizationName: _orgName, departmentName: 'Projects', designationName: 'Project Assistant', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 29, organizationName: _orgName, departmentName: 'Projects', designationName: 'Site Engineer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 30, organizationName: _orgName, departmentName: 'Projects', designationName: 'Site Coordinator', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 31, organizationName: _orgName, departmentName: 'Projects', designationName: 'Sr. Site Coordinator', hierarchyLevel: HierarchyLevel.senior),
    const Designation(id: 32, organizationName: _orgName, departmentName: 'Projects', designationName: 'Site Coordinator - Trainee', hierarchyLevel: HierarchyLevel.trainee),
    const Designation(id: 33, organizationName: _orgName, departmentName: 'Projects', designationName: 'Rig Operator', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 34, organizationName: _orgName, departmentName: 'Projects', designationName: 'Bore Path Specialist', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 35, organizationName: _orgName, departmentName: 'Projects', designationName: 'Tracker', hierarchyLevel: HierarchyLevel.employee),

    // Human Resources
    const Designation(id: 36, organizationName: _orgName, departmentName: 'Human Resources', designationName: 'HR Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 37, organizationName: _orgName, departmentName: 'Human Resources', designationName: 'HR Executive', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 38, organizationName: _orgName, departmentName: 'Human Resources', designationName: 'HR Coordinator', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 39, organizationName: _orgName, departmentName: 'Human Resources', designationName: 'HR Trainee', hierarchyLevel: HierarchyLevel.trainee),

    // Finance & Accounts
    const Designation(id: 40, organizationName: _orgName, departmentName: 'Finance & Accounts', designationName: 'Finance Head', hierarchyLevel: HierarchyLevel.head),
    const Designation(id: 41, organizationName: _orgName, departmentName: 'Finance & Accounts', designationName: 'Finance Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 42, organizationName: _orgName, departmentName: 'Finance & Accounts', designationName: 'Senior Accountant', hierarchyLevel: HierarchyLevel.senior),
    const Designation(id: 43, organizationName: _orgName, departmentName: 'Finance & Accounts', designationName: 'Accountant', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 44, organizationName: _orgName, departmentName: 'Finance & Accounts', designationName: 'Junior Accountant', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 45, organizationName: _orgName, departmentName: 'Finance & Accounts', designationName: 'Accounts Executive', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 46, organizationName: _orgName, departmentName: 'Finance & Accounts', designationName: 'Accounts Assistant', hierarchyLevel: HierarchyLevel.employee),

    // Information Technology
    const Designation(id: 47, organizationName: _orgName, departmentName: 'Information Technology', designationName: 'IT Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 48, organizationName: _orgName, departmentName: 'Information Technology', designationName: 'Software Developer', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 49, organizationName: _orgName, departmentName: 'Information Technology', designationName: 'System Administrator', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 50, organizationName: _orgName, departmentName: 'Information Technology', designationName: 'IT Support Executive', hierarchyLevel: HierarchyLevel.employee),

    // Purchase & Procurement
    const Designation(id: 51, organizationName: _orgName, departmentName: 'Purchase & Procurement', designationName: 'Purchase Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 52, organizationName: _orgName, departmentName: 'Purchase & Procurement', designationName: 'Purchase Executive', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 53, organizationName: _orgName, departmentName: 'Purchase & Procurement', designationName: 'Procurement Specialist', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 54, organizationName: _orgName, departmentName: 'Purchase & Procurement', designationName: 'Purchase Assistant', hierarchyLevel: HierarchyLevel.employee),

    // Sales & Marketing
    const Designation(id: 55, organizationName: _orgName, departmentName: 'Sales & Marketing', designationName: 'Sales Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 56, organizationName: _orgName, departmentName: 'Sales & Marketing', designationName: 'Sales Executive', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 57, organizationName: _orgName, departmentName: 'Sales & Marketing', designationName: 'Marketing Executive', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 58, organizationName: _orgName, departmentName: 'Sales & Marketing', designationName: 'Business Development Executive', hierarchyLevel: HierarchyLevel.employee),

    // Administration
    const Designation(id: 59, organizationName: _orgName, departmentName: 'Administration', designationName: 'Admin Manager', hierarchyLevel: HierarchyLevel.manager),
    const Designation(id: 60, organizationName: _orgName, departmentName: 'Administration', designationName: 'Admin Executive', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 61, organizationName: _orgName, departmentName: 'Administration', designationName: 'Office Assistant', hierarchyLevel: HierarchyLevel.employee),
    const Designation(id: 62, organizationName: _orgName, departmentName: 'Administration', designationName: 'Receptionist', hierarchyLevel: HierarchyLevel.employee),
  ];

  final List<Organization> _memoryOrgs = [_initialSeedOrg];
  final List<BusinessUnit> _memoryBUs = List.from(_initialSeedBUs);
  final List<Location> _memoryLocations = List.from(_initialSeedLocations);
  final List<Department> _memoryDepts = List.from(_initialSeedDepts);
  final List<Designation> _memoryDesignations = List.from(_initialSeedDesignations);

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    _seeded = true;

    try {
      final orgRef = _orgsRef;
      if (orgRef != null) {
        final snap = await orgRef.limit(1).get();
        if (snap.docs.isEmpty) {
          await orgRef.doc('org_1').set(_initialSeedOrg.toMap());
        }
      }

      final buRef = _buRef;
      if (buRef != null) {
        final snap = await buRef.limit(1).get();
        if (snap.docs.isEmpty) {
          for (final item in _initialSeedBUs) {
            await buRef.doc('bu_${item.id}').set(item.toMap());
          }
        }
      }

      final locRef = _locationsRef;
      if (locRef != null) {
        final snap = await locRef.limit(1).get();
        if (snap.docs.isEmpty) {
          for (final item in _initialSeedLocations) {
            await locRef.doc('loc_${item.id}').set(item.toMap());
          }
        }
      }

      final dRef = _deptsRef;
      if (dRef != null) {
        final snap = await dRef.limit(1).get();
        if (snap.docs.isEmpty) {
          for (final dept in _initialSeedDepts) {
            await dRef.doc('dept_${dept.id}').set(dept.toMap());
          }
        }
      }

      final desigRef = _designationsRef;
      if (desigRef != null) {
        final snap = await desigRef.limit(1).get();
        if (snap.docs.isEmpty) {
          for (final desig in _initialSeedDesignations) {
            await desigRef.doc('desig_${desig.id}').set(desig.toMap());
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore Organization seeding check warning: $e');
    }
  }

  // --- Organization ---
  @override
  Future<List<Organization>> getOrganizations() async {
    await _ensureSeeded();
    try {
      final ref = _orgsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        if (snapshot.docs.isNotEmpty) {
          final orgs = snapshot.docs.map((doc) => Organization.fromMap(doc.data())).toList();
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
    await _ensureSeeded();
    try {
      final ref = _buRef;
      if (ref != null) {
        final snapshot = await ref.get();
        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs.map((doc) => BusinessUnit.fromMap(doc.data())).toList();
          _memoryBUs.clear();
          _memoryBUs.addAll(list);
        }
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
    await _ensureSeeded();
    try {
      final ref = _locationsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs.map((doc) => Location.fromMap(doc.data())).toList();
          _memoryLocations.clear();
          _memoryLocations.addAll(list);
        }
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
    await _ensureSeeded();
    try {
      final ref = _deptsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs.map((doc) => Department.fromMap(doc.data())).toList();
          list.sort((a, b) => a.id.compareTo(b.id));
          _memoryDepts.clear();
          _memoryDepts.addAll(list);
        }
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
    await _ensureSeeded();
    try {
      final ref = _designationsRef;
      if (ref != null) {
        final snapshot = await ref.get();
        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs.map((doc) {
            final desig = Designation.fromMap(doc.data());
            if (desig.organizationName.isEmpty) {
              final dept = _memoryDepts.where((dept) => dept.departmentName == desig.departmentName).firstOrNull;
              final org = (dept != null && dept.organizationName.isNotEmpty) ? dept.organizationName : _orgName;
              return desig.copyWith(organizationName: org);
            }
            return desig;
          }).toList();
          list.sort((a, b) => a.id.compareTo(b.id));
          _memoryDesignations.clear();
          _memoryDesignations.addAll(list);
        }
      }
    } catch (e) {
      debugPrint('Error getting designations: $e');
    }
    return _memoryDesignations.map((d) {
      if (d.organizationName.isEmpty) {
        final dept = _memoryDepts.where((dept) => dept.departmentName == d.departmentName).firstOrNull;
        final org = (dept != null && dept.organizationName.isNotEmpty) ? dept.organizationName : _orgName;
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
}
