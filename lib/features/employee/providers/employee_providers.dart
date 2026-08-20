import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organization/domain/column_preference.dart';
import '../data/firebase_employee_repository.dart';
import '../domain/candidate_response.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';
import '../domain/registration_link.dart';

final candidateResponsesProvider = FutureProvider<List<CandidateResponse>>(
  (ref) => ref.watch(employeeRepositoryProvider).getCandidateResponses(),
);

final candidateResponseByLinkIdProvider =
    FutureProvider.family<CandidateResponse?, String>(
  (ref, linkId) => ref.watch(employeeRepositoryProvider).getCandidateResponseByLinkId(linkId),
);

final candidateResponseByCandidateIdProvider =
    FutureProvider.family<CandidateResponse?, String>(
  (ref, candidateId) => ref.watch(employeeRepositoryProvider).getCandidateResponseByCandidateId(candidateId),
);

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => FirebaseEmployeeRepository(),
);

final employeesProvider = FutureProvider<List<Employee>>(
  (ref) async {
    final employees = await ref.watch(employeeRepositoryProvider).getEmployees();
    final uniqueEmployees = <Employee>[];
    final seenIds = <int>{};
    for (final emp in employees) {
      if (seenIds.add(emp.id)) {
        uniqueEmployees.add(emp);
      }
    }
    return uniqueEmployees;
  },
);

final allEmployeesProvider = FutureProvider<List<Employee>>(
  (ref) async {
    final employees = await ref.watch(employeeRepositoryProvider).getAllEmployees();
    final uniqueEmployees = <Employee>[];
    final seenIds = <int>{};
    for (final emp in employees) {
      if (seenIds.add(emp.id)) {
        uniqueEmployees.add(emp);
      }
    }
    return uniqueEmployees;
  },
);

final registrationLinksProvider = FutureProvider<List<RegistrationLink>>(
  (ref) => ref.watch(employeeRepositoryProvider).getRegistrationLinks(),
);

final registrationLinkByIdProvider =
    FutureProvider.family<RegistrationLink?, String>(
  (ref, linkId) async {
    if (linkId == 'new' || linkId == 'edit' || linkId.isEmpty) {
      return const RegistrationLink(
        id: 0,
        linkId: 'new',
        generatedBy: 'Admin',
        generatedDate: '',
        expiryDate: '',
        linkStatus: 'Pending',
        organizationName: 'iGreen Tech',
        department: 'Management',
      );
    }
    try {
      final link = await ref.watch(employeeRepositoryProvider).getRegistrationLinkById(linkId);
      if (link != null) return link;
    } catch (_) {}
    return const RegistrationLink(
      id: 0,
      linkId: 'new',
      generatedBy: 'Admin',
      generatedDate: '',
      expiryDate: '',
      linkStatus: 'Pending',
      organizationName: 'iGreen Tech',
      department: 'Management',
    );
  },
);

final empColumnPreferenceProvider =
    FutureProvider.family<ColumnPreference?, String>(
  (ref, tableId) =>
      ref.watch(employeeRepositoryProvider).getColumnPreference(tableId),
);

final empSearchQueryProvider = StateProvider<String>((ref) => '');
final empOrgFilterProvider = StateProvider<String>((ref) => 'All Organizations');
final empDeptFilterProvider = StateProvider<String>((ref) => 'All Departments');
final empDesigFilterProvider = StateProvider<String>((ref) => 'All Designations');
final empStatusFilterProvider = StateProvider<String>((ref) => 'All Statuses');

final responseSearchQueryProvider = StateProvider<String>((ref) => '');
final responseOrgFilterProvider = StateProvider<String>((ref) => 'All Organizations');
final responseDeptFilterProvider = StateProvider<String>((ref) => 'All Departments');
final responseStatusFilterProvider = StateProvider<String>((ref) => 'All Statuses');
final responseDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);
