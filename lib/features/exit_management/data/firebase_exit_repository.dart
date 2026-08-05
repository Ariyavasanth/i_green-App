import '../domain/exit_model.dart';
import '../domain/exit_repository.dart';

class FirebaseExitRepository implements ExitRepository {
  @override
  Future<List<ExitRequest>> getAllExitRequests() async {
    return [];
  }

  @override
  Future<ExitRequest?> getExitRequestByEmployeeId(String employeeId) async {
    return null;
  }

  @override
  Future<ExitRequest?> getExitRequestById(int id) async {
    return null;
  }

  @override
  Future<int> submitExitRequest(ExitRequest request) async {
    return 0;
  }

  @override
  Future<void> updateExitRequestStatus(int id, String status) async {}

  @override
  Future<void> updateExitRequestDetails(ExitRequest request) async {}

  @override
  Future<List<DepartmentClearance>> getClearancesForExit(int exitRequestId) async {
    return [];
  }

  @override
  Future<void> saveOrUpdateClearance(DepartmentClearance clearance) async {}

  @override
  Future<ExitInterview?> getExitInterview(int exitRequestId) async {
    return null;
  }

  @override
  Future<void> submitExitInterview(ExitInterview interview) async {}

  @override
  Future<ExitSettlement?> getExitSettlement(int exitRequestId) async {
    return null;
  }

  @override
  Future<void> saveOrUpdateSettlement(ExitSettlement settlement) async {}
}
