import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';

abstract class FundManagementRepository {
  /// Stream of pending fund requests for real-time admin review.
  Stream<List<FundRequest>> watchPendingFundRequests();

  /// Stream of all fund requests (Pending, Approved, Partially Approved, Rejected).
  Stream<List<FundRequest>> watchAllFundRequests();

  /// Fetch all pending fund requests once.
  Future<List<FundRequest>> getPendingFundRequests();

  /// Fetch all fund requests once.
  Future<List<FundRequest>> getAllFundRequests();

  /// Look up a site project by its project code to verify actual balance.
  Future<SiteProject?> getProjectByCode(String projectCode);

  /// Approve or partially approve a fund request, deducting the approved amount
  /// from the project's actual project value.
  Future<void> approveOrPartiallyApproveRequest({
    required String requestId,
    required String projectCode,
    required double approvedAmount,
    required String approvedBy,
    String? remarks,
  });

  /// Reject a fund request with reviewer details and reason.
  Future<void> rejectRequest({
    required String requestId,
    required String rejectedBy,
    required String reason,
  });
}
