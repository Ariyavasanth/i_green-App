import '../../incentive/domain/incentive_request.dart';
import '../domain/incentive_management_repository.dart';

class FirebaseIncentiveManagementRepository implements IncentiveManagementRepository {
  // Empty Firebase stub for future cloud integration
  @override
  Future<List<IncentiveRequest>> getAllRequests() async {
    return [];
  }

  @override
  Future<List<IncentiveRequest>> getRequestsByStatus(String status) async {
    return [];
  }

  @override
  Future<void> approveRequest(int id, double verifiedMeters, double approvedAmount) async {}

  @override
  Future<void> rejectRequest(int id) async {}
}
