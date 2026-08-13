import '../../incentive/data/firebase_incentive_repository.dart';
import '../../incentive/domain/incentive_request.dart';
import '../../incentive/domain/incentive_settings.dart';
import '../domain/incentive_management_repository.dart';

class FirebaseIncentiveManagementRepository implements IncentiveManagementRepository {
  FirebaseIncentiveManagementRepository({FirebaseIncentiveRepository? repository})
      : _repository = repository ?? FirebaseIncentiveRepository();

  final FirebaseIncentiveRepository _repository;

  @override
  Future<List<IncentiveRequest>> getAllRequests() async {
    return _repository.getAllRequests();
  }

  @override
  Future<List<IncentiveRequest>> getRequestsByStatus(String status) async {
    final requests = await _repository.getAllRequests();
    final normalized = status.trim().toLowerCase();
    return requests
        .where((request) =>
            request.status.trim().toLowerCase() == normalized)
        .toList();
  }

  @override
  Future<List<IncentiveRequest>> getRequestsByEmployee(int? employeeId, String employeeName) async {
    final requests = await _repository.getAllRequests();
    final normalizedName = employeeName.trim().toLowerCase();
    return requests.where((request) {
      if (employeeId != null &&
          employeeId > 0 &&
          request.employeeId != null &&
          request.employeeId! > 0) {
        return request.employeeId == employeeId;
      }
      return request.employeeName.trim().toLowerCase() == normalizedName;
    }).toList();
  }

  @override
  Future<IncentiveRequest?> getRequestById(int id) async {
    return _repository.getRequestById(id);
  }

  @override
  Future<void> approveRequest(int id, double verifiedMeters, double approvedAmount) {
    return _repository.updateRequestStatus(
      id,
      'Approved',
      verifiedMeters: verifiedMeters,
      approvedAmount: approvedAmount,
    );
  }

  @override
  Future<void> rejectRequest(int id) {
    return _repository.updateRequestStatus(id, 'Rejected');
  }

  @override
  Future<IncentiveSettings> getIncentiveSettings() async {
    return _repository.getIncentiveSettings();
  }

  @override
  Future<void> updateIncentiveSettings(IncentiveSettings settings) {
    return _repository.updateIncentiveSettings(settings);
  }
}
