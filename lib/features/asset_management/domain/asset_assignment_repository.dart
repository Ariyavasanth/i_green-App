import 'asset_assignment.dart';
import 'asset_transfer_request.dart';

abstract interface class AssetAssignmentRepository {
  Future<List<AssetAssignment>> getAssignments();
  Future<AssetAssignment> addAssignment(AssetAssignment assignment);
  Future<void> addAssignments(List<AssetAssignment> assignments);
  Future<void> updateAssignment(AssetAssignment assignment);
  Future<void> deleteAssignment(int id);
  Future<List<AssetTransferRequest>> getTransferRequests();
  Future<AssetTransferRequest> createTransferRequest(AssetTransferRequest request);
  Future<void> respondToTransferRequest(AssetTransferRequest request, {required bool approve});
}
