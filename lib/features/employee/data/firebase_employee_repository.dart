import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../organization/domain/column_preference.dart';
import '../domain/candidate_response.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';
import '../domain/registration_link.dart';

class FirebaseEmployeeRepository implements EmployeeRepository {
  final FirebaseFirestore? _customFirestore;
  final FirebaseStorage? _customStorage;

  FirebaseEmployeeRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _customFirestore = firestore,
        _customStorage = storage;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  CollectionReference<Map<String, dynamic>> get _registrationLinksRef =>
      _firestore.collection('registration_links');

  CollectionReference<Map<String, dynamic>> get _candidateResponsesRef =>
      _firestore.collection('candidate_responses');

  CollectionReference<Map<String, dynamic>> get _columnPreferencesRef =>
      _firestore.collection('column_preferences');

  String _folderForEmployee(String employeeId, String role) {
    final normalizedRole = role.trim().isEmpty ? 'employees' : role.trim().toLowerCase();
    final normalizedId = employeeId.trim().isEmpty ? 'unassigned' : employeeId.trim();
    return 'employee_management/profiles/$normalizedRole/$normalizedId';
  }

  // Helper: Map Employee object to Firestore document map
  Map<String, dynamic> _employeeToFirestore(Employee emp) {
    final map = emp.toMap();

    // Convert list objects into native Firestore Array of Maps instead of raw JSON strings
    map['education_items'] =
        emp.educationItems.map((e) => e.toMap()).toList();
    map['experience_items'] =
        emp.experienceItems.map((e) => e.toMap()).toList();
    map['document_items'] =
        emp.documentItems.map((e) => e.toMap()).toList();

    map['updated_at'] = FieldValue.serverTimestamp();
    return map;
  }

  // Helper: Map Firestore document data to Employee object
  Employee _employeeFromFirestore(Map<String, dynamic> map, String docId) {
    final mutableMap = Map<String, dynamic>.from(map);

    // If ID is missing or 0, try parsing numeric part of docId or generate deterministic hash
    if (!mutableMap.containsKey('id') || mutableMap['id'] == null || mutableMap['id'] == 0) {
      final parsed = int.tryParse(docId.replaceAll(RegExp(r'\D'), ''));
      mutableMap['id'] = (parsed != null && parsed != 0) ? parsed : (docId.hashCode & 0x7FFFFFFF);
    }

    // Convert Firestore native array lists back to JSON strings for domain model compatibility
    if (mutableMap['education_items'] is List) {
      mutableMap['education_list_json'] =
          jsonEncode(mutableMap['education_items']);
    }
    if (mutableMap['experience_items'] is List) {
      mutableMap['experience_list_json'] =
          jsonEncode(mutableMap['experience_items']);
    }
    if (mutableMap['document_items'] is List) {
      mutableMap['document_list_json'] =
          jsonEncode(mutableMap['document_items']);
    }

    return Employee.fromMap(mutableMap);
  }

