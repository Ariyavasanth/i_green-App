import 'attendance_correction_request.dart';

abstract class AttendanceCorrectionRepository {
  Future<void> submitRequest(AttendanceCorrectionRequest request);
  Stream<List<AttendanceCorrectionRequest>> watchPendingRequests();
  Stream<List<AttendanceCorrectionRequest>> watchEmployeeRequests(int employeeId);
  Future<void> approveAndReopenShift({
    required AttendanceCorrectionRequest request,
    required String resumedCheckInTime,
    String? finalCheckOutTime,
    String? adminComment,
    String? reviewedBy,
  });
  Future<void> rejectRequest({
    required String requestId,
    required String reason,
    String? reviewedBy,
  });
}

