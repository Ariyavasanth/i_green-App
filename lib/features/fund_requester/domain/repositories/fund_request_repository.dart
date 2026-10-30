import '../models/fund_request.dart';

abstract class FundRequestRepository {
  /// Stream of all active fund requests (for management/admin views and real-time lists).
  Stream<List<FundRequest>> watchAllFundRequests();

  /// Stream of fund requests for a specific employee.
  Stream<List<FundRequest>> watchFundRequestsForEmployee(String employeeId);

  /// Fetch all active fund requests.
  Future<List<FundRequest>> getAllFundRequests();

  /// Fetch fund requests for a specific employee.
  Future<List<FundRequest>> getFundRequestsForEmployee(String employeeId);

  /// Get a single fund request by ID.
  Future<FundRequest?> getFundRequestById(String id);

  /// Create a new fund request. Returns the generated document ID.
  Future<String> createFundRequest(FundRequest request);

  /// Update an existing fund request.
  Future<void> updateFundRequest(FundRequest request);

  /// Soft-delete or remove a fund request.
  Future<void> deleteFundRequest(String id);

  /// Approve a fund request with approved amount, reviewer name, and optional remarks.
  Future<void> approveFundRequest(
    String id, {
    required double approvedAmount,
    required String approvedBy,
    String? remarks,
  });

  /// Reject a fund request with reviewer name and reason.
  Future<void> rejectFundRequest(
    String id, {
    required String rejectedBy,
    required String reason,
  });
}

