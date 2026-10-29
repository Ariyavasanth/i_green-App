import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firebase_attendance_correction_repository.dart';
import '../domain/attendance_correction_repository.dart';
import '../domain/attendance_correction_request.dart';

final attendanceCorrectionRepositoryProvider = Provider<AttendanceCorrectionRepository>((ref) {
  return FirebaseAttendanceCorrectionRepository();
});

final pendingCorrectionRequestsProvider = StreamProvider<List<AttendanceCorrectionRequest>>((ref) {
  final repo = ref.watch(attendanceCorrectionRepositoryProvider);
  return repo.watchPendingRequests();
});

final employeeCorrectionRequestsProvider = StreamProvider.family<List<AttendanceCorrectionRequest>, int>((ref, employeeId) {
  final repo = ref.watch(attendanceCorrectionRepositoryProvider);
  return repo.watchEmployeeRequests(employeeId);
});

