import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../organization/domain/column_preference.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';
import '../domain/registration_link.dart';

class FirebaseEmployeeRepository implements EmployeeRepository {
  final FirebaseFirestore _firestore;
  final Uri cloudinarySignerBaseUri;

  FirebaseEmployeeRepository({
    FirebaseFirestore? firestore,
    Uri? cloudinarySignerBaseUri,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        cloudinarySignerBaseUri = cloudinarySignerBaseUri ??
            Uri.parse('http://127.0.0.1:3000');

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  CollectionReference<Map<String, dynamic>> get _registrationLinksRef =>
      _firestore.collection('registration_links');

  CollectionReference<Map<String, dynamic>> get _columnPreferencesRef =>
      _firestore.collection('column_preferences');

  String _folderForEmployee(String employeeId, String role) {
    final normalizedRole = role.trim().isEmpty ? 'employees' : role.trim().toLowerCase();
    final normalizedId = employeeId.trim().isEmpty ? 'unassigned' : employeeId.trim();
    return 'employee_management/$normalizedRole/$normalizedId/profile';
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
    return all
        .where((emp) =>
            emp.employeeId.startsWith('EMP-') ||
            (!emp.employeeId.startsWith('CAN-') && !emp.employeeId.startsWith('pending_')))
        .toList();
  }

  @override
  Future<List<Employee>> getAllEmployees() async {
    final snapshot = await _employeesRef.get();
    
    if (snapshot.docs.isEmpty) {
      const sampleEmp = Employee(
        id: 1,
        employeeId: 'EMP-0001',
        firstName: 'Saravanan',
        lastName: 'G S',
        emailAddress: 'Saravanan@igreentec.in',
        phoneNumber: '8760098789',
        gender: 'Male',
        dob: '13-05-1982',
        organizationName: 'iGreen Tech',
        department: 'Management',
        designation: 'Company Director',
        employmentType: 'Full-Time',
        joiningDate: '29-04-2017',
        status: 'Active',
        bloodGroup: 'B+',
        userType: 'SUPER_ADMIN',
        aadhaarNumber: '833750993144',
        pfNumber: '100338738050',
        city: 'Chennai',
        state: 'Tamil Nadu',
      );
      await addEmployee(sampleEmp);
      final newSnapshot = await _employeesRef.get();
      return newSnapshot.docs
          .map((doc) => _employeeFromFirestore(doc.data(), doc.id))
          .toList();
    }
    
    final employees = snapshot.docs.map((doc) {
      return _employeeFromFirestore(doc.data(), doc.id);
    }).toList();
    
    for (var i = 0; i < employees.length; i++) {
      if (employees[i].emailAddress.toLowerCase() == 'saravanan@igreentec.in') {
        if (employees[i].userType != 'SUPER_ADMIN' || employees[i].status != 'Active') {
          final updatedAdmin = employees[i].copyWith(
            userType: 'SUPER_ADMIN',
            status: 'Active',
          );
          updateEmployee(updatedAdmin);
          employees[i] = updatedAdmin;
        }
      }
    }
    
    return employees;
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
    final docId = employee.employeeId.isNotEmpty
        ? employee.employeeId
        : (employee.id != 0 ? employee.id.toString() : _employeesRef.doc().id);

    final data = _employeeToFirestore(employee);
    data['created_at'] = FieldValue.serverTimestamp();

    await _employeesRef.doc(docId).set(data, SetOptions(merge: true));

    final parsed = int.tryParse(docId.replaceAll(RegExp(r'\D'), ''));
    final assignedId = (parsed != null && parsed != 0)
        ? parsed
        : (docId.hashCode & 0x7FFFFFFF);

    return employee.copyWith(
      id: employee.id != 0 ? employee.id : assignedId,
      employeeId: employee.employeeId.isNotEmpty ? employee.employeeId : docId,
    );
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    String docId = employee.employeeId.isNotEmpty
        ? employee.employeeId
        : (employee.id != 0 ? employee.id.toString() : '');

    if (docId.isEmpty) {
      final snapshot =
          await _employeesRef.where('id', isEqualTo: employee.id).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        docId = snapshot.docs.first.id;
      } else {
        docId = _employeesRef.doc().id;
      }
    }

    final data = _employeeToFirestore(employee);
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
          if (effectiveDate != null) 'effective_date': effectiveDate,
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
    final request = http.MultipartRequest(
      'POST',
      cloudinarySignerBaseUri.resolve('/cloudinary/upload-image'),
    );
    request.fields['employeeId'] = employeeId;
    request.fields['role'] = role;
    request.fields['folder'] = folder;
    request.fields['fileName'] = fileName;
    request.fields['mimeType'] = mimeType;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: fileName,
    ));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary upload failed: $body');
    }
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return EmployeePhotoAsset(
      url: decoded['secureUrl'] as String? ?? '',
      publicId: decoded['publicId'] as String? ?? '',
      folder: decoded['folder'] as String? ?? folder,
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
  Future<List<RegistrationLink>> getRegistrationLinks() async {
    final snapshot = await _registrationLinksRef.get();
    return snapshot.docs
        .map((doc) => RegistrationLink.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<RegistrationLink?> getRegistrationLinkById(String linkId) async {
    final doc = await _registrationLinksRef.doc(linkId).get();
    if (doc.exists && doc.data() != null) {
      return RegistrationLink.fromMap(doc.data()!);
    }

    final query = await _registrationLinksRef
        .where('link_id', isEqualTo: linkId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return RegistrationLink.fromMap(query.docs.first.data());
    }

    return null;
  }

  @override
  Future<void> updateRegistrationLinkStatus({
    required String linkId,
    required String linkStatus,
  }) async {
    await _registrationLinksRef.doc(linkId).set(
      {
        'link_status': linkStatus,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (linkStatus == 'Accepted') {
      final linkDoc = await _registrationLinksRef.doc(linkId).get();
      if (linkDoc.exists) {
        final linkData = linkDoc.data()!;
        final linkEmpId = linkData['employee_id'] as String? ?? '';
        final empQuery = await _employeesRef
            .where('employee_id', isEqualTo: linkEmpId.isNotEmpty ? linkEmpId : linkId)
            .get();

        String newEmpId = '';
        if (empQuery.docs.isNotEmpty) {
          final doc = empQuery.docs.first;
          final currentId = doc.data()['employee_id'] as String? ?? '';
          if (!currentId.startsWith('EMP-')) {
            newEmpId = await _generateNextEmployeeId();
            await doc.reference.update({
              'employee_id': newEmpId,
              'status': 'Active',
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        } else {
          newEmpId = await _generateNextEmployeeId();
          final name = linkData['employee_name'] as String? ?? 'Candidate';
          final parts = name.trim().split(' ');
          final firstName = parts.first;
          final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          final newEmp = Employee(
            id: 0,
            employeeId: newEmpId,
            firstName: firstName,
            lastName: lastName,
            emailAddress: '',
            phoneNumber: '',
            gender: '',
            dob: '',
            organizationName: linkData['organization_name'] as String? ?? 'iGreen Tech',
            department: linkData['department'] as String? ?? 'Management',
            designation: 'Staff',
            employmentType: 'Full-Time',
            joiningDate: DateFormat('dd-MM-yyyy').format(DateTime.now()),
            status: 'Active',
          );
          await _employeesRef.doc(newEmpId).set(_employeeToFirestore(newEmp));
        }

        if (newEmpId.isNotEmpty) {
          await _registrationLinksRef.doc(linkId).update({
            'employee_id': newEmpId,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
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

    final linkDoc = await _registrationLinksRef.doc(linkId).get();
    if (!linkDoc.exists) {
      throw Exception('Invalid registration link.');
    }
    final linkData = linkDoc.data()!;
    final linkStatus = linkData['link_status'] as String? ?? 'Pending';
    if (linkStatus != 'Pending') {
      throw Exception('This registration link has already been used or expired.');
    }
    final existingEmpId = linkData['employee_id'] as String? ?? '';

    String newEmpId = employeeData.employeeId;
    if (newEmpId.isEmpty || newEmpId.startsWith('pending_')) {
      newEmpId = existingEmpId.isNotEmpty && existingEmpId.startsWith('EMP-')
          ? existingEmpId
          : await _generateNextCandidateId();
    }

    final tempPassword = employeeData.temporaryPassword.isNotEmpty
        ? employeeData.temporaryPassword
        : _generateRandomCode(10);

    final finalEmployee = employeeData.copyWith(
      employeeId: newEmpId,
      status: isSubmit ? 'Active' : 'Draft',
      temporaryPassword: tempPassword,
    );

    final linkRef = _registrationLinksRef.doc(linkId);
    batch.set(linkRef, {
      'link_status': isSubmit ? 'Completed' : 'Pending',
      'submitted_date': isSubmit ? nowIso : '',
      'submitted_by': isSubmit ? finalEmployee.fullName : '',
      'employee_name': finalEmployee.fullName,
      'employee_id': newEmpId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final empDocId = newEmpId;

    final empData = _employeeToFirestore(finalEmployee);
    empData['created_at'] = FieldValue.serverTimestamp();
    batch.set(_employeesRef.doc(empDocId), empData, SetOptions(merge: true));

    await batch.commit();
    return finalEmployee;
  }

  /// Generates the next CAN-XXXX candidate ID for registration form submissions.
  /// This sequence is independent from the EMP-XXXX employee ID sequence.
  Future<String> _generateNextCandidateId() async {
    final snapshot = await _employeesRef.get();
    int maxNum = 0;
    for (final doc in snapshot.docs) {
      final code = (doc.data()['employee_id'] as String?) ?? doc.id;
      if (!code.startsWith('CAN-')) continue;
      final numPart = code.replaceAll(RegExp(r'[^0-9]'), '');
      if (numPart.isNotEmpty) {
        final val = int.tryParse(numPart) ?? 0;
        if (val > maxNum) maxNum = val;
      }
    }
    final nextNum = maxNum + 1;
    return 'CAN-${nextNum.toString().padLeft(4, '0')}';
  }

  /// Generates the next EMP-XXXX employee ID for manually created employees.
  /// Used only by the Employee Management module — do NOT call from registration flow.
  // ignore: unused_element
  Future<String> _generateNextEmployeeId() async {
    final snapshot = await _employeesRef.get();
    int maxNum = 0;
    for (final doc in snapshot.docs) {
      final code = (doc.data()['employee_id'] as String?) ?? doc.id;
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
}
