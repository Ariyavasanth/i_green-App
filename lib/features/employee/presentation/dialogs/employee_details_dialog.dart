import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/employee.dart';

class EmployeeDetailsDialog extends StatelessWidget {
  const EmployeeDetailsDialog({required this.employee, super.key});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.active,
            child: Text(
              employee.firstName.isNotEmpty ? employee.firstName[0].toUpperCase() : 'E',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName.isEmpty ? 'Applicant Details' : employee.fullName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  employee.emailAddress.isNotEmpty
                      ? employee.emailAddress
                      : (employee.phoneNumber.isNotEmpty ? employee.phoneNumber : 'Registration Link Response'),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: (screenWidth * 0.9).clamp(280.0, 720.0),
        height: 620,
        child: DefaultTabController(
          length: 8,
          child: Column(
            children: [
              const TabBar(
                isScrollable: true,
                labelColor: AppColors.active,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.active,
                tabs: [
                  Tab(text: 'Personal Info'),
                  Tab(text: 'Address'),
                  Tab(text: 'Education'),
                  Tab(text: 'Experience'),
                  Tab(text: 'History'),
                  Tab(text: 'Bank Account'),
                  Tab(text: 'Document'),
                  Tab(text: 'Social Media'),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPersonalInfoTab(),
                    _buildAddressTab(),
                    _buildEducationTab(),
                    _buildExperienceTab(),
                    _buildHistoryTab(),
                    _buildBankAccountTab(),
                    _buildDocumentTab(),
                    _buildSocialMediaTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Personal Details'),
        _buildInfoGrid([
          _InfoItem('First Name', employee.firstName),
          _InfoItem('Last Name', employee.lastName),
          _InfoItem('Blood Group', employee.bloodGroup),
          _InfoItem('Gender', employee.gender),
          _InfoItem('Date of Birth', employee.dob),
          _InfoItem('Aadhaar Number', employee.aadhaarNumber),
          _InfoItem('Contact Number', employee.phoneNumber),
          _InfoItem('Date of Joining', employee.joiningDate),
          _InfoItem('Contract End Date', employee.contractEndDate),
          _InfoItem('Email Address', employee.emailAddress),
          _InfoItem('PF Number', employee.pfNumber),
          _InfoItem('ESI Number', employee.esiNumber),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Access Permissions'),
        ...Employee.sidebarPermissionsByCategory.entries.map((entry) {
          final categoryName = entry.key;
          final availablePerms = employee.accessPermissions.isNotEmpty
              ? employee.accessPermissions.toSet()
              : Employee.allSidebarPermissions.toSet();
          final categoryPerms = entry.value.where((p) => availablePerms.contains(p)).toList();

          if (categoryPerms.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667085),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: categoryPerms.map(
                  (perm) => Chip(
                    label: Text(perm, style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.active.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                ).toList(),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildAddressTab() {
    final permAddr = employee.permanentAddress.isNotEmpty ? employee.permanentAddress : employee.street;
    final permCity = employee.permanentCity.isNotEmpty ? employee.permanentCity : employee.city;
    final permCountry = employee.permanentCountry.isNotEmpty ? employee.permanentCountry : employee.country;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Permanent Contact Information'),
        _buildInfoGrid([
          _InfoItem('Address', permAddr),
          _InfoItem('City', permCity),
          _InfoItem('Country', permCountry),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Present Contact Information'),
        _buildInfoGrid([
          _InfoItem('Same as Permanent', employee.sameAsPermanent ? 'Yes' : 'No'),
          _InfoItem('Address', employee.presentAddress),
          _InfoItem('City', employee.presentCity),
          _InfoItem('Country', employee.presentCountry),
        ]),
      ],
    );
  }

  Widget _buildEducationTab() {
    final eduList = employee.educationItems;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Education Qualifications'),
        if (eduList.isNotEmpty)
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FixedColumnWidth(40),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(padding: EdgeInsets.all(6), child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Degree Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Institute Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Passing Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
              ...eduList.map(
                (item) => TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.id, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.degreeName, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.instituteName, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.result, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.passingYear, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ],
          )
        else
          const Text('No education details recorded.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildExperienceTab() {
    final expList = employee.experienceItems;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Work Experience'),
        if (expList.isNotEmpty)
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FixedColumnWidth(40),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(padding: EdgeInsets.all(6), child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Company Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Address/Duty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Work Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
              ...expList.map(
                (item) => TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.id, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.companyName, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.position, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.address, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.workingDuration, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ],
          )
        else
          const Text('No experience details recorded.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Personal History Details'),
        _buildInfoGrid([
          _InfoItem('Original DOB', employee.originalDob),
          _InfoItem('Personal Mobile Number', employee.personalMobile),
          _InfoItem('PAN Card Number', employee.panNumber),
          _InfoItem('Passport Number', employee.passportNumber),
          _InfoItem('Driving License Number', employee.drivingLicenseNumber),
          _InfoItem('Driving License Batch Details', employee.drivingLicenseBatch),
          _InfoItem('Health Issues', employee.healthIssues),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Emergency Contact'),
        _buildInfoGrid([
          _InfoItem('Contact Name', employee.emergencyName),
          _InfoItem('Mobile Number', employee.emergencyMobile),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Employee Referred By'),
        _buildInfoGrid([
          _InfoItem('Referred By Name', employee.referredByName),
          _InfoItem('Referred By Mobile', employee.referredByMobile),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Family Details'),
        _buildInfoGrid([
          _InfoItem('Father Name', employee.fatherName),
          _InfoItem('Mother Name', employee.motherName),
          _InfoItem('Marital Status', employee.maritalStatus),
          _InfoItem('Spouse Name', employee.spouseName),
          _InfoItem('Kids 1 Name', employee.kids1Name),
          _InfoItem('Kids 2 Name', employee.kids2Name),
          _InfoItem('Kids 3 Name', employee.kids3Name),
        ]),
      ],
    );
  }

  Widget _buildBankAccountTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Bank Account Details'),
        _buildInfoGrid([
          _InfoItem('Account Holder Name', employee.bankAccountHolder),
          _InfoItem('Bank Name', employee.bankName),
          _InfoItem('Account Number', employee.bankAccountNumber),
          _InfoItem('IFSC Code', employee.bankIfsc),
          _InfoItem('Branch Name', employee.bankBranch),
          _InfoItem('Account Type', employee.bankAccountType),
        ]),
      ],
    );
  }

  Widget _buildDocumentTab() {
    final docList = employee.documentItems;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Document Attachments'),
        if (docList.isNotEmpty)
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FixedColumnWidth(40),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2.5),
              3: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(padding: EdgeInsets.all(6), child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Document Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Doc Number / File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Uploaded Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
              ...docList.map(
                (item) => TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.id, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.documentType, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text('${item.documentNumber} (${item.fileName})', style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.uploadedDate, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ],
          )
        else
          const Text('No documents uploaded yet.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildSocialMediaTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Social Media Profiles'),
        _buildInfoGrid([
          _InfoItem('Facebook URL', employee.facebookUrl),
          _InfoItem('Twitter URL', employee.twitterUrl),
          _InfoItem('LinkedIn URL', employee.linkedinUrl),
          _InfoItem('Google URL', employee.googleUrl),
        ]),
      ],
    );
  }

  Widget _buildSalaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Salary Details'),
        _buildInfoGrid([
          _InfoItem('Salary Type', employee.salaryType),
          _InfoItem('Total CTC', employee.salaryTotalCtc == 0 ? '' : employee.salaryTotalCtc.toStringAsFixed(2)),
          _InfoItem('Basic Pay', employee.salaryBasic == 0 ? '' : employee.salaryBasic.toStringAsFixed(2)),
          _InfoItem('HRA', employee.salaryHra == 0 ? '' : employee.salaryHra.toStringAsFixed(2)),
          _InfoItem('Education Allowance', employee.salaryEducationAllowance == 0 ? '' : employee.salaryEducationAllowance.toStringAsFixed(2)),
          _InfoItem('Special Allowance', employee.salarySpecialAllowance == 0 ? '' : employee.salarySpecialAllowance.toStringAsFixed(2)),
          _InfoItem('Travel Allowance', employee.salaryTravelAllowance == 0 ? '' : employee.salaryTravelAllowance.toStringAsFixed(2)),
          _InfoItem('Tax', employee.salaryTax == 0 ? '' : employee.salaryTax.toStringAsFixed(2)),
          _InfoItem('PF', employee.salaryPf == 0 ? '' : employee.salaryPf.toStringAsFixed(2)),
          _InfoItem('Professional Tax', employee.salaryProfessionalTax == 0 ? '' : employee.salaryProfessionalTax.toStringAsFixed(2)),
        ]),
      ],
    );
  }

  Widget _buildCredentialsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Credentials'),
        _buildInfoGrid([
          _InfoItem('Employee ID', employee.employeeId),
          _InfoItem('Temporary Password', employee.temporaryPassword),
          _InfoItem('User Type', employee.userType),
          _InfoItem('Status', employee.status),
        ]),
      ],
    );
  }

  Widget _buildPermissionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Access Permissions'),
        if (employee.accessPermissions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: employee.accessPermissions
                .map((perm) => Chip(
                      label: Text(perm, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.active.withValues(alpha: 0.1),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          )
        else
          const Text('No access permissions assigned.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.active,
        ),
      ),
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: items.map((item) {
        return SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value.isEmpty ? '-' : item.value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);
  final String label;
  final String value;
}
