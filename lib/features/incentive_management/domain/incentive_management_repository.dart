import '../../incentive/domain/incentive_request.dart';
import '../../incentive/domain/incentive_settings.dart';

abstract class IncentiveManagementRepository {
  Future<List<IncentiveRequest>> getAllRequests();
  Future<List<IncentiveRequest>> getRequestsByStatus(String status);
  Future<void> approveRequest(int id, double verifiedMeters, double approvedAmount);
  Future<void> rejectRequest(int id);
  Future<IncentiveSettings> getIncentiveSettings();
  Future<void> updateIncentiveSettings(IncentiveSettings settings);
}