  @override
  Future<List<Employee>> getEmployees() async {
    final all = await getAllEmployees();
    final result = <Employee>[];
    final toFix = <Employee>[]; // employees needing an EMP- ID assigned

    for (final emp in all) {
      final s = emp.status.trim().toLowerCase();
      if (s == 'active' || s == 'converted' || s == 'submitted' || s.isEmpty) {
        final empIdUpper = emp.employeeId.trim().toUpperCase();
        if (empIdUpper.isEmpty || !empIdUpper.startsWith('EMP-')) {
          toFix.add(emp);
        } else {
          result.add(emp);
        }
      }
    }

    // Fix employees without EMP- IDs in the background (non-blocking)
    if (toFix.isNotEmpty) {
      _fixEmployeeIds(toFix);
      result.addAll(toFix);
    }

    return result.isNotEmpty ? result : all;
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

  @override
  Future<Employee?> getEmployeeById(int id) async {
    final snapshot =
        await _employeesRef.where('id', isEqualTo: id).limit(1).get();
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
    emp = emp.copyWith(status: 'Active');

    final docId = emp.employeeId;
    if (emp.profileImageUrl.isNotEmpty) {
      final storageUrl = await _uploadEmployeePhotoToStorage(docId, emp.profileImageUrl);
      emp = emp.copyWith(profileImageUrl: storageUrl);
    }

    final data = _employeeToFirestore(emp);
    data['created_at'] = FieldValue.serverTimestamp();

    await _employeesRef.doc(docId).set(data, SetOptions(merge: true));

    final parsed = int.tryParse(docId.replaceAll(RegExp(r'\D'), ''));
    final assignedId = (parsed != null && parsed != 0)
        ? parsed
        : (docId.hashCode & 0x7FFFFFFF);

    return emp.copyWith(
      id: emp.id != 0 ? emp.id : assignedId,
    );
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    var emp = employee;
    final empIdUpper = emp.employeeId.trim().toUpperCase();
    if (emp.status.toLowerCase() == 'active' &&
        (empIdUpper.isEmpty ||
         empIdUpper.startsWith('CAN-') ||
         empIdUpper.startsWith('PENDING_') ||
         empIdUpper.startsWith('REG-') ||
         !empIdUpper.startsWith('EMP-'))) {
      final newEmpId = await _generateNextEmployeeId();
      emp = emp.copyWith(employeeId: newEmpId);
    }

    String docId = emp.employeeId.isNotEmpty
        ? emp.employeeId
        : (emp.id != 0 ? emp.id.toString() : '');

    if (docId.isEmpty) {
      final snapshot =
          await _employeesRef.where('id', isEqualTo: emp.id).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        docId = snapshot.docs.first.id;
      } else {
        docId = _employeesRef.doc().id;
      }
    }

    if (emp.profileImageUrl.isNotEmpty) {
      final storageUrl = await _uploadEmployeePhotoToStorage(docId, emp.profileImageUrl);
      emp = emp.copyWith(profileImageUrl: storageUrl);
    }

    final data = _employeeToFirestore(emp);
    await _employeesRef.doc(docId).set(data, SetOptions(merge: true));
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
      final docId = doc.id;
      final parsed = int.tryParse(docId.replaceAll(RegExp(r'\D'), ''));
      final assignedId = (parsed != null && parsed != 0)
          ? parsed
          : (docId.hashCode & 0x7FFFFFFF);
      final empId = (data['id'] as int?) ?? assignedId;

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
    // 1. Try querying by the stored integer 'id' field
    final snapshot =
        await _employeesRef.where('id', isEqualTo: id).limit(1).get();
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
      final parsed = int.tryParse(docId.replaceAll(RegExp(r'\D'), ''));
      final assignedId = (parsed != null && parsed != 0)
          ? parsed
          : (docId.hashCode & 0x7FFFFFFF);
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
    );

    final data = link.toMap();
    data['created_at'] = FieldValue.serverTimestamp();
    data['updated_at'] = FieldValue.serverTimestamp();

