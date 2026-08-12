import '../../incentive/data/sqlite_incentive_repository.dart';
import '../../incentive/domain/incentive_request.dart';
import '../../incentive/domain/incentive_settings.dart';
import '../domain/incentive_management_repository.dart';

class SqliteIncentiveManagementRepository implements IncentiveManagementRepository {
  final SqliteIncentiveRepository _baseRepo = SqliteIncentiveRepository();

  @override
  Future<List<IncentiveRequest>> getAllRequests() async {
    return await _baseRepo.getAllRequests();
  }

  @override
  Future<List<IncentiveRequest>> getRequestsByStatus(String status) async {
    final all = await _baseRepo.getAllRequests();
    return all.where((r) => r.status.trim().toLowerCase() == status.trim().toLowerCase()).toList();
  }

  @override
  Future<List<IncentiveRequest>> getRequestsByEmployee(int? employeeId, String employeeName) async {
    final all = await _baseRepo.getAllRequests();
    final cleanName = employeeName.trim().toLowerCase();
    return all.where((r) {
      if (employeeId != null && employeeId > 0 && r.employeeId != null && r.employeeId! > 0) {
        return r.employeeId == employeeId;
      }
      return r.employeeName.trim().toLowerCase() == cleanName;
    }).toList();
  }

  @override
  Future<IncentiveRequest?> getRequestById(int id) async {
    return await _baseRepo.getRequestById(id);
  }

  @override
  Future<void> approveRequest(int id, double verifiedMeters, double approvedAmount) async {
    await _baseRepo.updateRequestStatus(
      id,
      'Approved',
      verifiedMeters: verifiedMeters,
      approvedAmount: approvedAmount,
    );
  }

  @override
  Future<void> rejectRequest(int id) async {
    await _baseRepo.updateRequestStatus(id, 'Rejected');
  }

  @override
  Future<IncentiveSettings> getIncentiveSettings() async {
    return await _baseRepo.getIncentiveSettings();
  }

  @override
  Future<void> updateIncentiveSettings(IncentiveSettings settings) async {
    await _baseRepo.updateIncentiveSettings(settings);
  }
}
