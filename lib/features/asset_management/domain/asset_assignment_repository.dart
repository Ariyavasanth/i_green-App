import 'asset_assignment.dart';

abstract interface class AssetAssignmentRepository {
  Future<List<AssetAssignment>> getAssignments();
  Future<AssetAssignment> addAssignment(AssetAssignment assignment);
  Future<void> updateAssignment(AssetAssignment assignment);
  Future<void> deleteAssignment(int id);
}
