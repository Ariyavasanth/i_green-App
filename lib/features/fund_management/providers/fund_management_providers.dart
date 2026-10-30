import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/fund_management/domain/repositories/fund_management_repository.dart';
import 'package:flutter_application_1/features/fund_management/data/repositories/firebase_fund_management_repository.dart';

final fundManagementRepositoryProvider =
    Provider<FundManagementRepository>((ref) {
  return FirebaseFundManagementRepository();
});

final pendingFundRequestsStreamProvider =
    StreamProvider.autoDispose<List<FundRequest>>((ref) {
  final repo = ref.watch(fundManagementRepositoryProvider);
  return repo.watchPendingFundRequests();
});

final allFundRequestsStreamProvider =
    StreamProvider.autoDispose<List<FundRequest>>((ref) {
  final repo = ref.watch(fundManagementRepositoryProvider);
  return repo.watchAllFundRequests();
});

final projectByCodeProvider =
    FutureProvider.family<SiteProject?, String>((ref, projectCode) async {
  if (projectCode.trim().isEmpty) return null;
  final repo = ref.watch(fundManagementRepositoryProvider);
  return repo.getProjectByCode(projectCode);
});
