import 'exit_model.dart';

abstract class ExitRepository {
  Future<List<ExitRequest>> getAllExitRequests();
  Future<ExitRequest?> getExitRequestByEmployeeId(String employeeId);
  Future<ExitRequest?> getExitRequestById(int id);
  Future<int> submitExitRequest(ExitRequest request);
  Future<void> updateExitRequestStatus(int id, String status);
  Future<void> updateExitRequestDetails(ExitRequest request);

  Future<List<DepartmentClearance>> getClearancesForExit(int exitRequestId);
  Future<void> saveOrUpdateClearance(DepartmentClearance clearance);

  Future<ExitInterview?> getExitInterview(int exitRequestId);
  Future<void> submitExitInterview(ExitInterview interview);

  Future<ExitSettlement?> getExitSettlement(int exitRequestId);
  Future<void> saveOrUpdateSettlement(ExitSettlement settlement);
}
