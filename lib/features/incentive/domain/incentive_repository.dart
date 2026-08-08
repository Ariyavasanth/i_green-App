import 'incentive_request.dart';
import 'incentive_settings.dart';

abstract class IncentiveRepository {
  Future<List<IncentiveRequest>> getAllRequests();
  Future<List<IncentiveRequest>> getRequestsByEmployeeName(String employeeName);
  Future<IncentiveRequest?> getRequestById(int id);
  Future<void> createRequest(IncentiveRequest request);
  Future<void> cancelRequest(int id);
  Future<void> updateRequest(IncentiveRequest request);
  Future<void> updateRequestStatus(
    int id,
    String status, {
    double? verifiedMeters,
    double? approvedAmount,
  });
  Future<IncentiveSettings> getIncentiveSettings();
  Future<void> updateIncentiveSettings(IncentiveSettings settings);
}
