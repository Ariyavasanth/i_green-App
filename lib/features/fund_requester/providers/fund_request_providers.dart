import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/firebase_fund_request_repository.dart';
import '../domain/models/fund_request.dart';
import '../domain/repositories/fund_request_repository.dart';

/// Provider for the repository interface.
/// UI only depends on this interface provider.
final fundRequestRepositoryProvider = Provider<FundRequestRepository>((ref) {
  return FirebaseFundRequestRepository();
});

/// Real-time stream of all fund requests
final allFundRequestsStreamProvider = StreamProvider<List<FundRequest>>((ref) {
  final repo = ref.watch(fundRequestRepositoryProvider);
  return repo.watchAllFundRequests();
});

/// Stream of fund requests for a specific employee
final employeeFundRequestsStreamProvider =
    StreamProvider.family<List<FundRequest>, String>((ref, employeeId) {
  final repo = ref.watch(fundRequestRepositoryProvider);
  return repo.watchFundRequestsForEmployee(employeeId);
});

/// Search query provider
final fundRequestSearchQueryProvider = StateProvider<String>((ref) => '');

/// Status filter provider ('All', 'Pending', 'Approved', 'Rejected')
final fundRequestStatusFilterProvider = StateProvider<String>((ref) => 'All');

/// Category filter provider ('All', etc.)
final fundRequestCategoryFilterProvider = StateProvider<String>((ref) => 'All');

enum FundRequestViewMode {
  auto,
  table,
  card,
}

/// Preferred view mode on wider screens
final fundRequestViewModeProvider =
    StateProvider<FundRequestViewMode>((ref) => FundRequestViewMode.auto);

/// Filtered requests provider based on search and status
final filteredFundRequestsProvider = Provider<AsyncValue<List<FundRequest>>>((ref) {
  final asyncRequests = ref.watch(allFundRequestsStreamProvider);
  final search = ref.watch(fundRequestSearchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(fundRequestStatusFilterProvider);
  final catFilter = ref.watch(fundRequestCategoryFilterProvider);

  return asyncRequests.whenData((requests) {
    return requests.where((req) {
      if (statusFilter != 'All' &&
          req.status.toLowerCase() != statusFilter.toLowerCase()) {
        return false;
      }

      if (catFilter != 'All') {
        final hasCategory = req.items.any((item) =>
            item.category.toLowerCase() == catFilter.toLowerCase() ||
            item.subCategory.toLowerCase() == catFilter.toLowerCase());
        if (!hasCategory) return false;
      }

      if (search.isNotEmpty) {
        final matchName = req.employeeName.toLowerCase().contains(search);
        final matchMessage = req.message.toLowerCase().contains(search);
        final matchProject = req.projectCode.toLowerCase().contains(search);
        final matchNum = req.requestNumber.toLowerCase().contains(search);
        final matchItems = req.items.any((i) =>
            i.category.toLowerCase().contains(search) ||
            i.subCategory.toLowerCase().contains(search) ||
            i.comments.toLowerCase().contains(search));
        if (!matchName && !matchMessage && !matchProject && !matchNum && !matchItems) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

