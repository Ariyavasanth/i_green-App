import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/payroll.dart';
import '../domain/payroll_repository.dart';

class FirebasePayrollRepository implements PayrollRepository {
  final FirebaseFirestore _firestore;

  FirebasePayrollRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _payrollsRef =>
      _firestore.collection('payrolls');

  CollectionReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('payroll_settings');

  // Helper: map doc data to PayrollRecord
  PayrollRecord _recordFromFirestore(Map<String, dynamic> map, String docId) {
    final mutableMap = Map<String, dynamic>.from(map);
    if (!mutableMap.containsKey('id') || mutableMap['id'] == null || mutableMap['id'] == 0) {
      mutableMap['id'] = docId.hashCode & 0x7FFFFFFF;
    }
    return PayrollRecord.fromMap(mutableMap);
  }

  @override
  Future<List<PayrollRecord>> getPayrollRecordsForMonth(String month) async {
    final snap = await _payrollsRef.where('month', isEqualTo: month).get();
    return snap.docs.map((doc) => _recordFromFirestore(doc.data(), doc.id)).toList();
  }

  @override
  Future<List<PayrollRecord>> getAllPayrollRecords() async {
    final snap = await _payrollsRef.get();
    return snap.docs.map((doc) => _recordFromFirestore(doc.data(), doc.id)).toList();
  }

  @override
  Future<PayrollRecord?> getPayrollRecordById(int id) async {
    final snap = await _payrollsRef.where('id', isEqualTo: id).get();
    if (snap.docs.isEmpty) return null;
    return _recordFromFirestore(snap.docs.first.data(), snap.docs.first.id);
  }

  @override
  Future<PayrollRecord?> getPayrollRecordForEmployee(int employeeId, String month) async {
    final snap = await _payrollsRef
        .where('employee_id', isEqualTo: employeeId)
        .where('month', isEqualTo: month)
        .get();
    if (snap.docs.isEmpty) return null;
    return _recordFromFirestore(snap.docs.first.data(), snap.docs.first.id);
  }

  @override
  Future<PayrollRecord> savePayrollRecord(PayrollRecord record) async {
    final docId = '${record.employeeId}_${record.month.replaceAll(' ', '_')}';
    final map = record.toMap();
    
    // Set a hash numeric id for reference if id is 0
    final numericId = record.id != 0 ? record.id : (docId.hashCode & 0x7FFFFFFF);
    map['id'] = numericId;
    map['updated_at'] = FieldValue.serverTimestamp();

    await _payrollsRef.doc(docId).set(map, SetOptions(merge: true));
    return record.copyWith(id: numericId);
  }

  @override
  Future<void> deletePayrollRecord(int id) async {
    final snap = await _payrollsRef.where('id', isEqualTo: id).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Future<PayrollSettings> getPayrollSettings() async {
    final doc = await _settingsRef.doc('settings_1').get();
    if (!doc.exists || doc.data() == null) {
      const defaults = PayrollSettings();
      await savePayrollSettings(defaults);
      return defaults;
    }
    return PayrollSettings.fromMap(doc.data()!);
  }

  @override
  Future<void> savePayrollSettings(PayrollSettings settings) async {
    await _settingsRef.doc('settings_1').set(settings.toMap(), SetOptions(merge: true));
  }
}
