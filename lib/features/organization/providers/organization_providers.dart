import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sqlite_organization_repository.dart';
import '../domain/column_preference.dart';
import '../domain/department.dart';
import '../domain/organization.dart';
import '../domain/organization_repository.dart';

// Change only this line when the Firebase implementation is ready.
final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => SqliteOrganizationRepository(),
);

final organizationsProvider = FutureProvider<List<Organization>>(
  (ref) => ref.watch(organizationRepositoryProvider).getOrganizations(),
);

final departmentsProvider = FutureProvider<List<Department>>(
  (ref) => ref.watch(organizationRepositoryProvider).getDepartments(),
);

final columnPreferenceProvider =
    FutureProvider.family<ColumnPreference?, String>(
  (ref, tableId) =>
      ref.watch(organizationRepositoryProvider).getColumnPreference(tableId),
);

final orgSearchQueryProvider = StateProvider<String>((ref) => '');
final deptSearchQueryProvider = StateProvider<String>((ref) => '');
