import 'column_preference.dart';
import 'department.dart';
import 'organization.dart';

abstract interface class OrganizationRepository {
  // Organization methods
  Future<List<Organization>> getOrganizations();
  Future<void> addOrganization(Organization organization);
  Future<void> updateOrganization(Organization organization);
  Future<void> deleteOrganization(int id);

  // Department methods
  Future<List<Department>> getDepartments();
  Future<void> addDepartment(Department department);
  Future<void> updateDepartment(Department department);
  Future<void> deleteDepartment(int id);

  // Column Preference methods
  Future<ColumnPreference?> getColumnPreference(String tableId);
  Future<void> saveColumnPreference(ColumnPreference preference);
}
