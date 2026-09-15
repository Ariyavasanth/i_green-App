import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_repository.dart';
import '../domain/on_duty_site.dart';

/// Firebase Firestore implementation for OnDutyRepository.
class FirebaseOnDutyRepository implements OnDutyRepository {
  FirebaseOnDutyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('on_duty_assignments');

  @override
  Future<List<OnDutyAssignment>> getAssignmentsForEmployee({
    required int employeeId,
    String? date,
  }) async {
    try {
      final snapshot = await _collection.get();
      final items = snapshot.docs
          .map((doc) => OnDutyAssignment.fromMap({...doc.data(), 'id': int.tryParse(doc.id) ?? doc.data()['id'] ?? 0}))
          .where((item) {
            final matchesEmp = item.employeeId == employeeId || employeeId == 0;
            final matchesDate = date == null || date.isEmpty || item.date == date;
            return matchesEmp && matchesDate;
          })
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<OnDutyAssignment>> getAllAssignments({
    String? date,
    String? statusFilter,
    int? employeeId,
  }) async {
    try {
      final snapshot = await _collection.get();
      var items = snapshot.docs
          .map((doc) => OnDutyAssignment.fromMap({...doc.data(), 'id': int.tryParse(doc.id) ?? doc.data()['id'] ?? 0}))
          .toList();

      if (date != null && date.isNotEmpty) {
        items = items.where((item) => item.date == date).toList();
      }

      if (employeeId != null && employeeId != 0) {
        items = items.where((item) => item.employeeId == employeeId).toList();
      }

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        final filterUpper = statusFilter.toUpperCase().replaceAll(' ', '_');
        items = items.where((item) {
          final s = item.status.toUpperCase();
          if (filterUpper == 'COMPLETED') {
            return s == 'COMPLETED';
          }
          if (filterUpper == 'IN_PROGRESS') {
            return item.isOngoing && s != 'ASSIGNED';
          }
          if (filterUpper == 'ACTIVE') {
            return item.isOngoing;
          }
          if (filterUpper == 'NOT_COMPLETED') {
            return s == 'NOT_COMPLETED' || s == 'CANCELLED';
          }
          return s == filterUpper;
        }).toList();
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<OnDutyAssignment?> getActiveAssignmentForEmployee(int employeeId) async {
    try {
      final snapshot = await _collection.get();

      final activeItems = snapshot.docs
          .map((doc) => OnDutyAssignment.fromMap({...doc.data(), 'id': int.tryParse(doc.id) ?? doc.data()['id'] ?? 0}))
          .where((item) {
            final matchesEmp = item.employeeId == employeeId || employeeId == 0;
            return matchesEmp && item.isOngoing;
          })
          .toList();

      if (activeItems.isEmpty) return null;

      // Prioritize active running states over assigned
      activeItems.sort((a, b) {
        int getRank(String status) {
          final s = status.toUpperCase();
          if (s == 'RETURNING_TO_OFFICE') return 1;
          if (s == 'WORK_COMPLETED') return 2;
          if (s == 'REACHED_DESTINATION') return 3;
          if (s == 'TRAVELING_TO_DESTINATION' || s == 'IN_PROGRESS' || s == 'ACTIVE') return 4;
          if (s == 'ASSIGNED') return 5;
          return 6;
        }

        final rankA = getRank(a.status);
        final rankB = getRank(b.status);
        if (rankA != rankB) return rankA.compareTo(rankB);
        return b.createdAt.compareTo(a.createdAt);
      });

      return activeItems.first;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OnDutyAssignment?> getAssignmentById(int id) async {
    try {
      final doc = await _collection.doc(id.toString()).get();
      if (doc.exists && doc.data() != null) {
        return OnDutyAssignment.fromMap({...doc.data()!, 'id': id});
      }
      final snapshot = await _collection.get();
      for (final d in snapshot.docs) {
        final item = OnDutyAssignment.fromMap({...d.data(), 'id': int.tryParse(d.id) ?? d.data()['id'] ?? 0});
        if (item.id == id) return item;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> createAssignment(OnDutyAssignment assignment) async {
    try {
      final int newId = DateTime.now().millisecondsSinceEpoch;
      final data = assignment.copyWith(id: newId).toMap();
      await _collection.doc(newId.toString()).set(data);
      return newId;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> updateAssignment(OnDutyAssignment assignment) async {
    try {
      final docData = assignment.toMap();

      if (assignment.id > 0) {
        await _collection.doc(assignment.id.toString()).set(docData, SetOptions(merge: true));
        return;
      }

      final snapshot = await _collection.get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawDocId = doc.id;
        final docIdNum = int.tryParse(rawDocId) ?? (data['id'] is int ? data['id'] : int.tryParse(data['id']?.toString() ?? '0') ?? 0);

        final matchesId = assignment.id > 0 && (docIdNum == assignment.id || rawDocId == assignment.id.toString());

        if (matchesId) {
          final targetId = assignment.id > 0 ? assignment.id : (docIdNum > 0 ? docIdNum : assignment.id);
          final mergedData = assignment.copyWith(id: targetId).toMap();
          await doc.reference.set(mergedData, SetOptions(merge: true));
          break;
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> updateAssignmentStatus({
    required int id,
    required String status,
    String? actualStartTime,
    String? actualEndTime,
    double? latitude,
    double? longitude,
    String? photoPath,
    int? durationMinutes,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.toUpperCase(),
      };
      if (actualStartTime != null) updates['actual_start_time'] = actualStartTime;
      if (actualEndTime != null) updates['actual_end_time'] = actualEndTime;
      if (status.toUpperCase() == 'IN_PROGRESS' || status.toUpperCase() == 'TRAVELING_TO_DESTINATION') {
        if (latitude != null) updates['start_latitude'] = latitude;
        if (longitude != null) updates['start_longitude'] = longitude;
        if (photoPath != null) updates['start_photo'] = photoPath;
      } else if (status.toUpperCase() == 'COMPLETED') {
        if (latitude != null) updates['end_latitude'] = latitude;
        if (longitude != null) updates['end_longitude'] = longitude;
        if (photoPath != null) updates['end_photo'] = photoPath;
      }
      if (durationMinutes != null) updates['duration_minutes'] = durationMinutes;

      await _collection.doc(id.toString()).set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> deleteAssignment(int id) async {
    try {
      await _collection.doc(id.toString()).delete();
    } catch (_) {}
  }

  @override
  Future<void> postponeAssignment({
    required int id,
    required String nextDate,
    String? notes,
  }) async {
    try {
      final assignment = await getAssignmentById(id);
      if (assignment == null) return;

      final resetSites = assignment.sites.map((s) => s.copyWith(
        status: 'PENDING',
        travelStartTime: null,
        reachedTime: null,
        reachedPhoto: null,
        workCompletedTime: null,
        workPhoto: null,
        workPhotos: [],
      )).toList();

      final postponeLog = 'Postponed to $nextDate${notes != null && notes.isNotEmpty ? ": $notes" : ""}';
      final updatedNotes = assignment.notes.isNotEmpty
          ? '${assignment.notes} | $postponeLog'
          : postponeLog;

      final updated = assignment.copyWith(
        date: nextDate,
        status: 'ASSIGNED',
        travelStartTime: null,
        reachedTime: null,
        reachedPhoto: null,
        workCompletedTime: null,
        workPhoto: null,
        workPhotos: [],
        returnStartTime: null,
        officeReachedTime: null,
        actualStartTime: null,
        actualEndTime: null,
        sites: resetSites,
        notes: updatedNotes,
      );

      await updateAssignment(updated);
    } catch (_) {}
  }

  @override
  Future<void> markAsCompleted({
    required int id,
    required String purposeDetails,
    required List<String> photos,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final assignment = await getAssignmentById(id);
      if (assignment == null) return;

      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final updatedNotes = purposeDetails.isNotEmpty
          ? (assignment.notes.isNotEmpty ? '${assignment.notes} | Details: $purposeDetails' : purposeDetails)
          : assignment.notes;

      final sitesList = List<OnDutySite>.from(assignment.effectiveSites);
      for (int i = 0; i < sitesList.length; i++) {
        sitesList[i] = sitesList[i].copyWith(
          status: 'COMPLETED',
          workCompletedTime: sitesList[i].workCompletedTime ?? nowStr,
          workPhoto: sitesList[i].workPhoto ?? (photos.isNotEmpty ? photos.first : null),
          workPhotos: sitesList[i].workPhotos.isNotEmpty ? sitesList[i].workPhotos : photos,
          workEndLatitude: sitesList[i].workEndLatitude ?? latitude,
          workEndLongitude: sitesList[i].workEndLongitude ?? longitude,
        );
      }

      final updated = assignment.copyWith(
        status: 'COMPLETED',
        actualEndTime: nowStr,
        workCompletedTime: nowStr,
        workPhoto: photos.isNotEmpty ? photos.first : null,
        workPhotos: photos,
        notes: updatedNotes,
        endLatitude: latitude ?? assignment.endLatitude,
        endLongitude: longitude ?? assignment.endLongitude,
        workEndLatitude: latitude ?? assignment.workEndLatitude,
        workEndLongitude: longitude ?? assignment.workEndLongitude,
        sites: sitesList,
      );

      await updateAssignment(updated);
    } catch (_) {}
  }

  @override
  Future<void> markAsNotCompleted({
    required int id,
    required String reason,
    required List<String> photos,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final assignment = await getAssignmentById(id);
      if (assignment == null) return;

      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final updatedNotes = reason.isNotEmpty
          ? (assignment.notes.isNotEmpty ? '${assignment.notes} | Not Completed Reason: $reason' : 'Reason: $reason')
          : assignment.notes;

      final sitesList = List<OnDutySite>.from(assignment.effectiveSites);
      if (sitesList.isNotEmpty) {
        final activeIdx = assignment.currentSiteIndex;
        if (activeIdx < sitesList.length) {
          sitesList[activeIdx] = sitesList[activeIdx].copyWith(
            status: 'NOT_COMPLETED',
            workCompletedTime: nowStr,
            workPhoto: photos.isNotEmpty ? photos.first : null,
            workPhotos: photos,
            workEndLatitude: latitude ?? sitesList[activeIdx].workEndLatitude,
            workEndLongitude: longitude ?? sitesList[activeIdx].workEndLongitude,
            notes: reason.isNotEmpty ? reason : sitesList[activeIdx].notes,
          );
        }
      }

      final updated = assignment.copyWith(
        status: 'NOT_COMPLETED',
        actualEndTime: nowStr,
        workCompletedTime: nowStr,
        workPhoto: photos.isNotEmpty ? photos.first : null,
        workPhotos: photos,
        notes: updatedNotes,
        endLatitude: latitude ?? assignment.endLatitude,
        endLongitude: longitude ?? assignment.endLongitude,
        workEndLatitude: latitude ?? assignment.workEndLatitude,
        workEndLongitude: longitude ?? assignment.workEndLongitude,
        sites: sitesList,
      );

      await updateAssignment(updated);
    } catch (_) {}
  }
}
