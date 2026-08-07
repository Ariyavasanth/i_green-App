import '../domain/incentive_repository.dart';
import '../domain/incentive_request.dart';

class FirebaseIncentiveRepository implements IncentiveRepository {
  // Empty Firebase stub for future cloud integration
  @override
  Future<List<IncentiveRequest>> getAllRequests() async {
    return [];
  }

  @override
  Future<List<IncentiveRequest>> getRequestsByEmployeeName(String employeeName) async {
    return [];
  }

  @override
  Future<IncentiveRequest?> getRequestById(int id) async {
    return null;
  }

  @override
  Future<void> createRequest(IncentiveRequest request) async {}

  @override
  Future<void> cancelRequest(int id) async {}

  @override
  Future<void> updateRequestStatus(
    int id,
    String status, {
    double? verifiedMeters,
    double? approvedAmount,
  }) async {}
}
