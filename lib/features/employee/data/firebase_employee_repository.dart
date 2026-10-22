import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../organization/domain/column_preference.dart';
import '../domain/candidate_response.dart';
import '../domain/correction_request.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';
import '../domain/registration_link.dart';

class FirebaseEmployeeRepository implements EmployeeRepository {
  final FirebaseFirestore? _customFirestore;
  final FirebaseStorage? _customStorage;
  final bool _isInMemory;
  final List<Employee> _memoryEmployees = [];

  FirebaseEmployeeRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    bool isInMemory = false,
  }) : _customFirestore = firestore,
       _customStorage = storage,
       _isInMemory = isInMemory;

  static bool _hasFirebaseApp() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool get isInMemory =>
      _isInMemory || (_customFirestore == null && !_hasFirebaseApp());

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  CollectionReference<Map<String, dynamic>> get _registrationLinksRef =>
      _firestore.collection('registration_links');

  CollectionReference<Map<String, dynamic>> get _candidateResponsesRef =>
      _firestore.collection('candidate_responses');

  CollectionReference<Map<String, dynamic>> get _correctionRequestsRef =>
      _firestore.collection('correction_requests');

  CollectionReference<Map<String, dynamic>> get _columnPreferencesRef =>
      _firestore.collection('column_preferences');

  /// Safely fetches a DocumentSnapshot with recovery logic for browser IndexedDB
  /// transaction aborts (e.g., Safari iOS app suspension during photo selection,
  /// multi-tab lock conflicts, or transient storage connection drops).
  Future<DocumentSnapshot<T>> _safeGetDoc<T>(
    DocumentReference<T> ref, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (attempt == 1) {
          return await ref.get();
        }
        return await ref.get(const GetOptions(source: Source.server));
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isRecoverable =
            errStr.contains('indexeddb') ||
            errStr.contains('aborterror') ||
            errStr.contains('allocate target') ||
            errStr.contains('unavailable') ||
            errStr.contains('failed-precondition');

        if (attempt == maxRetries || !isRecoverable) {
          try {
            return await ref.get(const GetOptions(source: Source.server));
          } catch (_) {
            rethrow;
          }
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
    return await ref.get(const GetOptions(source: Source.server));
  }

  /// Safely fetches a QuerySnapshot with recovery logic for browser IndexedDB
  /// transaction aborts (e.g., Safari iOS app suspension during photo selection,
  /// multi-tab lock conflicts, or transient storage connection drops).
  Future<QuerySnapshot<T>> _safeGetQuery<T>(
    Query<T> query, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (attempt == 1) {
          return await query.get();
        }
        return await query.get(const GetOptions(source: Source.server));
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isRecoverable =
            errStr.contains('indexeddb') ||
            errStr.contains('aborterror') ||
            errStr.contains('allocate target') ||
            errStr.contains('unavailable') ||
            errStr.contains('failed-precondition');

        if (attempt == maxRetries || !isRecoverable) {
          try {
            return await query.get(const GetOptions(source: Source.server));
          } catch (_) {
            rethrow;
          }
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
    return await query.get(const GetOptions(source: Source.server));
  }

  /// Safely commits a WriteBatch with retry logic for transient browser/network drops.
  Future<void> _safeCommitBatch(
    WriteBatch batch, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await batch.commit();
        return;
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isRecoverable =
            errStr.contains('indexeddb') ||
            errStr.contains('aborterror') ||
            errStr.contains('unavailable') ||
            errStr.contains('deadline-exceeded');
        if (attempt == maxRetries || !isRecoverable) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
  }

  String _folderForEmployee(String employeeId, String role) {
    final normalizedRole = role.trim().isEmpty
        ? 'employees'
        : role.trim().toLowerCase();
    final normalizedId = employeeId.trim().isEmpty
        ? 'unassigned'
        : employeeId.trim();
    return 'employee_management/profiles/$normalizedRole/$normalizedId';
  }

  // Helper: Map Employee object to Firestore document map
  Map<String, dynamic> _employeeToFirestore(Employee emp) {
    final map = emp.toMap();

    // Convert list objects into native Firestore Array of Maps instead of raw JSON strings
    map['education_items'] = emp.educationItems.map((e) => e.toMap()).toList();
    map['experience_items'] = emp.experienceItems
        .map((e) => e.toMap())
        .toList();
    map['document_items'] = emp.documentItems.map((e) => e.toMap()).toList();

    map['updated_at'] = FieldValue.serverTimestamp();
    return map;
  }

  /// Returns the integer employee ID, always preferring the stored 'id' field from Firestore.
  /// Falls back to parsing the numeric suffix from the Firestore document key.
  /// No employee-specific names or codes are hardcoded here.
  static int resolveEmployeeIntegerId(String docKey, [int? currentId]) {
    // Always prefer explicitly stored id
    if (currentId != null && currentId > 0) return currentId;
    // Derive from the numeric portion of the doc key (e.g. EMP-002 → 2)
    final digits = docKey.trim().replaceAll(RegExp(r'\D'), '');
    final num = int.tryParse(digits) ?? 0;
    if (num > 0) return num;
    // Final fallback: non-zero hash of the doc key string
    final hash = docKey.trim().hashCode.abs();
    return hash > 0 ? hash : 1;
  }

  // Helper: Map Firestore document data to Employee object
  Employee _employeeFromFirestore(Map<String, dynamic> map, String docId) {
    final mutableMap = Map<String, dynamic>.from(map);

    final currentId = mutableMap['id'] as int?;
    final resolvedId = resolveEmployeeIntegerId(docId, currentId);
    mutableMap['id'] = resolvedId;

    // Self-healing: persist id back to Firestore if it was missing or zero
    if (docId.isNotEmpty && (currentId == null || currentId == 0)) {
      _employeesRef.doc(docId).set({
        'id': resolvedId,
      }, SetOptions(merge: true)).ignore();
    }

    // Convert Firestore native array lists back to JSON strings for domain model compatibility
    if (mutableMap['education_items'] is List) {
      mutableMap['education_list_json'] = jsonEncode(
        mutableMap['education_items'],
      );
    }
    if (mutableMap['experience_items'] is List) {
      mutableMap['experience_list_json'] = jsonEncode(
        mutableMap['experience_items'],
      );
    }
    if (mutableMap['document_items'] is List) {
      mutableMap['document_list_json'] = jsonEncode(
        mutableMap['document_items'],
      );
    }

    return Employee.fromMap(mutableMap);
  }

  @override
  Stream<Employee?> watchEmployee(String emailOrId) {
    final target = emailOrId.trim();
    if (target.isEmpty) return Stream.value(null);

    final lower = target.toLowerCase();
    if (lower == 'admin' || lower == 'super admin' || lower == 'superadmin') {
      return _employeesRef.doc('EMP-001').snapshots().map((doc) {
        if (doc.exists && doc.data() != null) {
          return _employeeFromFirestore(doc.data()!, doc.id);
        }
        return _superAdminMotherAccount;
      });
    }

    if (target.contains('@')) {
      return _employeesRef
          .where('email_address', isEqualTo: target)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final doc = snapshot.docs.first;
              return _employeeFromFirestore(doc.data(), doc.id);
            }
            return null;
          });
    }

    final docKey = target.toUpperCase();
    return _employeesRef.doc(docKey).snapshots().asyncMap((doc) async {
      if (doc.exists && doc.data() != null) {
        return _employeeFromFirestore(doc.data()!, doc.id);
      }
      final byEmpId = await _employeesRef.where('employee_id', isEqualTo: docKey).limit(1).get();
      if (byEmpId.docs.isNotEmpty) {
        return _employeeFromFirestore(byEmpId.docs.first.data(), byEmpId.docs.first.id);
      }
      final all = await getAllEmployees();
      return all.where((e) {
        final t = target.toLowerCase();
        return e.employeeId.toLowerCase() == t ||
            e.emailAddress.toLowerCase() == t ||
            e.firstName.toLowerCase() == t ||
            e.fullName.toLowerCase() == t;
      }).firstOrNull;
    });
  }

  @override
  Future<List<Employee>> getEmployees() async {
    final all = await getAllEmployees();
    final result = <Employee>[];

    for (final emp in all) {
      final s = emp.status.trim().toLowerCase();
      if (s != 'archived' && s != 'deleted') {
        var updated = emp;
        if (s.isEmpty || s == 'draft' || s == 'submitted') {
          updated = emp.copyWith(status: 'Active');
        }
        result.add(updated);
      }
    }

    return result;
  }

  /// Restores status to Active for full EMP- employees in Firestore background task
  Future<void> _fixEmployeeStatuses(List<Employee> employees) async {
    try {
      for (final emp in employees) {
        final docId = emp.employeeId.isNotEmpty
            ? emp.employeeId
            : (emp.id != 0 ? emp.id.toString() : '');
        if (docId.isNotEmpty) {
          await _employeesRef.doc(docId).set({
            'status': 'Active',
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  /// Assigns proper EMP- IDs to employees in the background without blocking the UI.
  Future<void> _fixEmployeeIds(List<Employee> employees) async {
    try {
      for (final emp in employees) {
        final newEmpId = await _generateNextEmployeeId();
        final updated = emp.copyWith(employeeId: newEmpId, status: 'Active');
        await updateEmployee(updated);
      }
    } catch (_) {
      // Non-critical — ignore errors, will retry on next load
    }
  }

  Future<void> _validateReportingManager(
    Employee employee, {
    required bool isUpdate,
  }) async {
    final managerId = employee.reportingManagerId.trim();
    if (managerId.isEmpty) {
      // Unassigned reporting manager is allowed (legacy record or top-level leadership)
      return;
    }

    final empId = employee.employeeId.trim();

    // 1. Prevent self-reporting
    if (empId.isNotEmpty && managerId.toLowerCase() == empId.toLowerCase()) {
      throw ArgumentError('An employee cannot report to themselves.');
    }
    if (employee.id != 0 && managerId == employee.id.toString()) {
      throw ArgumentError('An employee cannot report to themselves.');
    }

    // 2. Fetch manager from repository
    final all = await getAllEmployees();
    final manager = all.where((e) {
      return (e.employeeId.isNotEmpty &&
              e.employeeId.trim().toLowerCase() == managerId.toLowerCase()) ||
          (e.id != 0 && e.id.toString() == managerId) ||
          (e.emailAddress.isNotEmpty &&
              e.emailAddress.trim().toLowerCase() == managerId.toLowerCase());
    }).firstOrNull;

    if (manager == null) {
      // If updating an employee whose managerId was already set and unchanged, allow gracefully
      if (isUpdate) {
        final existingEmp = all
            .where(
              (e) =>
                  (empId.isNotEmpty &&
                      e.employeeId.trim().toLowerCase() ==
                          empId.toLowerCase()) ||
                  (employee.id != 0 && e.id == employee.id),
            )
            .firstOrNull;
        if (existingEmp != null &&
            existingEmp.reportingManagerId.trim().toLowerCase() ==
                managerId.toLowerCase()) {
          return;
        }
      }
      throw ArgumentError(
        'Cannot assign reporting manager "$managerId": manager does not exist.',
      );
    }

    // 3. Prevent cross-organization reporting
    final empOrg = employee.organizationName.trim().toLowerCase();
    final mgrOrg = manager.organizationName.trim().toLowerCase();
    if (empOrg.isNotEmpty && mgrOrg.isNotEmpty && empOrg != mgrOrg) {
      throw ArgumentError(
        'Cannot assign reporting manager "${manager.fullName}": manager belongs to "${manager.organizationName}", but employee belongs to "${employee.organizationName}".',
      );
    }

    // 4. Validate active status
    final mgrStatus = manager.status.trim().toLowerCase();
    final isInactive =
        mgrStatus == 'inactive' ||
        mgrStatus == 'suspended' ||
        mgrStatus == 'archived' ||
        mgrStatus == 'deleted';

    if (isInactive) {
      // If updating an existing employee without changing managerId, don't lock out record
      if (isUpdate) {
        final existingEmp = all
            .where(
              (e) =>
                  (empId.isNotEmpty &&
                      e.employeeId.trim().toLowerCase() ==
                          empId.toLowerCase()) ||
                  (employee.id != 0 && e.id == employee.id),
            )
            .firstOrNull;
        if (existingEmp != null &&
            existingEmp.reportingManagerId.trim().toLowerCase() ==
                managerId.toLowerCase()) {
          return;
        }
      }
      throw ArgumentError(
        'Cannot assign inactive employee "${manager.fullName}" (${manager.employeeId}) as reporting manager.',
      );
    }
  }

  @override
  Future<Employee?> getEmployeeById(int id) async {
    final inMem = _memoryEmployees.where((e) => e.id == id).firstOrNull;
    if (inMem != null) return inMem;
    if (isInMemory) return null;

    final snapshot = await _employeesRef
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return _employeeFromFirestore(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    }
    final doc = await _employeesRef.doc(id.toString()).get();
    if (doc.exists && doc.data() != null) {
      return _employeeFromFirestore(doc.data()!, doc.id);
    }
    return null;
  }

  @override
  Future<Employee> addEmployee(Employee employee) async {
    await _validateReportingManager(employee, isUpdate: false);
    var emp = employee;
    final empIdUpper = emp.employeeId.trim().toUpperCase();
    if (empIdUpper.isEmpty ||
        empIdUpper.startsWith('CAN-') ||
        empIdUpper.startsWith('PENDING_') ||
        empIdUpper.startsWith('REG-') ||
        !empIdUpper.startsWith('EMP-')) {
      final newEmpId = await _generateNextEmployeeId();
      emp = emp.copyWith(employeeId: newEmpId);
    }
    if (emp.status.isEmpty) {
      emp = emp.copyWith(status: 'Active');
    }

    final docId = emp.employeeId;
    if (emp.profileImageUrl.isNotEmpty && !isInMemory) {
      final storageUrl = await _uploadEmployeePhotoToStorage(
        docId,
        emp.profileImageUrl,
      );
      emp = emp.copyWith(profileImageUrl: storageUrl);
    }

    if (isInMemory) {
      final assignedId = resolveEmployeeIntegerId(
        docId,
        emp.id != 0 ? emp.id : null,
      );
      final saved = emp.copyWith(id: assignedId);
      _memoryEmployees.removeWhere(
        (e) => e.employeeId == saved.employeeId || e.id == assignedId,
      );
      _memoryEmployees.add(saved);
      return saved;
    }

    final data = _employeeToFirestore(emp);
    data['created_at'] = FieldValue.serverTimestamp();

    await _employeesRef.doc(docId).set(data, SetOptions(merge: true));

    final assignedId = resolveEmployeeIntegerId(
      docId,
      emp.id != 0 ? emp.id : null,
    );
    await _employeesRef.doc(docId).set({
      'id': assignedId,
    }, SetOptions(merge: true));

    final saved = emp.copyWith(id: assignedId);
    _memoryEmployees.removeWhere(
      (e) => e.employeeId == saved.employeeId || e.id == assignedId,
    );
    _memoryEmployees.add(saved);
    return saved;
  }

  @override
  Future<String> getNextEmployeeId() async {
    return _generateNextEmployeeId();
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    await _validateReportingManager(employee, isUpdate: true);
    var emp = employee;
    String docId = emp.employeeId.isNotEmpty
        ? emp.employeeId
        : (emp.id != 0 ? emp.id.toString() : '');

    if (isInMemory) {
      if (docId.isEmpty) {
        final newEmpId = await _generateNextEmployeeId();
        docId = newEmpId;
        emp = emp.copyWith(employeeId: newEmpId);
      }
      final idx = _memoryEmployees.indexWhere(
        (e) =>
            (e.employeeId.isNotEmpty && e.employeeId == emp.employeeId) ||
            (emp.id != 0 && e.id == emp.id),
      );
      if (idx != -1) {
        _memoryEmployees[idx] = emp;
      } else {
        _memoryEmployees.add(emp);
      }
      return;
    }

    if (docId.isEmpty) {
      final snapshot = await _employeesRef
          .where('id', isEqualTo: emp.id)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        docId = snapshot.docs.first.id;
      } else {
        final newEmpId = await _generateNextEmployeeId();
        docId = newEmpId;
        emp = emp.copyWith(employeeId: newEmpId);
      }
    }

    if (emp.profileImageUrl.isNotEmpty) {
      final storageUrl = await _uploadEmployeePhotoToStorage(
        docId,
        emp.profileImageUrl,
      );
      emp = emp.copyWith(profileImageUrl: storageUrl);
    }

    final data = _employeeToFirestore(emp);
    await _employeesRef.doc(docId).set(data, SetOptions(merge: true));
    final idx = _memoryEmployees.indexWhere(
      (e) =>
          (e.employeeId.isNotEmpty && e.employeeId == emp.employeeId) ||
          (emp.id != 0 && e.id == emp.id),
    );
    if (idx != -1) {
      _memoryEmployees[idx] = emp;
    } else {
      _memoryEmployees.add(emp);
    }
  }

  @override
  Future<void> updateBulkLeavePolicy({
    required List<int> employeeIds,
    required String leaveType,
    required double allowedLeaves,
    required String leaveAllocationFrequency,
    required bool requiresLeaveApproval,
    String? effectiveDate,
  }) async {
    final batch = _firestore.batch();
    final snapshot = await _employeesRef.get();
    final idSet = employeeIds.toSet();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final assignedId = resolveEmployeeIntegerId(doc.id, data['id'] as int?);
      final empId = assignedId;

      if (idSet.contains(empId)) {
        final updateData = <String, dynamic>{
          'leave_type': leaveType,
          'allowed_leaves': allowedLeaves,
          'leave_allocation_frequency': leaveAllocationFrequency,
          'requires_leave_approval': requiresLeaveApproval,
          'effective_date': effectiveDate ?? '',
          'updated_at': FieldValue.serverTimestamp(),
        };
        batch.set(doc.reference, updateData, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  @override
  Future<void> deleteEmployee(int id) async {
    _memoryEmployees.removeWhere((e) => e.id == id);
    if (isInMemory) return;

    // 1. Try querying by the stored integer 'id' field
    final snapshot = await _employeesRef
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      await _employeesRef.doc(snapshot.docs.first.id).delete();
      return;
    }

    // 2. Try doc ID = id.toString() (e.g. "1", "2")
    final doc = await _employeesRef.doc(id.toString()).get();
    if (doc.exists) {
      await _employeesRef.doc(id.toString()).delete();
      return;
    }

    // 3. Try querying by 'employee_id' field that contains the numeric part
    //    (handles cases where id == hashCode of the employeeId doc key)
    final allDocs = await _employeesRef.get();
    for (final d in allDocs.docs) {
      final data = d.data();
      // Reconstruct the id that _employeeFromFirestore would have assigned
      final docId = d.id;
      final assignedId = resolveEmployeeIntegerId(docId, data['id'] as int?);
      if (assignedId == id || data['id'] == id) {
        await _employeesRef.doc(d.id).delete();
        return;
      }
    }
  }

  @override
  Future<EmployeePhotoAsset> uploadEmployeeProfileImage({
    required String employeeId,
    required String role,
    required Uint8List imageBytes,
    required String fileName,
    required String mimeType,
  }) async {
    final folder = _folderForEmployee(employeeId, role);
    final storagePath = 'Employee Photo/$folder/$fileName';
    try {
      final ref = _storage.ref().child(storagePath);
      final uploadTask = await ref.putData(
        imageBytes,
        SettableMetadata(contentType: mimeType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return EmployeePhotoAsset(
        url: downloadUrl,
        publicId: storagePath,
        folder: folder,
      );
    } catch (_) {}

    // Fallback to local base64 Data URI if network or backend upload service is unreachable
    final base64Str = base64Encode(imageBytes);
    final dataUri = 'data:$mimeType;base64,$base64Str';
    return EmployeePhotoAsset(
      url: dataUri,
      publicId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      folder: folder,
    );
  }

  @override
  Future<RegistrationLink> createRegistrationLink({
    required String generatedBy,
    String? organizationName,
    String? department,
    String? designation,
    bool isExperienceMandatory = false,
    String? referredBy,
    String? referredByMobile,
    String? referredByEmployeeId,
  }) async {
    final docRef = _registrationLinksRef.doc();
    final linkId = 'lnk_${docRef.id.substring(0, 8)}';
    final now = DateTime.now();
    final expiry = now.add(const Duration(days: 7));

    final link = RegistrationLink(
      id: now.millisecondsSinceEpoch ~/ 1000,
      linkId: linkId,
      generatedBy: generatedBy,
      generatedDate: now.toIso8601String(),
      expiryDate: expiry.toIso8601String(),
      linkStatus: 'Pending',
      organizationName: organizationName ?? '',
      department: department ?? '',
      designation: designation ?? '',
      isExperienceMandatory: isExperienceMandatory,
      referredBy: referredBy ?? '',
      referredByMobile: referredByMobile ?? '',
      referredByEmployeeId: referredByEmployeeId ?? '',
    );

    final data = link.toMap();
    data['created_at'] = FieldValue.serverTimestamp();
    data['updated_at'] = FieldValue.serverTimestamp();

    await _registrationLinksRef.doc(linkId).set(data);
    return link;
  }

  static const Employee superAdminMotherAccount = _superAdminMotherAccount;

  static const Employee _superAdminMotherAccount = Employee(
    id: 1,
    employeeId: 'EMP-001',
    firstName: 'Super',
    lastName: 'Admin',
    emailAddress: 'admin@company.com',
    phoneNumber: '+91 9876543210',
    gender: 'Male',
    dob: '1990-01-01',
    organizationName: 'Primary Organization',
    department: 'Management',
    designation: 'Super Administrator',
    employmentType: 'Full-time',
    joiningDate: '2024-01-01',
    userType: 'Super Admin',
    status: 'Active',
    temporaryPassword: 'admin123',
    accessPermissions: Employee.allSidebarPermissions,
  );

  /// Dummy employee populated with comprehensive dummy data for Employee Management,
  /// credentials, full access permissions, and attendance testing.
  static final Employee dummyEmployee = Employee(
    id: 1001,
    employeeId: 'EMP-1001',
    firstName: 'Rahul',
    lastName: 'Sharma',
    emailAddress: 'rahul.sharma@igreen.com',
    phoneNumber: '+91 9876543210',
    personalMobile: '+91 9876543210',
    gender: 'Male',
    dob: '15-06-1995',
    bloodGroup: 'O+',
    organizationName: 'I-Green Technology',
    businessUnit: 'Engineering',
    department: 'Execution',
    designation: 'Site Engineer',
    employmentType: 'Full Time',
    joiningDate: '01-01-2024',
    userType: 'EMPLOYEE',
    status: 'Active',
    temporaryPassword: 'Password@123',
    accessPermissions: Employee.allSidebarPermissions,
    // Attendance & Schedule
    workScheduleType: 'Fixed Schedule',
    inTime: '09:00 AM',
    outTime: '06:00 PM',
    requiredWorkingHours: 9.0,
    weeklyOffDay: 'Sunday',
    leaveType: 'As Needed',
    leaveAllocationFrequency: 'Monthly',
    allowedLeaves: 3.0,
    monthlyLeaveAllowance: 3.0,
    monthlyPermissionLimitHours: 3.0,
    dailyPermissionLimitHours: 1.0,
    effectiveDate: '01-01-2024',
    requiresLeaveApproval: true,
    siteLatitude: 13.0827,
    siteLongitude: 80.2707,
    siteAllowedRadiusMeters: 500,
    siteRequireGpsVerification: false,
    isStaticEmployee: true,
    isDynamicEmployee: false,
    reportingManager: 'Super Admin',
    reportingManagerId: 'EMP-001',
    // Address
    street: '123, Green Tech Park, Mount Road',
    city: 'Chennai',
    state: 'Tamil Nadu',
    postalCode: '600002',
    country: 'India',
    permanentAddress: '123, Green Tech Park, Mount Road, Chennai',
    permanentState: 'Tamil Nadu',
    permanentCity: 'Chennai',
    permanentDistrict: 'Chennai',
    permanentPincode: '600002',
    presentAddress: '123, Green Tech Park, Mount Road, Chennai',
    presentState: 'Tamil Nadu',
    presentCity: 'Chennai',
    presentDistrict: 'Chennai',
    presentPincode: '600002',
    sameAsPermanent: true,
    // Salary & Statutory
    salaryType: 'Monthly',
    salaryBasic: 35000.0,
    salaryHra: 15000.0,
    salarySpecialAllowance: 10000.0,
    salaryTotalCtc: 60000.0,
    salaryPf: 1800.0,
    salaryEsi: 0.0,
    pfNumber: 'MH/BAN/12345/678',
    pfUan: '100987654321',
    esiNumber: '31001234560001001',
    panNumber: 'ABCDE1234F',
    aadhaarNumber: '567812349012',
    // Bank Details
    bankAccountHolder: 'Rahul Sharma',
    bankName: 'HDFC Bank',
    bankAccountNumber: '50100234567890',
    bankIfsc: 'HDFC0001234',
    bankBranch: 'Mount Road',
    bankAccountType: 'Savings',
    // Education & Experience JSON
    educationDegree: 'B.Tech Civil Engineering',
    educationInstitution: 'Anna University',
    educationYear: '2017',
    educationGrade: 'First Class with Distinction',
    educationListJson: jsonEncode([
      {
        'id': '1',
        'degree_name': 'B.Tech Civil Engineering',
        'institute_name': 'Anna University',
        'result': '8.5 CGPA',
        'passing_year': '2017',
        'certificate_name': 'Degree Certificate',
      }
    ]),
    experienceCompany: 'BuildCon Infrastructure',
    experienceRole: 'Junior Site Engineer',
    experienceYears: '3 Years',
    experienceListJson: jsonEncode([
      {
        'id': '1',
        'company_name': 'BuildCon Infrastructure',
        'position': 'Junior Site Engineer',
        'address': 'Chennai',
        'working_duration': '3 Years',
      }
    ]),
    // Family & Emergency
    fatherName: 'Suresh Sharma',
    motherName: 'Meena Sharma',
    emergencyName: 'Suresh Sharma',
    emergencyMobile: '+91 9876543211',
    maritalStatus: 'Unmarried',
  );

  @override
  Future<List<Employee>> getAllEmployees() async {
    if (isInMemory) {
      if (!_memoryEmployees.any((e) => e.employeeId == 'EMP-1001')) {
        _memoryEmployees.add(dummyEmployee);
      }
      return List.unmodifiable(_memoryEmployees);
    }
    final result = <Employee>[];
    final seenKeys = <String>{};

    try {
      final snapshot = await _safeGetQuery(_employeesRef);
      for (final doc in snapshot.docs) {
        final emp = _employeeFromFirestore(doc.data(), doc.id);
        final key = doc.id.isNotEmpty
            ? doc.id
            : (emp.employeeId.isNotEmpty ? emp.employeeId : emp.id.toString());
        if (seenKeys.add(key)) {
          result.add(emp);
        }
      }

      // Ensure at least one Super Admin account exists in Firestore
      final hasSuperAdmin = result.any((e) => e.isSuperAdmin);
      if (!hasSuperAdmin && result.isEmpty) {
        final data = _employeeToFirestore(_superAdminMotherAccount);
        data['created_at'] = FieldValue.serverTimestamp();
        await _employeesRef.doc('EMP-001').set(data, SetOptions(merge: true));
        result.insert(0, _superAdminMotherAccount);
      }

      // Ensure the dummy employee exists in Firestore and memory
      final hasDummyEmployee = result.any(
        (e) =>
            e.employeeId == 'EMP-1001' ||
            e.emailAddress == 'rahul.sharma@igreen.com' ||
            e.id == 1001,
      );
      if (!hasDummyEmployee) {
        final data = _employeeToFirestore(dummyEmployee);
        data['created_at'] = FieldValue.serverTimestamp();
        data['id'] = 1001;
        await _employeesRef.doc('EMP-1001').set(data, SetOptions(merge: true));
        result.add(dummyEmployee);
      }

      _memoryEmployees.clear();
      _memoryEmployees.addAll(result);
    } catch (e) {
      debugPrint('Firebase getAllEmployees error: $e');
      if (result.isEmpty && _memoryEmployees.isNotEmpty) {
        if (!_memoryEmployees.any((e) => e.employeeId == 'EMP-1001')) {
          _memoryEmployees.add(dummyEmployee);
        }
        return List.unmodifiable(_memoryEmployees);
      }
      if (result.isEmpty) {
        result.add(_superAdminMotherAccount);
        result.add(dummyEmployee);
      } else if (!result.any((e) => e.employeeId == 'EMP-1001')) {
        result.add(dummyEmployee);
      }
    }

    return result;
  }

  @override
  Future<List<RegistrationLink>> getRegistrationLinks() async {
    final links = <RegistrationLink>[];

    try {
      final snapshot = await _registrationLinksRef.get();
      final candSnapshot = await _candidateResponsesRef.get();

      final candMap = <String, CandidateResponse>{};
      for (final doc in candSnapshot.docs) {
        final resp = CandidateResponse.fromMap(doc.data());
        if (resp.linkId.isNotEmpty) candMap[resp.linkId] = resp;
        if (resp.candidateId.isNotEmpty) candMap[resp.candidateId] = resp;
        candMap[doc.id] = resp;
        if (resp.employeeData.fullName.isNotEmpty) {
          candMap[resp.employeeData.fullName.trim().toLowerCase()] = resp;
        }
      }

      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final linkId = (data['link_id']?.toString() ?? doc.id).trim();
        data['link_id'] = linkId.isNotEmpty ? linkId : doc.id;
        final empId = (data['employee_id']?.toString() ?? '').trim();
        final empName = (data['employee_name']?.toString() ?? '')
            .trim()
            .toLowerCase();

        final cand =
            candMap[linkId] ??
            candMap[doc.id] ??
            (empId.isNotEmpty ? candMap[empId] : null) ??
            (empName.isNotEmpty && empName != '-' ? candMap[empName] : null);

        if (cand != null) {
          if ((data['employee_name']?.toString() ?? '').isEmpty ||
              data['employee_name'] == '-') {
            data['employee_name'] = cand.employeeData.fullName;
          }
          if ((data['employee_id']?.toString() ?? '').isEmpty ||
              data['employee_id'] == '-') {
            data['employee_id'] = cand.candidateId;
          }
          if (cand.status.isNotEmpty &&
              cand.status.toLowerCase() != 'pending') {
            data['link_status'] = cand.status;
            data['status'] = cand.status;
          }
          if ((data['submitted_date']?.toString() ?? '').isEmpty) {
            data['submitted_date'] = cand.submittedDate;
          }
          if ((data['submitted_by']?.toString() ?? '').isEmpty) {
            data['submitted_by'] = cand.employeeData.fullName;
          }
        }

        final link = RegistrationLink.fromMap(data);
        final statusLower = link.linkStatus.trim().toLowerCase();

        // Automatically delete pending registration links from Firebase if expired
        if (statusLower == 'pending' && link.expiryDate.isNotEmpty) {
          final expiry = DateTime.tryParse(link.expiryDate);
          if (expiry != null && now.isAfter(expiry)) {
            await doc.reference.delete();
            continue;
          }
        }

        links.add(link);
      }

      for (final doc in candSnapshot.docs) {
        final cand = CandidateResponse.fromMap(doc.data());
        final s = cand.status.toLowerCase();
        if (s != 'converted' && s != 'registered') {
          final exists = links.any(
            (l) =>
                (cand.linkId.isNotEmpty && l.linkId == cand.linkId) ||
                (cand.candidateId.isNotEmpty &&
                    (l.employeeId == cand.candidateId ||
                        l.linkId == cand.candidateId)) ||
                (cand.employeeData.fullName.isNotEmpty &&
                    l.employeeName.trim().toLowerCase() ==
                        cand.employeeData.fullName.trim().toLowerCase()),
          );
          if (!exists) {
            links.add(
              RegistrationLink(
                id: cand.id,
                linkId: cand.linkId.isNotEmpty ? cand.linkId : cand.candidateId,
                generatedBy: 'Candidate',
                generatedDate: cand.submittedDate,
                expiryDate: '',
                linkStatus: cand.status,
                employeeName: cand.employeeData.fullName,
                employeeId: cand.candidateId,
                organizationName: cand.employeeData.organizationName,
                department: cand.employeeData.department,
                submittedDate: cand.submittedDate,
                submittedBy: cand.employeeData.fullName,
              ),
            );
          }
        }
      }
    } catch (e, st) {
      debugPrint('Firebase getRegistrationLinks error: $e\n$st');
    }

    return links;
  }

  @override
  Future<RegistrationLink?> getRegistrationLinkById(String linkId) async {
    try {
      final doc = await _safeGetDoc(_registrationLinksRef.doc(linkId));
      if (doc.exists && doc.data() != null) {
        final link = RegistrationLink.fromMap(doc.data()!);
        if (link.linkStatus.trim().toLowerCase() == 'pending' &&
            link.expiryDate.isNotEmpty) {
          final expiry = DateTime.tryParse(link.expiryDate);
          if (expiry != null && DateTime.now().isAfter(expiry)) {
            await doc.reference.delete();
            return null;
          }
        }
        return link;
      }

      final query = await _safeGetQuery(
        _registrationLinksRef
            .where('link_id', isEqualTo: linkId)
            .limit(1),
      );
      if (query.docs.isNotEmpty) {
        return RegistrationLink.fromMap(query.docs.first.data());
      }

      final candQuery = await _safeGetQuery(
        _candidateResponsesRef
            .where('link_id', isEqualTo: linkId)
            .limit(1),
      );
      if (candQuery.docs.isNotEmpty) {
        final resp = CandidateResponse.fromMap(candQuery.docs.first.data());
        return RegistrationLink(
          id: resp.id,
          linkId: resp.linkId.isNotEmpty ? resp.linkId : resp.candidateId,
          generatedBy: 'Candidate',
          generatedDate: resp.submittedDate,
          expiryDate: '',
          linkStatus: resp.status,
          employeeName: resp.employeeData.fullName,
          employeeId: resp.candidateId,
          organizationName: resp.employeeData.organizationName,
          department: resp.employeeData.department,
          submittedDate: resp.submittedDate,
          submittedBy: resp.employeeData.fullName,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateRegistrationLinkStatus({
    required String linkId,
    required String linkStatus,
    String? candidateId,
  }) async {
    try {
      final batch = _firestore.batch();
      if (linkId.isNotEmpty) {
        batch.set(_registrationLinksRef.doc(linkId), {
          'link_status': linkStatus,
          'status': linkStatus,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (candidateId != null && candidateId.isNotEmpty) {
        batch.set(_candidateResponsesRef.doc(candidateId), {
          'status': linkStatus,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Also batch update any candidate_responses matching linkId
      if (linkId.isNotEmpty) {
        final candByLink = await _candidateResponsesRef
            .where('link_id', isEqualTo: linkId)
            .get();
        for (final doc in candByLink.docs) {
          batch.set(doc.reference, {
            'status': linkStatus,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // Also batch update any candidate_responses or registration_links matching candidateId
      if (candidateId != null && candidateId.isNotEmpty) {
        final candById = await _candidateResponsesRef
            .where('candidate_id', isEqualTo: candidateId)
            .get();
        for (final doc in candById.docs) {
          batch.set(doc.reference, {
            'status': linkStatus,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        final linksByCand = await _registrationLinksRef
            .where('employee_id', isEqualTo: candidateId)
            .get();
        for (final doc in linksByCand.docs) {
          batch.set(doc.reference, {
            'link_status': linkStatus,
            'status': linkStatus,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      await batch.commit();

      final query = await _registrationLinksRef
          .where('link_id', isEqualTo: linkId)
          .get();
      for (final doc in query.docs) {
        await doc.reference.set({
          'link_status': linkStatus,
          'status': linkStatus,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('updateRegistrationLinkStatus error: $e');
    }
  }

  @override
  Future<Employee> submitEmployeeRegistration({
    required String linkId,
    required Employee employeeData,
    bool isSubmit = true,
  }) async {
    final batch = _firestore.batch();
    final nowIso = DateTime.now().toIso8601String();

    DocumentSnapshot<Map<String, dynamic>>? linkDoc =
        await _safeGetDoc(_registrationLinksRef.doc(linkId));
    if (!linkDoc.exists || linkDoc.data() == null) {
      final query = await _safeGetQuery(
        _registrationLinksRef
            .where('link_id', isEqualTo: linkId)
            .limit(1),
      );
      if (query.docs.isNotEmpty) {
        linkDoc = query.docs.first;
      }
    }

    if (linkDoc.exists && linkDoc.data() != null) {
      final currentStatus =
          (linkDoc.data()!['link_status'] as String? ?? 'Pending')
              .trim()
              .toLowerCase();
      if (currentStatus == 'converted' || currentStatus == 'registered') {
        throw Exception(
          'This candidate link has already been converted into an employee.',
        );
      }
    }

    final existingCandidateId = (linkDoc.exists && linkDoc.data() != null)
        ? (linkDoc.data()!['employee_id'] as String? ?? '')
        : '';

    String candidateId = employeeData.employeeId;
    if (candidateId.isEmpty ||
        candidateId.startsWith('pending_') ||
        candidateId.startsWith('EMP-')) {
      candidateId =
          existingCandidateId.isNotEmpty &&
              existingCandidateId.startsWith('CAN-')
          ? existingCandidateId
          : await _generateNextCandidateId();
    }

    var finalEmployee = employeeData.copyWith(
      employeeId: candidateId,
      status: isSubmit ? 'Submitted' : 'Draft',
    );

    if (finalEmployee.profileImageUrl.isNotEmpty) {
      final storageUrl = await _uploadEmployeePhotoToStorage(
        candidateId,
        finalEmployee.profileImageUrl,
      );
      finalEmployee = finalEmployee.copyWith(profileImageUrl: storageUrl);
    }

    final targetDocId = linkDoc.exists ? linkDoc.id : linkId;
    final linkRef = _registrationLinksRef.doc(targetDocId);
    final existingStatus = (linkDoc.exists && linkDoc.data() != null)
        ? (linkDoc.data()!['link_status'] as String? ?? 'Pending')
        : 'Pending';

    batch.set(linkRef, {
      'link_id': linkId,
      'link_status': isSubmit
          ? 'Submitted'
          : (existingStatus.isEmpty ? 'Pending' : existingStatus),
      'submitted_date': isSubmit ? nowIso : '',
      'submitted_by': isSubmit ? finalEmployee.fullName : '',
      'employee_name': finalEmployee.fullName,
      'employee_id': candidateId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final candidateResponse = CandidateResponse(
      candidateId: candidateId,
      linkId: linkId,
      employeeData: finalEmployee,
      submittedDate: isSubmit ? nowIso : '',
      status: isSubmit ? 'Submitted' : 'Draft',
    );

    batch.set(
      _candidateResponsesRef.doc(candidateId),
      candidateResponse.toMap(),
      SetOptions(merge: true),
    );

    await _safeCommitBatch(batch);
    return finalEmployee;
  }

  @override
  Future<CandidateResponse?> getCandidateResponseByLinkId(String linkId) async {
    try {
      final query = await _candidateResponsesRef
          .where('link_id', isEqualTo: linkId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return CandidateResponse.fromMap(query.docs.first.data());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CandidateResponse?> getCandidateResponseByCandidateId(
    String candidateId,
  ) async {
    try {
      final doc = await _candidateResponsesRef.doc(candidateId).get();
      if (doc.exists && doc.data() != null) {
        return CandidateResponse.fromMap(doc.data()!);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<CandidateResponse>> getCandidateResponses() async {
    try {
      final snapshot = await _candidateResponsesRef.get();
      return snapshot.docs
          .map((doc) => CandidateResponse.fromMap(doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String> createCorrectionRequest({
    required String candidateId,
    required String linkId,
    required String candidateResponseId,
    required String remarks,
    required String requestedBy,
    bool allowEditing = true,
    Duration validity = const Duration(days: 7),
  }) async {
    final batch = _firestore.batch();

    // Invalidate / expire any existing active correction requests for this candidate/link
    try {
      final existingActive = await _correctionRequestsRef
          .where('candidate_id', isEqualTo: candidateId)
          .where('status', isEqualTo: 'active')
          .get();
      for (final doc in existingActive.docs) {
        batch.update(doc.reference, {
          'status': 'expired',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    // Generate a cryptographically secure 32-byte token
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final rawToken = values
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final tokenHash = CorrectionRequest.hashToken(rawToken);

    final now = DateTime.now();
    final expiresAt = now.add(validity).toIso8601String();
    final reqDocRef = _correctionRequestsRef.doc();

    final request = CorrectionRequest(
      id: reqDocRef.id,
      candidateResponseId: candidateResponseId.isNotEmpty
          ? candidateResponseId
          : candidateId,
      candidateId: candidateId,
      linkId: linkId,
      remarks: remarks.trim(),
      status: 'active',
      allowEditing: allowEditing,
      tokenHash: tokenHash,
      createdAt: now.toIso8601String(),
      expiresAt: expiresAt,
      requestedBy: requestedBy,
    );

    batch.set(reqDocRef, request.toMap());

    // Update candidate response and registration link status to 'Correction Requested'
    if (candidateId.isNotEmpty) {
      batch.set(_candidateResponsesRef.doc(candidateId), {
        'status': 'Correction Requested',
        'has_correction_request': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (linkId.isNotEmpty) {
      final linkQuery = await _registrationLinksRef
          .where('link_id', isEqualTo: linkId)
          .limit(1)
          .get();
      if (linkQuery.docs.isNotEmpty) {
        batch.set(linkQuery.docs.first.reference, {
          'link_status': 'Correction Requested',
          'status': 'Correction Requested',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
    return rawToken;
  }

  @override
  Future<CorrectionRequest?> validateCorrectionToken(String rawToken) async {
    if (rawToken.trim().isEmpty) return null;
    final tokenHash = CorrectionRequest.hashToken(rawToken);

    try {
      final query = await _correctionRequestsRef
          .where('token_hash', isEqualTo: tokenHash)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      final request = CorrectionRequest.fromMap(doc.data(), doc.id);

      if (request.status != 'active' || request.usedAt != null) {
        return null;
      }

      if (request.isExpired) {
        await doc.reference.update({
          'status': 'expired',
          'updated_at': FieldValue.serverTimestamp(),
        });
        return null;
      }

      return request;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CandidateResponse?> getCandidateResponseForCorrection(
    String rawToken,
  ) async {
    final req = await validateCorrectionToken(rawToken);
    if (req == null) return null;

    if (req.candidateId.isNotEmpty) {
      final byCandId = await getCandidateResponseByCandidateId(req.candidateId);
      if (byCandId != null) return byCandId;
    }

    if (req.linkId.isNotEmpty) {
      final byLinkId = await getCandidateResponseByLinkId(req.linkId);
      if (byLinkId != null) return byLinkId;
    }

    return null;
  }

  @override
  Future<List<CorrectionRequest>> getCorrectionRequestsForCandidate(
    String candidateId,
  ) async {
    try {
      final query = await _correctionRequestsRef
          .where('candidate_id', isEqualTo: candidateId)
          .get();
      final list = query.docs
          .map((d) => CorrectionRequest.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> submitCandidateCorrection({
    required String rawToken,
    required Employee updatedEmployee,
  }) async {
    final req = await validateCorrectionToken(rawToken);
    if (req == null || !req.isValidActive) return false;

    final batch = _firestore.batch();
    final nowIso = DateTime.now().toIso8601String();

    Employee finalEmp = updatedEmployee;
    if (finalEmp.profileImageUrl.isNotEmpty &&
        (finalEmp.profileImageUrl.startsWith('data:') ||
            finalEmp.profileImageUrl.startsWith('blob:'))) {
      final storageUrl = await _uploadEmployeePhotoToStorage(
        req.candidateId,
        finalEmp.profileImageUrl,
      );
      finalEmp = finalEmp.copyWith(profileImageUrl: storageUrl);
    }

    final candidateResp = CandidateResponse(
      candidateId: req.candidateId,
      linkId: req.linkId,
      organizationId: finalEmp.organizationId,
      employeeData: finalEmp,
      submittedDate: nowIso,
      status: 'Resubmitted',
    );

    if (req.candidateId.isNotEmpty) {
      batch.set(
        _candidateResponsesRef.doc(req.candidateId),
        candidateResp.toMap(),
        SetOptions(merge: true),
      );
    }
    if (req.candidateResponseId.isNotEmpty &&
        req.candidateResponseId != req.candidateId) {
      batch.set(
        _candidateResponsesRef.doc(req.candidateResponseId),
        candidateResp.toMap(),
        SetOptions(merge: true),
      );
    }

    if (req.linkId.isNotEmpty) {
      batch.set(_registrationLinksRef.doc(req.linkId), {
        'link_status': 'Resubmitted',
        'status': 'Resubmitted',
        'submitted_date': nowIso,
        'submitted_by': finalEmp.fullName,
        'employee_name': finalEmp.fullName,
        'employee_id': req.candidateId,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    batch.update(_correctionRequestsRef.doc(req.id), {
      'status': 'completed',
      'used_at': nowIso,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Also update any queried docs
    if (req.linkId.isNotEmpty) {
      final linkQuery = await _registrationLinksRef
          .where('link_id', isEqualTo: req.linkId)
          .get();
      for (final doc in linkQuery.docs) {
        await doc.reference.set({
          'link_status': 'Resubmitted',
          'status': 'Resubmitted',
          'submitted_date': nowIso,
          'submitted_by': finalEmp.fullName,
          'employee_name': finalEmp.fullName,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    if (req.candidateId.isNotEmpty) {
      final candLinkQuery = await _registrationLinksRef
          .where('employee_id', isEqualTo: req.candidateId)
          .get();
      for (final doc in candLinkQuery.docs) {
        await doc.reference.set({
          'link_status': 'Resubmitted',
          'status': 'Resubmitted',
          'submitted_date': nowIso,
          'submitted_by': finalEmp.fullName,
          'employee_name': finalEmp.fullName,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    return true;
  }

  @override
  Future<Employee> submitCandidateRegistration({
    required String linkId,
    required Employee candidateData,
  }) async {
    return submitEmployeeRegistration(
      linkId: linkId,
      employeeData: candidateData,
      isSubmit: true,
    );
  }

  @override
  Future<Employee> convertCandidateToEmployee({
    required String linkId,
    required Employee employeeData,
  }) async {
    String empId = employeeData.employeeId;
    if (!empId.startsWith('EMP-')) {
      final all = await getAllEmployees();
      final existing = all
          .where(
            (e) =>
                (employeeData.aadhaarNumber.isNotEmpty &&
                    e.aadhaarNumber == employeeData.aadhaarNumber) ||
                (employeeData.emailAddress.isNotEmpty &&
                    e.emailAddress.toLowerCase() ==
                        employeeData.emailAddress.toLowerCase()),
          )
          .firstOrNull;

      if (existing != null && existing.employeeId.startsWith('EMP-')) {
        empId = existing.employeeId;
      } else {
        empId = await _generateNextEmployeeId();
      }
    }

    final activeEmployee = employeeData.copyWith(
      employeeId: empId,
      status: 'Active',
      userType: employeeData.userType.isEmpty
          ? 'EMPLOYEE'
          : employeeData.userType,
    );

    final savedEmployee = await addEmployee(activeEmployee);

    await updateRegistrationLinkStatus(
      linkId: linkId,
      linkStatus: 'Registered',
    );

    return savedEmployee;
  }

  /// Generates the next CAN-XXXX candidate ID for registration form submissions.
  /// This sequence is independent from the EMP-XXXX employee ID sequence.
  Future<String> _generateNextCandidateId() async {
    try {
      final snapshot = await _safeGetQuery(_candidateResponsesRef);
      int maxNum = 0;
      for (final doc in snapshot.docs) {
        final code = (doc.data()['candidate_id'] as String?) ?? doc.id;
        if (!code.startsWith('CAN-')) continue;
        final numPart = code.replaceAll(RegExp(r'[^0-9]'), '');
        if (numPart.isNotEmpty) {
          final val = int.tryParse(numPart) ?? 0;
          if (val > maxNum) maxNum = val;
        }
      }
      final nextNum = maxNum + 1;
      return 'CAN-${nextNum.toString().padLeft(4, '0')}';
    } catch (_) {
      return 'CAN-0001';
    }
  }

  /// Generates the next EMP-XXXX employee ID for active employees.
  Future<String> _generateNextEmployeeId() async {
    if (isInMemory) {
      int maxNum = 0;
      for (final emp in _memoryEmployees) {
        final code = emp.employeeId;
        if (!code.toUpperCase().startsWith('EMP-')) continue;
        final numPart = code.replaceAll(RegExp(r'[^0-9]'), '');
        if (numPart.isNotEmpty) {
          final val = int.tryParse(numPart) ?? 0;
          if (val > maxNum) maxNum = val;
        }
      }
      final nextNum = maxNum + 1;
      return 'EMP-${nextNum.toString().padLeft(4, '0')}';
    }

    final snapshot = await _safeGetQuery(_employeesRef);
    int maxNum = 0;
    for (final doc in snapshot.docs) {
      final code = (doc.data()['employee_id'] as String?) ?? doc.id;
      if (!code.toUpperCase().startsWith('EMP-')) continue;
      final numPart = code.replaceAll(RegExp(r'[^0-9]'), '');
      if (numPart.isNotEmpty) {
        final val = int.tryParse(numPart) ?? 0;
        if (val > maxNum) maxNum = val;
      }
    }
    final nextNum = maxNum + 1;
    return 'EMP-${nextNum.toString().padLeft(4, '0')}';
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  @override
  Future<void> clearAllData() async {
    try {
      final emps = await _employeesRef.get();
      for (final doc in emps.docs) {
        await doc.reference.delete();
      }
      final links = await _registrationLinksRef.get();
      for (final doc in links.docs) {
        await doc.reference.delete();
      }
      final responses = await _candidateResponsesRef.get();
      for (final doc in responses.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  @override
  Future<ColumnPreference?> getColumnPreference(String tableId) async {
    final doc = await _columnPreferencesRef.doc(tableId).get();
    if (doc.exists && doc.data() != null) {
      return ColumnPreference.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> saveColumnPreference(ColumnPreference preference) async {
    await _columnPreferencesRef
        .doc(preference.tableId)
        .set(preference.toMap(), SetOptions(merge: true));
  }

  Future<String> _uploadEmployeePhotoToStorage(
    String docId,
    String imagePathOrData,
  ) async {
    if (imagePathOrData.isEmpty ||
        imagePathOrData.startsWith('http://') ||
        imagePathOrData.startsWith('https://')) {
      return imagePathOrData;
    }
    try {
      Uint8List? bytes;
      String ext = 'jpg';

      if (imagePathOrData.startsWith('data:image')) {
        final parts = imagePathOrData.split(',');
        if (parts.length > 1) {
          if (parts[0].contains('png')) {
            ext = 'png';
          } else if (parts[0].contains('webp')) {
            ext = 'webp';
          }
          bytes = base64Decode(parts[1]);
        }
      } else if (kIsWeb || imagePathOrData.startsWith('blob:')) {
        final response = await http.get(Uri.parse(imagePathOrData));
        bytes = response.bodyBytes;
      } else {
        final file = File(imagePathOrData);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        Uint8List uploadBytes = bytes;
        // Compress image if larger than 250KB to keep storage lightweight and fast
        if (uploadBytes.lengthInBytes > 250000) {
          try {
            final decoded = img.decodeImage(uploadBytes);
            if (decoded != null) {
              final resized = (decoded.width > 720 || decoded.height > 720)
                  ? img.copyResize(decoded, width: 720, height: 720)
                  : decoded;
              uploadBytes = Uint8List.fromList(
                img.encodeJpg(resized, quality: 85),
              );
              ext = 'jpg';
            }
          } catch (_) {}
        }

        final storagePath =
            'Employee Photo/${docId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final ref = _storage.ref().child(storagePath);
        final contentType = ext == 'png'
            ? 'image/png'
            : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        UploadTask? uploadTask;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            uploadTask = ref.putData(
              uploadBytes,
              SettableMetadata(contentType: contentType),
            );
            final snapshot = await uploadTask;
            return await snapshot.ref.getDownloadURL();
          } catch (storageErr) {
            if (attempt == 3) rethrow;
            await Future.delayed(Duration(milliseconds: 350 * attempt));
          }
        }
      }
    } catch (e) {
      debugPrint('Firebase Storage upload failed: $e');
    }

    // Safety fallback: If Firebase Storage failed and image string is too large (> 400KB),
    // compress it to a light JPEG base64 to ensure it NEVER exceeds Firestore's 1,048,487 byte document limit.
    if (imagePathOrData.length > 400000) {
      try {
        final commaIdx = imagePathOrData.indexOf(',');
        final rawStr = commaIdx != -1
            ? imagePathOrData.substring(commaIdx + 1)
            : imagePathOrData;
        final rawBytes = base64Decode(rawStr);
        final decoded = img.decodeImage(rawBytes);
        if (decoded != null) {
          final resized = (decoded.width > 600 || decoded.height > 600)
              ? img.copyResize(decoded, width: 600, height: 600)
              : decoded;
          final compressedJpg = img.encodeJpg(resized, quality: 80);
          return 'data:image/jpeg;base64,${base64Encode(compressedJpg)}';
        }
      } catch (_) {}
    }

    return imagePathOrData;
  }
}
