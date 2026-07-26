import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organization/domain/column_preference.dart';
import '../data/sqlite_employee_repository.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';
import '../domain/registration_link.dart';

// Change only this line when the Firebase implementation is ready.
final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => SqliteEmployeeRepository(),
);

final employeesProvider = FutureProvider<List<Employee>>(
  (ref) => ref.watch(employeeRepositoryProvider).getEmployees(),
);

final registrationLinksProvider = FutureProvider<List<RegistrationLink>>(
  (ref) => ref.watch(employeeRepositoryProvider).getRegistrationLinks(),
);

final registrationLinkByIdProvider =
    FutureProvider.family<RegistrationLink?, String>(
  (ref, linkId) =>
      ref.watch(employeeRepositoryProvider).getRegistrationLinkById(linkId),
);

final empColumnPreferenceProvider =
    FutureProvider.family<ColumnPreference?, String>(
  (ref, tableId) =>
      ref.watch(employeeRepositoryProvider).getColumnPreference(tableId),
);

final empSearchQueryProvider = StateProvider<String>((ref) => '');
final empOrgFilterProvider = StateProvider<String>((ref) => 'All Organizations');
final empDeptFilterProvider = StateProvider<String>((ref) => 'All Departments');
final empStatusFilterProvider = StateProvider<String>((ref) => 'All Statuses');

final responseSearchQueryProvider = StateProvider<String>((ref) => '');
final responseOrgFilterProvider = StateProvider<String>((ref) => 'All Organizations');
final responseDeptFilterProvider = StateProvider<String>((ref) => 'All Departments');
final responseStatusFilterProvider = StateProvider<String>((ref) => 'All Statuses');

