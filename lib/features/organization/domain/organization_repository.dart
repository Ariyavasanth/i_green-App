import 'business_unit.dart';
import 'column_preference.dart';
import 'department.dart';
import 'designation.dart';
import 'location.dart';
import 'organization.dart';

abstract interface class OrganizationRepository {
  // Organization methods
  Future<List<Organization>> getOrganizations();
  Future<void> addOrganization(Organization organization);
  Future<void> updateOrganization(Organization organization);
  Future<void> deleteOrganization(int id);

  // Business Unit methods
  Future<List<BusinessUnit>> getBusinessUnits({String? organizationName});
  Future<void> addBusinessUnit(BusinessUnit businessUnit);
  Future<void> updateBusinessUnit(BusinessUnit businessUnit);
  Future<void> deleteBusinessUnit(int id);

  // Location methods
  Future<List<Location>> getLocations({String? organizationName, String? businessUnitName});
  Future<void> addLocation(Location location);
  Future<void> updateLocation(Location location);
  Future<void> deleteLocation(int id);

  // Department methods
  Future<List<Department>> getDepartments({String? organizationName, String? businessUnitName, String? workLocation});
  Future<void> addDepartment(Department department);
  Future<void> updateDepartment(Department department);
  Future<void> deleteDepartment(int id);

  // Designation methods
  Future<List<Designation>> getDesignations({String? departmentName});
  Future<void> addDesignation(Designation designation);
  Future<void> updateDesignation(Designation designation);
  Future<void> deleteDesignation(int id);

  // Column Preference methods
  Future<ColumnPreference?> getColumnPreference(String tableId);
  Future<void> saveColumnPreference(ColumnPreference preference);
}