    await _registrationLinksRef.doc(linkId).set(data);
    return link;
  }

  @override
  Future<List<Employee>> getAllEmployees() async {
    final result = <Employee>[];
    final seenIds = <int>{};

    try {
      final snapshot = await _employeesRef.get();
      for (final doc in snapshot.docs) {
        final emp = _employeeFromFirestore(doc.data(), doc.id);
        if (seenIds.add(emp.id)) {
          result.add(emp);
        }
      }
    } catch (e) {
      debugPrint('Firebase getAllEmployees error: $e');
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
        candMap[resp.linkId] = resp;
        candMap[resp.candidateId] = resp;
      }

      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final linkId = (data['link_id']?.toString() ?? doc.id).trim();
        data['link_id'] = linkId.isNotEmpty ? linkId : doc.id;

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

        final cand = candMap[linkId] ?? candMap[data['employee_id']?.toString() ?? ''];
        if (cand != null) {
          if ((data['employee_name']?.toString() ?? '').isEmpty) {
            data['employee_name'] = cand.employeeData.fullName;
          }
          if ((data['employee_id']?.toString() ?? '').isEmpty) {
            data['employee_id'] = cand.candidateId;
          }
        }

        links.add(link);
      }


      for (final doc in candSnapshot.docs) {
        final cand = CandidateResponse.fromMap(doc.data());
        final s = cand.status.toLowerCase();
        if (s != 'converted' && s != 'registered') {
          final exists = links.any((l) => l.linkId == cand.linkId || l.employeeId == cand.candidateId);
          if (!exists) {
            links.add(RegistrationLink(
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
            ));
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
      final doc = await _registrationLinksRef.doc(linkId).get();
      if (doc.exists && doc.data() != null) {
        final link = RegistrationLink.fromMap(doc.data()!);
        if (link.linkStatus.trim().toLowerCase() == 'pending' && link.expiryDate.isNotEmpty) {
          final expiry = DateTime.tryParse(link.expiryDate);
          if (expiry != null && DateTime.now().isAfter(expiry)) {
            await doc.reference.delete();
            return null;
          }
        }
        return link;
      }


      final query = await _registrationLinksRef
          .where('link_id', isEqualTo: linkId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return RegistrationLink.fromMap(query.docs.first.data());
      }

      final candQuery = await _candidateResponsesRef
          .where('link_id', isEqualTo: linkId)
          .limit(1)
          .get();
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
  }) async {
    try {
      await _registrationLinksRef.doc(linkId).set(
        {
          'link_status': linkStatus,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      final query = await _registrationLinksRef
          .where('link_id', isEqualTo: linkId)
          .get();
      for (final doc in query.docs) {
        await doc.reference.set(
          {
            'link_status': linkStatus,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  @override
  Future<Employee> submitEmployeeRegistration({
    required String linkId,
    required Employee employeeData,
    bool isSubmit = true,
  }) async {
    final batch = _firestore.batch();
    final nowIso = DateTime.now().toIso8601String();

    DocumentSnapshot<Map<String, dynamic>>? linkDoc = await _registrationLinksRef.doc(linkId).get();
    if (!linkDoc.exists || linkDoc.data() == null) {
      final query = await _registrationLinksRef
          .where('link_id', isEqualTo: linkId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        linkDoc = query.docs.first;
      }
    }

    if (linkDoc.exists && linkDoc.data() != null) {
      final currentStatus = (linkDoc.data()!['link_status'] as String? ?? 'Pending').trim().toLowerCase();
      if (currentStatus == 'converted' || currentStatus == 'registered') {
        throw Exception('This candidate link has already been converted into an employee.');
      }
    }

    final existingCandidateId = (linkDoc.exists && linkDoc.data() != null)
        ? (linkDoc.data()!['employee_id'] as String? ?? '')
        : '';

    String candidateId = employeeData.employeeId;
    if (candidateId.isEmpty || candidateId.startsWith('pending_') || candidateId.startsWith('EMP-')) {
      candidateId = existingCandidateId.isNotEmpty && existingCandidateId.startsWith('CAN-')
          ? existingCandidateId
          : await _generateNextCandidateId();
    }

    var finalEmployee = employeeData.copyWith(
      employeeId: candidateId,
      status: isSubmit ? 'Submitted' : 'Draft',
    );

    if (finalEmployee.profileImageUrl.isNotEmpty) {
      final storageUrl = await _uploadEmployeePhotoToStorage(candidateId, finalEmployee.profileImageUrl);
      finalEmployee = finalEmployee.copyWith(profileImageUrl: storageUrl);
    }

    final targetDocId = linkDoc.exists ? linkDoc.id : linkId;
    final linkRef = _registrationLinksRef.doc(targetDocId);
    batch.set(linkRef, {
      'link_id': linkId,
      'link_status': 'Submitted',
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

    batch.set(_candidateResponsesRef.doc(candidateId), candidateResponse.toMap(), SetOptions(merge: true));

    await batch.commit();
    return finalEmployee;
  }

  @override
  Future<CandidateResponse?> getCandidateResponseByLinkId(String linkId) async {
    try {
      final query = await _candidateResponsesRef.where('link_id', isEqualTo: linkId).limit(1).get();
      if (query.docs.isNotEmpty) {
        return CandidateResponse.fromMap(query.docs.first.data());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CandidateResponse?> getCandidateResponseByCandidateId(String candidateId) async {
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
      return snapshot.docs.map((doc) => CandidateResponse.fromMap(doc.data())).toList();
    } catch (_) {
      return [];
    }
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
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final empId = (employeeData.employeeId.isNotEmpty && employeeData.employeeId.startsWith('EMP-'))
        ? employeeData.employeeId
        : 'EMP-${timestamp.substring(timestamp.length - 4)}';

    final activeEmployee = employeeData.copyWith(
      employeeId: empId,
      status: 'Active',
      userType: employeeData.userType.isEmpty ? 'EMPLOYEE' : employeeData.userType,
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
      final snapshot = await _candidateResponsesRef.get();
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
    final snapshot = await _employeesRef.get();
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
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
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

  Future<String> _uploadEmployeePhotoToStorage(String docId, String imagePathOrData) async {
    if (imagePathOrData.isEmpty || imagePathOrData.startsWith('http://') || imagePathOrData.startsWith('https://')) {
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
        final storagePath = 'Employee Photo/${docId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final ref = _storage.ref().child(storagePath);
        final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
        return await uploadTask.ref.getDownloadURL();
      }
    } catch (_) {}
    return imagePathOrData;
  }
}
