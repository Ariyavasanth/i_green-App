import 'incentive_payout_ledger.dart';
import 'incentive_request.dart';
import 'incentive_settings.dart';

abstract class IncentiveRepository {
  Future<List<IncentiveRequest>> getAllRequests();
  Stream<List<IncentiveRequest>> watchAllRequests();
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
  Future<List<IncentiveRequest>> getApprovedRequestsForEmployee({
    int? employeeId,
    String? employeeName,
    String? employeeCode,
    DateTime? startDate,
    DateTime? endDateExclusive,
  });

  // 3-Table Payout & Deferred Ledger Operations
  Future<List<IncentivePayoutLedger>> getPayoutLedgersForEmployee(int employeeId);
  Future<List<IncentivePayoutLedger>> getAllPayoutLedgers();
  Stream<List<IncentivePayoutLedger>> watchPayoutLedgersForEmployee(int employeeId);
  Future<void> savePayoutLedger(IncentivePayoutLedger ledger);
  Future<void> markPayoutLedgersReleased({
    required List<String> ledgerIds,
    required String releaseCycle,
    required DateTime releasedAt,
    int? payrollRecordId,
  });
}

