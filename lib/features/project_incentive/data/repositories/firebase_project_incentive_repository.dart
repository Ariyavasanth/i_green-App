import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../projects/domain/models/daily_progress_entry.dart';
import '../../../projects/domain/models/project_compliance_record.dart';
import '../../../projects/domain/models/site_project.dart';
import '../../../projects/domain/repositories/project_repository.dart';
import '../../domain/models/project_incentive_record.dart';
import '../../domain/models/project_incentive_settings.dart';
import '../../domain/repositories/project_incentive_repository.dart';
import '../../domain/services/project_incentive_calculator.dart';

class FirebaseProjectIncentiveRepository implements ProjectIncentiveRepository {
  FirebaseProjectIncentiveRepository({
    FirebaseFirestore? firestore,
    ProjectRepository? projectRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _projectRepository = projectRepository;

  final FirebaseFirestore _firestore;
  final ProjectRepository? _projectRepository;

  CollectionReference<Map<String, dynamic>> get _recordsCollection =>
      _firestore.collection('project_incentive_records');

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _firestore.collection('app_settings').doc('project_incentive_settings');

  ProjectIncentiveRecord _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    data['id'] = doc.id;
    return ProjectIncentiveRecord.fromJson(data, doc.id);
  }

  @override
  Stream<List<ProjectIncentiveRecord>> watchIncentiveRecords() {
    return _recordsCollection.snapshots().map((snap) {
      final list = <ProjectIncentiveRecord>[];
      for (final doc in snap.docs) {
        try {
          list.add(_fromDoc(doc));
        } catch (e, st) {
          developer.log(
            'Error parsing incentive record ${doc.id}: $e',
            name: 'FirebaseProjectIncentiveRepository',
            error: e,
            stackTrace: st,
          );
        }
      }
      list.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
      return list;
    });
  }

  @override
  Future<List<ProjectIncentiveRecord>> getIncentiveRecords() async {
    final snap = await _recordsCollection.get();
    final list = <ProjectIncentiveRecord>[];
    for (final doc in snap.docs) {
      try {
        list.add(_fromDoc(doc));
      } catch (e) {
        developer.log('Error parsing doc ${doc.id}: $e');
      }
    }
    list.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
    return list;
  }

  @override
  Future<ProjectIncentiveRecord?> getIncentiveRecordByProject(String projectCodeOrId) async {
    final directDoc = await _recordsCollection.doc(projectCodeOrId).get();
    if (directDoc.exists) {
      return _fromDoc(directDoc);
    }
    // Query by project_id or project_code
    final qId = await _recordsCollection.where('project_id', isEqualTo: projectCodeOrId).limit(1).get();
    if (qId.docs.isNotEmpty) {
      return _fromDoc(qId.docs.first);
    }
    final qCode = await _recordsCollection.where('project_code', isEqualTo: projectCodeOrId).limit(1).get();
    if (qCode.docs.isNotEmpty) {
      return _fromDoc(qCode.docs.first);
    }
    return null;
  }

  @override
  Future<void> saveIncentiveRecord(ProjectIncentiveRecord record) async {
    final docId = record.id.isNotEmpty
        ? record.id
        : (record.projectId.isNotEmpty ? 'inc_${record.projectId}' : 'inc_${record.projectCode}');
    await _recordsCollection.doc(docId).set(record.toJson(), SetOptions(merge: true));
  }

  @override
  Future<ProjectIncentiveRecord> recalculateProjectIncentive(String projectId) async {
    final settings = await getSettings();

    SiteProject? project;
    List<DailyProgressEntry> dailyEntries = [];
    List<IncidentLogEntry> incidents = [];

    if (_projectRepository != null) {
      project = await _projectRepository.getProjectById(projectId);
      if (project != null) {
        // Fetch daily progress
        try {
          final progressList = await _projectRepository.watchDailyProgress(project.projectCode).first;
          dailyEntries = progressList;
        } catch (_) {}

        // Fetch incidents
        try {
          final incidentList = await _projectRepository.watchIncidents(project.projectCode).first;
          incidents = incidentList;
        } catch (_) {}
      }
    }

    if (project == null) {
      // Fallback: try fetching from direct firestore project doc
      final pDoc = await _firestore.collection('site_projects').doc(projectId).get();
      if (pDoc.exists) {
        final p = SiteProject.fromJson(pDoc.data() ?? {}, docId: pDoc.id);
        project = p;
        // Fetch incidents
        final incSnap = await _firestore
            .collection('project_incidents')
            .where('project_code', isEqualTo: p.projectCode)
            .get();
        incidents = incSnap.docs.map((d) => IncidentLogEntry.fromJson(d.data(), d.id)).toList();

        // Fetch daily progress
        final dpSnap = await _firestore
            .collection('project_daily_progress')
            .where('project_code', isEqualTo: p.projectCode)
            .get();
        dailyEntries = dpSnap.docs.map((d) => DailyProgressEntry.fromJson(d.data(), d.id)).toList();
      }
    }

    if (project == null) {
      throw Exception('Project not found for ID: $projectId');
    }

    final calculated = ProjectIncentiveCalculator.calculate(
      project: project,
      dailyProgressEntries: dailyEntries,
      incidents: incidents,
      settings: settings,
    );

    await saveIncentiveRecord(calculated);
    return calculated;
  }

  @override
  Future<void> recalculateAllIncentives() async {
    final settings = await getSettings();
    List<SiteProject> projects = [];

    if (_projectRepository != null) {
      projects = await _projectRepository.getProjects();
    } else {
      final snap = await _firestore.collection('site_projects').get();
      projects = snap.docs.map((d) => SiteProject.fromJson(d.data(), docId: d.id)).toList();
    }

    for (final p in projects) {
      try {
        List<DailyProgressEntry> dailyEntries = [];
        List<IncidentLogEntry> incidents = [];

        if (_projectRepository != null) {
          try {
            dailyEntries = await _projectRepository.watchDailyProgress(p.projectCode).first;
          } catch (_) {}
          try {
            incidents = await _projectRepository.watchIncidents(p.projectCode).first;
          } catch (_) {}
        } else {
          final incSnap = await _firestore
              .collection('project_incidents')
              .where('project_code', isEqualTo: p.projectCode)
              .get();
          incidents = incSnap.docs.map((d) => IncidentLogEntry.fromJson(d.data(), d.id)).toList();

          final dpSnap = await _firestore
              .collection('project_daily_progress')
              .where('project_code', isEqualTo: p.projectCode)
              .get();
          dailyEntries = dpSnap.docs.map((d) => DailyProgressEntry.fromJson(d.data(), d.id)).toList();
        }

        final calculated = ProjectIncentiveCalculator.calculate(
          project: p,
          dailyProgressEntries: dailyEntries,
          incidents: incidents,
          settings: settings,
        );

        await saveIncentiveRecord(calculated);
      } catch (e) {
        developer.log('Error calculating incentive for ${p.projectCode}: $e');
      }
    }
  }

  @override
  Future<ProjectIncentiveSettings> getSettings() async {
    try {
      final doc = await _settingsDoc.get();
      if (doc.exists && doc.data() != null) {
        return ProjectIncentiveSettings.fromJson(doc.data()!);
      }
    } catch (e) {
      developer.log('Error fetching incentive settings: $e');
    }
    return const ProjectIncentiveSettings();
  }

  @override
  Stream<ProjectIncentiveSettings> watchSettings() {
    return _settingsDoc.snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        try {
          return ProjectIncentiveSettings.fromJson(doc.data()!);
        } catch (_) {}
      }
      return const ProjectIncentiveSettings();
    });
  }

  @override
  Future<void> updateSettings(ProjectIncentiveSettings settings) async {
    await _settingsDoc.set(settings.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteIncentiveRecord(String id) async {
    await _recordsCollection.doc(id).delete();
  }
}
