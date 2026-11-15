import 'package:file_picker/file_picker.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/retention_sd/domain/models/retention_sd_record.dart';

abstract class RetentionSdRepository {
  /// Real-time stream of all Retention cum SD follow-up records.
  Stream<List<RetentionSdRecord>> watchRecords();

  /// Retrieves all records once.
  Future<List<RetentionSdRecord>> getRecords();

  /// Retrieves a specific follow-up record by its document ID.
  Future<RetentionSdRecord?> getRecordById(String id);

  /// Retrieves a specific follow-up record linked to a project ID.
  Future<RetentionSdRecord?> getRecordByProjectId(String projectId);

  /// Saves or creates a follow-up record, optionally uploading attached claim / BG files.
  Future<void> saveRecord(
    RetentionSdRecord record, {
    List<PlatformFile>? claimFiles,
    List<PlatformFile>? bgFiles,
  });

  /// Updates the claim lifecycle status (Pending -> Claim Submitted -> Released)
  /// with submission details, release details, remarks, and attached documentation.
  Future<void> updateClaimStatus({
    required String recordId,
    required RetentionClaimStatus status,
    DateTime? submissionDate,
    String? referenceNo,
    DateTime? releasedDate,
    double? releasedAmount,
    String? remarks,
    List<PlatformFile>? documents,
    String? updatedBy,
  });

  /// Updates or registers Bank Guarantee (BG) details for a project record.
  Future<void> updateBgDetails({
    required String recordId,
    required BankGuaranteeDetail bg,
    List<PlatformFile>? documents,
    String? updatedBy,
  });

  /// Deletes a follow-up record.
  Future<void> deleteRecord(String id);

  /// Synchronizes existing site projects that have retention or SD amounts/agreements
  /// into the centralized retention_sd_followups collection, ensuring zero manual re-entry.
  Future<void> syncWithSiteProjects(List<SiteProject> projects);
}
