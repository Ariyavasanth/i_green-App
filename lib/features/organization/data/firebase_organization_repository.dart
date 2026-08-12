import '../domain/column_preference.dart';
import '../domain/department.dart';
import '../domain/organization.dart';
import '../domain/organization_repository.dart';

/// Firestore stub — returns safe empty values until fully implemented.
class FirebaseOrganizationRepository implements OrganizationRepository {
  @override Future<List<Organization>> getOrganizations() async => [];
  @override Future<void> addOrganization(Organization organization) async {}
  @override Future<void> updateOrganization(Organization organization) async {}
  @override Future<void> deleteOrganization(int id) async {}
  @override Future<List<Department>> getDepartments() async => [];
  @override Future<void> addDepartment(Department department) async {}
  @override Future<void> updateDepartment(Department department) async {}
  @override Future<void> deleteDepartment(int id) async {}
  @override Future<ColumnPreference?> getColumnPreference(String tableId) async => null;
  @override Future<void> saveColumnPreference(ColumnPreference preference) async {}
}
