import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';
import 'package:flutter_application_1/features/retention_sd/data/repositories/firebase_retention_sd_repository.dart';
import 'package:flutter_application_1/features/retention_sd/domain/models/retention_sd_record.dart';
import 'package:flutter_application_1/features/retention_sd/domain/repositories/retention_sd_repository.dart';

final retentionSdRepositoryProvider = Provider<RetentionSdRepository>((ref) {
  return FirebaseRetentionSdRepository();
});

final retentionSdRecordsStreamProvider =
    StreamProvider<List<RetentionSdRecord>>((ref) {
  final repo = ref.watch(retentionSdRepositoryProvider);
  return repo.watchRecords();
});

final retentionDivisionFilterProvider = StateProvider<String?>((ref) => null);

/// Filter options: 'All', 'Pending', 'Claim Submitted', 'Released', 'BG Expiring'
final retentionClaimStatusFilterProvider =
    StateProvider<String>((ref) => 'All');

final retentionSearchQueryProvider = StateProvider<String>((ref) => '');

class RetentionSdMetrics {
  const RetentionSdMetrics({
    this.totalRecordsCount = 0,
    this.totalRetentionAmount = 0.0,
    this.totalSdAmount = 0.0,
    this.totalOutstandingAmount = 0.0,
    this.pendingCount = 0,
    this.pendingAmount = 0.0,
    this.submittedCount = 0,
    this.submittedAmount = 0.0,
    this.releasedCount = 0,
    this.releasedAmount = 0.0,
    this.bgExpiringSoonCount = 0,
    this.bgExpiringSoonAmount = 0.0,
    this.bgExpiredCount = 0,
    this.expiringBgs = const [],
  });

  final int totalRecordsCount;
  final double totalRetentionAmount;
  final double totalSdAmount;
  final double totalOutstandingAmount;

  final int pendingCount;
  final double pendingAmount;

  final int submittedCount;
  final double submittedAmount;

  final int releasedCount;
  final double releasedAmount;

  final int bgExpiringSoonCount;
  final double bgExpiringSoonAmount;
  final int bgExpiredCount;
  final List<RetentionSdRecord> expiringBgs;
}

final retentionSdMetricsProvider = Provider<RetentionSdMetrics>((ref) {
  final records =
      ref.watch(filteredRetentionRecordsByDivisionProvider).valueOrNull ?? [];
  if (records.isEmpty) return const RetentionSdMetrics();

  double retTotal = 0.0;
  double sdTotal = 0.0;
  int pendingCnt = 0;
  double pendingAmt = 0.0;
  int submittedCnt = 0;
  double submittedAmt = 0.0;
  int releasedCnt = 0;
  double releasedAmt = 0.0;
  int bgExpiringCnt = 0;
  double bgExpiringAmt = 0.0;
  int bgExpiredCnt = 0;
  final expiringList = <RetentionSdRecord>[];

  for (final r in records) {
    retTotal += r.retentionAmount;
    sdTotal += r.sdAmount;

    switch (r.claimStatus) {
      case RetentionClaimStatus.pending:
        pendingCnt++;
        pendingAmt += r.totalFollowUpAmount;
        break;
      case RetentionClaimStatus.submitted:
        submittedCnt++;
        submittedAmt += r.totalFollowUpAmount;
        break;
      case RetentionClaimStatus.released:
        releasedCnt++;
        releasedAmt += r.releasedAmount > 0
            ? r.releasedAmount
            : r.totalFollowUpAmount;
        break;
    }

    if (r.hasBg && r.bg != null) {
      if (r.isBgExpiringSoon) {
        bgExpiringCnt++;
        bgExpiringAmt += r.bg!.bgAmount;
        expiringList.add(r);
      } else if (r.isBgExpired) {
        bgExpiredCnt++;
        expiringList.add(r);
      }
    }
  }

  return RetentionSdMetrics(
    totalRecordsCount: records.length,
    totalRetentionAmount: retTotal,
    totalSdAmount: sdTotal,
    totalOutstandingAmount: (retTotal + sdTotal) - releasedAmt,
    pendingCount: pendingCnt,
    pendingAmount: pendingAmt,
    submittedCount: submittedCnt,
    submittedAmount: submittedAmt,
    releasedCount: releasedCnt,
    releasedAmount: releasedAmt,
    bgExpiringSoonCount: bgExpiringCnt,
    bgExpiringSoonAmount: bgExpiringAmt,
    bgExpiredCount: bgExpiredCnt,
    expiringBgs: expiringList,
  );
});

final filteredRetentionRecordsByDivisionProvider =
    Provider<AsyncValue<List<RetentionSdRecord>>>((ref) {
  final recordsAsync = ref.watch(retentionSdRecordsStreamProvider);
  final division = ref.watch(retentionDivisionFilterProvider);

  return recordsAsync.whenData((records) {
    if (division == null || division == 'All') return records;
    return records
        .where((r) => r.division.trim().toLowerCase() == division.trim().toLowerCase())
        .toList();
  });
});

final filteredRetentionRecordsProvider =
    Provider<AsyncValue<List<RetentionSdRecord>>>((ref) {
  final divisionFiltered =
      ref.watch(filteredRetentionRecordsByDivisionProvider);
  final statusFilter = ref.watch(retentionClaimStatusFilterProvider);
  final query = ref.watch(retentionSearchQueryProvider).trim().toLowerCase();

  return divisionFiltered.whenData((records) {
    var result = records;

    // Filter by Claim Status / BG Expiry
    if (statusFilter == 'Pending') {
      result = result
          .where((r) => r.claimStatus == RetentionClaimStatus.pending)
          .toList();
    } else if (statusFilter == 'Claim Submitted') {
      result = result
          .where((r) => r.claimStatus == RetentionClaimStatus.submitted)
          .toList();
    } else if (statusFilter == 'Released') {
      result = result
          .where((r) => r.claimStatus == RetentionClaimStatus.released)
          .toList();
    } else if (statusFilter == 'BG Expiring') {
      result = result
          .where((r) => r.isBgExpiringSoon || r.isBgExpired)
          .toList();
    }

    // Filter by Search Query
    if (query.isNotEmpty) {
      result = result.where((r) {
        final code = r.projectCode.toLowerCase();
        final name = r.projectName.toLowerCase();
        final client = r.clientName.toLowerCase();
        final bgNo = r.bg?.bgNumber.toLowerCase() ?? '';
        final bank = r.bg?.bankName.toLowerCase() ?? '';
        final claimRef = r.claimReferenceNo.toLowerCase();
        return code.contains(query) ||
            name.contains(query) ||
            client.contains(query) ||
            bgNo.contains(query) ||
            bank.contains(query) ||
            claimRef.contains(query);
      }).toList();
    }

    return result;
  });
});
