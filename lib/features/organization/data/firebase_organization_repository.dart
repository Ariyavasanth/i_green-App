import '../domain/column_preference.dart';
import '../domain/department.dart';
import '../domain/organization.dart';
import '../domain/organization_repository.dart';

class FirebaseOrganizationRepository implements OrganizationRepository {
  @override
  Future<List<Organization>> getOrganizations() => throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );

  @override
  Future<void> addOrganization(Organization organization) =>
      throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );

  @override
  Future<void> updateOrganization(Organization organization) =>
      throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );

  @override
  Future<void> deleteOrganization(int id) => throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );

  @override
  Future<List<Department>> getDepartments() => throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );

  @override
  Future<void> addDepartment(Department department) => throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );

  @override
  Future<void> updateDepartment(Department department) =>
      throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );

  @override
  Future<void> deleteDepartment(int id) => throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );

  @override
  Future<ColumnPreference?> getColumnPreference(String tableId) =>
      throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );

  @override
  Future<void> saveColumnPreference(ColumnPreference preference) =>
      throw UnimplementedError(
        'Firebase organization repository is not configured yet.',
      );
}
