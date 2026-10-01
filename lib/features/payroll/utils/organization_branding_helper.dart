import '../../employee/domain/employee.dart';
import '../../organization/domain/organization.dart';

class OrganizationPayslipBranding {
  final String orgName;
  final String email;
  final String tanNumber;
  final String logoAssetPath;
  final bool isTecEngineering;
  final String companySubtitle;
  final String tagLine;

  const OrganizationPayslipBranding({
    required this.orgName,
    required this.email,
    required this.tanNumber,
    required this.logoAssetPath,
    required this.isTecEngineering,
    required this.companySubtitle,
    required this.tagLine,
  });

  factory OrganizationPayslipBranding.resolve({
    Organization? organization,
    Employee? employee,
  }) {
    final candidateName = (employee?.organizationName.isNotEmpty == true
            ? employee!.organizationName
            : (organization?.name.isNotEmpty == true ? organization!.name : ''))
        .trim();

    final lower = candidateName.toLowerCase();
    final empCode = (employee?.employeeId ?? '').trim().toUpperCase();

    // Check if it belongs to iGreen Tec Engineering
    // It is Tec Engineering ONLY if:
    // 1. It explicitly contains "engineering", "tec engineering", "pvt ltd"
    // 2. Or the employee ID starts with "IGT"
    // 3. Or it has "tec" as a distinct word AND does not contain "technolog"
    final isTec = lower.contains('engineering') ||
        lower.contains('tec engineering') ||
        lower.contains('pvt ltd') ||
        empCode.startsWith('IGT') ||
        (RegExp(r'\btec\b').hasMatch(lower) && !lower.contains('technolog'));

    if (isTec) {
      final name = candidateName.isNotEmpty
          ? candidateName
          : 'IGREEN TEC ENGINEERING INDIA PVT LTD';
      final email = organization?.emailAddress.isNotEmpty == true
          ? organization!.emailAddress
          : 'SUPPORT@IGREENTEC.IN';
      final tan = organization?.tanNumber.isNotEmpty == true
          ? organization!.tanNumber
          : (organization?.panNumber.isNotEmpty == true
              ? organization!.panNumber
              : 'CHEI09733D');

      return OrganizationPayslipBranding(
        orgName: name,
        email: email,
        tanNumber: tan,
        logoAssetPath: 'assets/igreen_logo_engineering.png',
        isTecEngineering: true,
        companySubtitle: 'Tec Engineering India Pvt Ltd',
        tagLine: 'Innovation In Engineering',
      );
    } else {
      final name = candidateName.isNotEmpty
          ? candidateName
          : 'IGREEN TECHNOLOGIES';
      final email = (organization != null &&
              !organization.name.toLowerCase().contains('engineering') &&
              organization.emailAddress.isNotEmpty)
          ? organization.emailAddress
          : 'support@igreentechnologies.in';
      final tan = (organization != null &&
              !organization.name.toLowerCase().contains('engineering') &&
              organization.tanNumber.isNotEmpty)
          ? organization.tanNumber
          : ((organization != null &&
                  !organization.name.toLowerCase().contains('engineering') &&
                  organization.panNumber.isNotEmpty)
              ? organization.panNumber
              : 'CHEG16972E');

      return OrganizationPayslipBranding(
        orgName: name,
        email: email,
        tanNumber: tan,
        logoAssetPath: 'assets/igreen_logo_technology.png',
        isTecEngineering: false,
        companySubtitle: 'TECHNOLOGIES',
        tagLine: 'trenchless solutions',
      );
    }
  }
}
