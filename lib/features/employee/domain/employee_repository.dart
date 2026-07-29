import 'employee.dart';
import 'registration_link.dart';
import '../../organization/domain/column_preference.dart';

abstract class EmployeeRepository {
  Future<List<Employee>> getEmployees();
  Future<Employee?> getEmployeeById(int id);
  Future<Employee> addEmployee(Employee employee);
  Future<void> updateEmployee(Employee employee);
  Future<void> deleteEmployee(int id);

  Future<RegistrationLink> createRegistrationLink({
    required String generatedBy,
    String? organizationName,
    String? department,
  });
  Future<List<RegistrationLink>> getRegistrationLinks();
  Future<RegistrationLink?> getRegistrationLinkById(String linkId);
  Future<void> updateRegistrationLinkStatus({
    required String linkId,
    required String linkStatus,
  });
  Future<Employee> submitEmployeeRegistration({
    required String linkId,
    required Employee employeeData,
    bool isSubmit = true,
  });

  Future<ColumnPreference?> getColumnPreference(String tableId);
  Future<void> saveColumnPreference(ColumnPreference preference);
}
