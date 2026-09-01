import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_organization_repository.dart';
import '../domain/business_unit.dart';
import '../domain/column_preference.dart';
import '../domain/department.dart';
import '../domain/designation.dart';
import '../domain/location.dart';
import '../domain/organization.dart';
import '../domain/organization_repository.dart';

// Firestore implementation active.
final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => FirebaseOrganizationRepository(),
);

final organizationsProvider = FutureProvider<List<Organization>>(
  (ref) => ref.watch(organizationRepositoryProvider).getOrganizations(),
);

final businessUnitsProvider = FutureProvider.family<List<BusinessUnit>, String?>(
  (ref, orgName) => ref.watch(organizationRepositoryProvider).getBusinessUnits(organizationName: orgName),
);

class LocationFilter {
  final String? organizationName;
  final String? businessUnitName;
  const LocationFilter({this.organizationName, this.businessUnitName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationFilter &&
          runtimeType == other.runtimeType &&
          organizationName == other.organizationName &&
          businessUnitName == other.businessUnitName;

  @override
  int get hashCode => organizationName.hashCode ^ businessUnitName.hashCode;
}

final locationsProvider = FutureProvider.family<List<Location>, LocationFilter>(
  (ref, filter) => ref.watch(organizationRepositoryProvider).getLocations(
        organizationName: filter.organizationName,
        businessUnitName: filter.businessUnitName,
      ),
);

class DepartmentFilter {
  final String? organizationName;
  final String? businessUnitName;
  final String? workLocation;
  const DepartmentFilter({this.organizationName, this.businessUnitName, this.workLocation});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepartmentFilter &&
          runtimeType == other.runtimeType &&
          organizationName == other.organizationName &&
          businessUnitName == other.businessUnitName &&
          workLocation == other.workLocation;

  @override
  int get hashCode => organizationName.hashCode ^ businessUnitName.hashCode ^ workLocation.hashCode;
}

final departmentsProvider = FutureProvider<List<Department>>(
  (ref) => ref.watch(organizationRepositoryProvider).getDepartments(),
);

final filteredDepartmentsProvider = FutureProvider.family<List<Department>, DepartmentFilter>(
  (ref, filter) => ref.watch(organizationRepositoryProvider).getDepartments(
        organizationName: filter.organizationName,
        businessUnitName: filter.businessUnitName,
        workLocation: filter.workLocation,
      ),
);

final designationsProvider = FutureProvider.family<List<Designation>, String?>(
  (ref, deptName) => ref.watch(organizationRepositoryProvider).getDesignations(departmentName: deptName),
);

final allDesignationsProvider = FutureProvider<List<Designation>>(
  (ref) => ref.watch(organizationRepositoryProvider).getDesignations(),
);

class DesignationFilter {
  final String? organizationName;
  final String? departmentName;
  const DesignationFilter({this.organizationName, this.departmentName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesignationFilter &&
          runtimeType == other.runtimeType &&
          organizationName == other.organizationName &&
          departmentName == other.departmentName;

  @override
  int get hashCode => organizationName.hashCode ^ departmentName.hashCode;
}

final filteredDesignationsProvider = FutureProvider.family<List<Designation>, DesignationFilter>(
  (ref, filter) => ref.watch(organizationRepositoryProvider).getDesignations(
        organizationName: filter.organizationName,
        departmentName: filter.departmentName,
      ),
);

final columnPreferenceProvider =
    FutureProvider.family<ColumnPreference?, String>(
  (ref, tableId) =>
      ref.watch(organizationRepositoryProvider).getColumnPreference(tableId),
);

final orgSearchQueryProvider = StateProvider<String>((ref) => '');
final deptSearchQueryProvider = StateProvider<String>((ref) => '');
final desigSearchQueryProvider = StateProvider<String>((ref) => '');
