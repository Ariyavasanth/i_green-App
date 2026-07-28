import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sqlite_leave_repository.dart';
import '../domain/leave_repository.dart';
import '../domain/leave_request.dart';

/// Swap to FirebaseLeaveRepository() to switch backends — no screen changes needed.
final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => SqliteLeaveRepository(),
);

final leaveRequestsProvider = FutureProvider.family<List<LeaveRequest>, int>(
  (ref, employeeId) => ref.watch(leaveRepositoryProvider).getLeaveRequests(employeeId),
);
