import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/authentication_providers.dart';
import '../../organization/domain/column_preference.dart';
import '../data/firebase_employee_repository.dart';
import '../domain/candidate_response.dart';
import '../domain/correction_request.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';
import '../domain/registration_link.dart';

final currentEmployeeStreamProvider = StreamProvider<Employee?>((ref) {
  final emailOrId = ref.watch(currentUserEmailProvider);
  if (emailOrId == null || emailOrId.trim().isEmpty) {
    return Stream.value(null);
  }
  return ref.watch(employeeRepositoryProvider).watchEmployee(emailOrId.trim());
});

final currentEmployeeProvider = Provider<Employee?>((ref) {
  final streamedAsync = ref.watch(currentEmployeeStreamProvider);
  final streamedEmployee = streamedAsync.asData?.value;
  if (streamedEmployee != null) {
    return streamedEmployee;
  }
  final emailOrId = ref.watch(currentUserEmailProvider);
  if (emailOrId == null || emailOrId.trim().isEmpty) {
    return null;
  }
  final target = emailOrId.trim().toLowerCase();
  final employeesAsync = ref.watch(employeesProvider);
  return employeesAsync.maybeWhen(
    data: (list) {
      final matches = list.where((e) {
        return e.emailAddress.trim().toLowerCase() == target ||
            e.employeeId.trim().toLowerCase() == target ||
            e.id.toString() == target ||
            e.fullName.trim().toLowerCase() == target ||
            e.firstName.trim().toLowerCase() == target ||
            ((target == 'admin' || target == 'superadmin' || target == 'super admin') && e.isSuperAdmin);
      }).toList();
      if (matches.isNotEmpty) return matches.first;

      if (target == 'admin' || target == 'superadmin' || target == 'super admin' || target == 'admin@company.com') {
        final adminMatch = list.where((e) => e.isSuperAdmin).firstOrNull;
        if (adminMatch != null) return adminMatch;
        return FirebaseEmployeeRepository.superAdminMotherAccount;
      }

      return null;
    },
    orElse: () {
      if (target == 'admin' || target == 'superadmin' || target == 'super admin' || target == 'admin@company.com') {
        return FirebaseEmployeeRepository.superAdminMotherAccount;
      }
      return null;
    },
  );
});

final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentEmployeeProvider)?.isSuperAdmin ?? false;
});

final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  return ref.watch(currentEmployeeProvider)?.hasPermission(permission) ?? false;
});

final candidateResponsesProvider = FutureProvider<List<CandidateResponse>>(
  (ref) => ref.watch(employeeRepositoryProvider).getCandidateResponses(),
);

final candidateResponseByLinkIdProvider =
    FutureProvider.family<CandidateResponse?, String>(
      (ref, linkId) => ref
          .watch(employeeRepositoryProvider)
          .getCandidateResponseByLinkId(linkId),
    );

final candidateResponseByCandidateIdProvider =
    FutureProvider.family<CandidateResponse?, String>(
      (ref, candidateId) => ref
          .watch(employeeRepositoryProvider)
          .getCandidateResponseByCandidateId(candidateId),
    );

final correctionRequestsForCandidateProvider =
    FutureProvider.family<List<CorrectionRequest>, String>(
      (ref, candidateId) => ref
          .watch(employeeRepositoryProvider)
          .getCorrectionRequestsForCandidate(candidateId),
    );

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => FirebaseEmployeeRepository(),
);

final employeesProvider = FutureProvider<List<Employee>>((ref) async {
  final employees = await ref.watch(employeeRepositoryProvider).getEmployees();
  final uniqueEmployees = <Employee>[];
  final seenKeys = <String>{};

  final hasDynamicPrefix = <String>{};
  for (final emp in employees) {
    if (!emp.employeeId.startsWith('EMP-') && !emp.employeeId.startsWith('CAN-')) {
      if (emp.emailAddress.trim().isNotEmpty) {
        hasDynamicPrefix.add(emp.emailAddress.trim().toLowerCase());
      }
      if (emp.id > 0) {
        hasDynamicPrefix.add('id_${emp.id}');
      }
    }
  }

  for (final emp in employees) {
    if (emp.emailAddress.toLowerCase() == 'rahul.sharma@igreen.com' ||
        emp.employeeId == 'EMP-1001') {
      continue;
    }
    final emailKey = emp.emailAddress.trim().toLowerCase();
    final idKey = 'id_${emp.id}';
    final isDuplicateEmpDoc = emp.employeeId.startsWith('EMP-') &&
        ((emailKey.isNotEmpty && hasDynamicPrefix.contains(emailKey)) ||
         (emp.id > 0 && hasDynamicPrefix.contains(idKey)));
    if (isDuplicateEmpDoc) continue;

    final key = emp.employeeId.trim().isNotEmpty
        ? emp.employeeId.trim().toUpperCase()
        : '${emp.id}_$emailKey';
    if (!emp.employeeId.startsWith('CAN-') &&
        emp.status.toLowerCase() != 'draft' &&
        seenKeys.add(key)) {
      uniqueEmployees.add(emp);
    }
  }
  uniqueEmployees.sort((a, b) {
    final numA = int.tryParse(a.employeeId.replaceAll(RegExp(r'[^0-9]'), '')) ?? a.id;
    final numB = int.tryParse(b.employeeId.replaceAll(RegExp(r'[^0-9]'), '')) ?? b.id;
    if (numA != numB) return numA.compareTo(numB);
    return a.employeeId.compareTo(b.employeeId);
  });
  return uniqueEmployees;
});

final allEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  final employees = await ref
      .watch(employeeRepositoryProvider)
      .getAllEmployees();
  final uniqueEmployees = <Employee>[];
  final seenKeys = <String>{};

  final hasDynamicPrefix = <String>{};
  for (final emp in employees) {
    if (!emp.employeeId.startsWith('EMP-') && !emp.employeeId.startsWith('CAN-')) {
      if (emp.emailAddress.trim().isNotEmpty) {
        hasDynamicPrefix.add(emp.emailAddress.trim().toLowerCase());
      }
      if (emp.id > 0) {
        hasDynamicPrefix.add('id_${emp.id}');
      }
    }
  }

  for (final emp in employees) {
    if (emp.emailAddress.toLowerCase() == 'rahul.sharma@igreen.com' ||
        emp.employeeId == 'EMP-1001') {
      continue;
    }
    final emailKey = emp.emailAddress.trim().toLowerCase();
    final idKey = 'id_${emp.id}';
    final isDuplicateEmpDoc = emp.employeeId.startsWith('EMP-') &&
        ((emailKey.isNotEmpty && hasDynamicPrefix.contains(emailKey)) ||
         (emp.id > 0 && hasDynamicPrefix.contains(idKey)));
    if (isDuplicateEmpDoc) continue;

    final key = emp.employeeId.trim().isNotEmpty
        ? emp.employeeId.trim().toUpperCase()
        : '${emp.id}_$emailKey';
    if (!emp.employeeId.startsWith('CAN-') &&
        emp.status.toLowerCase() != 'draft' &&
        seenKeys.add(key)) {
      uniqueEmployees.add(emp);
    }
  }
  uniqueEmployees.sort((a, b) {
    final numA = int.tryParse(a.employeeId.replaceAll(RegExp(r'[^0-9]'), '')) ?? a.id;
    final numB = int.tryParse(b.employeeId.replaceAll(RegExp(r'[^0-9]'), '')) ?? b.id;
    if (numA != numB) return numA.compareTo(numB);
    return a.employeeId.compareTo(b.employeeId);
  });
  return uniqueEmployees;
});

final activeResponsesProvider = FutureProvider<List<RegistrationLink>>((
  ref,
) async {
  final repo = ref.watch(employeeRepositoryProvider);
  final links = await repo.getRegistrationLinks();
  return links.where((link) {
    final status = link.linkStatus.trim().toLowerCase();
    return status != 'registered' && status != 'converted';
  }).toList();
});

final registrationLinksProvider = FutureProvider<List<RegistrationLink>>(
  (ref) => ref.watch(employeeRepositoryProvider).getRegistrationLinks(),
);

final registrationLinkByIdProvider =
    FutureProvider.family<RegistrationLink?, String>((ref, linkId) async {
      if (linkId == 'new' || linkId == 'edit' || linkId.isEmpty) {
        return const RegistrationLink(
          id: 0,
          linkId: 'new',
          generatedBy: 'Admin',
          generatedDate: '',
          expiryDate: '',
          linkStatus: 'Pending',
          organizationName: '',
          department: 'Management',
        );
      }
      try {
        final link = await ref
            .watch(employeeRepositoryProvider)
            .getRegistrationLinkById(linkId);
        if (link != null) return link;
      } catch (_) {}
      return const RegistrationLink(
        id: 0,
        linkId: 'new',
        generatedBy: 'Admin',
        generatedDate: '',
        expiryDate: '',
        linkStatus: 'Pending',
        organizationName: '',
        department: 'Management',
      );
    });

final empColumnPreferenceProvider =
    FutureProvider.family<ColumnPreference?, String>(
      (ref, tableId) =>
          ref.watch(employeeRepositoryProvider).getColumnPreference(tableId),
    );

final empSearchQueryProvider = StateProvider<String>((ref) => '');
final empOrgFilterProvider = StateProvider<String>(
  (ref) => 'All Organizations',
);
final empDeptFilterProvider = StateProvider<String>((ref) => 'All Departments');
final empDesigFilterProvider = StateProvider<String>(
  (ref) => 'All Designations',
);
final empStatusFilterProvider = StateProvider<String>((ref) => 'All Statuses');

final responseSearchQueryProvider = StateProvider<String>((ref) => '');
final responseOrgFilterProvider = StateProvider<String>(
  (ref) => 'All Organizations',
);
final responseDeptFilterProvider = StateProvider<String>(
  (ref) => 'All Departments',
);
final responseStatusFilterProvider = StateProvider<String>(
  (ref) => 'All Statuses',
);
final responseDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);
