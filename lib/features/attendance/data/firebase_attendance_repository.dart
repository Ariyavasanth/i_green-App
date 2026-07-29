import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/attendance_record.dart';
import '../domain/attendance_repository.dart';

class FirebaseAttendanceRepository implements AttendanceRepository {
  final FirebaseFirestore _firestore;

  FirebaseAttendanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _recordsRef =>
      _firestore.collection('attendance_records');

  AttendanceRecord _recordFromDoc(Map<String, dynamic> data, String docId) {
    final mutable = Map<String, dynamic>.from(data);
    if (!mutable.containsKey('id') || mutable['id'] == null || mutable['id'] == 0) {
      final parsed = int.tryParse(docId.replaceAll(RegExp(r'\D'), ''));
      mutable['id'] = (parsed != null && parsed != 0)
          ? parsed
          : (docId.hashCode & 0x7FFFFFFF);
    }
    return AttendanceRecord.fromMap(mutable);
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId) async {
    final snap = await _recordsRef
        .where('employee_id', isEqualTo: employeeId)
        .get();
    final list = snap.docs.map((d) => _recordFromDoc(d.data(), d.id)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<void> markAttendance(int employeeId, String date) async {
    final docId = '${employeeId}_${date.replaceAll('-', '')}';
    await _recordsRef.doc(docId).set({
      'employee_id': employeeId,
      'date': date,
      'status': 'Present',
      'marked_at': DateTime.now().toIso8601String(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
