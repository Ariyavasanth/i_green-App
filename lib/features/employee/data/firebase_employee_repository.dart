import '../../organization/domain/column_preference.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';
import '../domain/registration_link.dart';

class FirebaseEmployeeRepository implements EmployeeRepository {
  @override
  Future<List<Employee>> getEmployees() => throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<Employee?> getEmployeeById(int id) => throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<void> addEmployee(Employee employee) => throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<void> updateEmployee(Employee employee) => throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<void> deleteEmployee(int id) => throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<RegistrationLink> createRegistrationLink({
    required String generatedBy,
    String? organizationName,
    String? department,
  }) => throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<List<RegistrationLink>> getRegistrationLinks() =>
      throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<RegistrationLink?> getRegistrationLinkById(String linkId) =>
      throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<Employee> submitEmployeeRegistration({
    required String linkId,
    required Employee employeeData,
  }) => throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<ColumnPreference?> getColumnPreference(String tableId) =>
      throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );

  @override
  Future<void> saveColumnPreference(ColumnPreference preference) =>
      throw UnimplementedError(
        'Firebase employee repository is not configured yet.',
      );
}
