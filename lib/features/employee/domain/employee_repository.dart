import 'dart:typed_data';

import 'candidate_response.dart';
import 'employee.dart';
import 'registration_link.dart';
import '../../organization/domain/column_preference.dart';

abstract class EmployeeRepository {
  Future<List<Employee>> getEmployees();
  Future<List<Employee>> getAllEmployees();
  Future<Employee?> getEmployeeById(int id);
  Future<Employee> addEmployee(Employee employee);
  Future<void> updateEmployee(Employee employee);
  Future<void> updateBulkLeavePolicy({
    required List<int> employeeIds,
    required String leaveType,
    required double allowedLeaves,
    required String leaveAllocationFrequency,
    required bool requiresLeaveApproval,
    String? effectiveDate,
  });
  Future<void> deleteEmployee(int id);
  Future<EmployeePhotoAsset> uploadEmployeeProfileImage({
    required String employeeId,
    required String role,
    required Uint8List imageBytes,
    required String fileName,
    required String mimeType,
  });

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
  Future<Employee> submitCandidateRegistration({
    required String linkId,
    required Employee candidateData,
  });
  Future<Employee> convertCandidateToEmployee({
    required String linkId,
    required Employee employeeData,
  });

  Future<CandidateResponse?> getCandidateResponseByLinkId(String linkId);
  Future<CandidateResponse?> getCandidateResponseByCandidateId(String candidateId);
  Future<List<CandidateResponse>> getCandidateResponses();
  Future<void> clearAllData();

  Future<ColumnPreference?> getColumnPreference(String tableId);
  Future<void> saveColumnPreference(ColumnPreference preference);

  Future<String> getNextEmployeeId();
}
