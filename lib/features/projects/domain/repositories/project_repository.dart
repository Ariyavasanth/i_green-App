import 'package:file_picker/file_picker.dart';

import '../models/project_audit_log.dart';
import '../models/site_project.dart';

abstract class ProjectRepository {
  /// Creates a new site project, uploads attached files (if any), and saves to database.
  Future<SiteProject> createProject(
    SiteProject project, {
    Map<String, List<PlatformFile>>? filesByCategory,
  });

  /// Retrieves all site projects.
  Future<List<SiteProject>> getProjects();

  /// Real-time stream of all site projects.
  Stream<List<SiteProject>> watchProjects();

  /// Retrieves a specific site project by its ID.
  Future<SiteProject?> getProjectById(String id);

  /// Updates an existing site project, uploading newly attached files (if any),
  /// and automatically records an audit log entry if audit details are provided.
  Future<void> updateProject(
    SiteProject project, {
    Map<String, List<PlatformFile>>? filesByCategory,
    String? auditNote,
    String? auditEmployeeId,
    String? auditEmployeeName,
    String? auditDesignation,
  });

  /// Deletes a site project by its ID.
  Future<void> deleteProject(String id);

  /// Retrieves the list of available tender types.
  Future<List<String>> getTenderTypes();

  /// Retrieves the next project sequence number for code generation.
  Future<int> getNextProjectSequence();

  /// Retrieves the full audit history for a given project.
  Future<List<ProjectAuditLog>> getProjectAuditLogs(String projectId);

  /// Records an audit log entry for a project.
  Future<void> addAuditLog(ProjectAuditLog log);
}
