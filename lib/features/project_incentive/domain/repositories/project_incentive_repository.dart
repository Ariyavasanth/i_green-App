import '../models/project_incentive_record.dart';
import '../models/project_incentive_settings.dart';

abstract class ProjectIncentiveRepository {
  /// Stream real-time project incentive records across all projects
  Stream<List<ProjectIncentiveRecord>> watchIncentiveRecords();

  /// Retrieve all project incentive records
  Future<List<ProjectIncentiveRecord>> getIncentiveRecords();

  /// Get specific project incentive record by project ID or code
  Future<ProjectIncentiveRecord?> getIncentiveRecordByProject(String projectCodeOrId);

  /// Save or update an incentive record
  Future<void> saveIncentiveRecord(ProjectIncentiveRecord record);

  /// Recalculate incentive for a specific project
  Future<ProjectIncentiveRecord> recalculateProjectIncentive(String projectId);

  /// Recalculate all project incentives
  Future<void> recalculateAllIncentives();

  /// Get engine configuration settings
  Future<ProjectIncentiveSettings> getSettings();

  /// Stream engine configuration settings
  Stream<ProjectIncentiveSettings> watchSettings();

  /// Update engine configuration settings
  Future<void> updateSettings(ProjectIncentiveSettings settings);

  /// Delete an incentive record
  Future<void> deleteIncentiveRecord(String id);
}
