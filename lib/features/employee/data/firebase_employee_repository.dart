import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../organization/domain/column_preference.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';
import '../domain/registration_link.dart';

class FirebaseEmployeeRepository implements EmployeeRepository {
  final FirebaseFirestore _firestore;

  FirebaseEmployeeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  CollectionReference<Map<String, dynamic>> get _registrationLinksRef =>
      _firestore.collection('registration_links');

  CollectionReference<Map<String, dynamic>> get _columnPreferencesRef =>
      _firestore.collection('column_preferences');

  CollectionReference<Map<String, dynamic>> get _responsesRef =>
      _firestore.collection('employee_responses');

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
    final snapshot = await _employeesRef.get();
    if (snapshot.docs.isEmpty) {
      // Seed sample employee if collection is currently empty
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
    return snapshot.docs
        .map((doc) => _employeeFromFirestore(doc.data(), doc.id))
        .toList();
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
  Future<void> addEmployee(Employee employee) async {
    final docId = employee.employeeId.isNotEmpty
        ? employee.employeeId
        : (employee.id != 0 ? employee.id.toString() : _employeesRef.doc().id);

    final data = _employeeToFirestore(employee);
    data['created_at'] = FieldValue.serverTimestamp();

    await _employeesRef.doc(docId).set(data, SetOptions(merge: true));
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
  Future<void> deleteEmployee(int id) async {
    final snapshot =
        await _employeesRef.where('id', isEqualTo: id).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      await _employeesRef.doc(snapshot.docs.first.id).delete();
    } else {
      final doc = await _employeesRef.doc(id.toString()).get();
      if (doc.exists) {
        await _employeesRef.doc(id.toString()).delete();
      }
    }
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
  Future<Employee> submitEmployeeRegistration({
    required String linkId,
    required Employee employeeData,
  }) async {
    final batch = _firestore.batch();
    final nowIso = DateTime.now().toIso8601String();

    String newEmpId = employeeData.employeeId;
    if (newEmpId.isEmpty) {
      newEmpId = await _generateNextCandidateId();
    }

    final tempPassword = employeeData.temporaryPassword.isNotEmpty
        ? employeeData.temporaryPassword
        : _generateRandomCode(10);

    final finalEmployee = employeeData.copyWith(
      employeeId: newEmpId,
      status: employeeData.status.isEmpty ? 'Pending' : employeeData.status,
      temporaryPassword: tempPassword,
    );

    // 1. Record submission response in `employee_responses` collection
    final responseRef = _responsesRef.doc(linkId);
    batch.set(responseRef, {
      'response_id': 'resp_${responseRef.id}',
      'link_id': linkId,
      'submission_status': 'Submitted',
      'submitted_at': FieldValue.serverTimestamp(),
      'submitted_by': finalEmployee.emailAddress,
      'candidate_data': _employeeToFirestore(finalEmployee),
    }, SetOptions(merge: true));

    // 2. Update status of `registration_links` document to Completed
    final linkRef = _registrationLinksRef.doc(linkId);
    batch.set(linkRef, {
      'link_status': 'Completed',
      'submitted_date': nowIso,
      'submitted_by': finalEmployee.fullName,
      'employee_name': finalEmployee.fullName,
      'employee_id': newEmpId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Save candidate data into `employees` collection
    final empDocId = newEmpId.isNotEmpty
        ? newEmpId
        : (finalEmployee.id != 0
            ? finalEmployee.id.toString()
            : _employeesRef.doc().id);

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

