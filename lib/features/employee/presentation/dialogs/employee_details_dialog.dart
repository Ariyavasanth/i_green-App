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
                  employee.fullName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ID: ${employee.employeeId}  \u00b7  ${employee.designation} (${employee.department})',
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
        height: 520,
        child: DefaultTabController(
          length: 5,
          child: Column(
            children: [
              const TabBar(
                isScrollable: true,
                labelColor: AppColors.active,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: 'Personal & Org'),
                  Tab(text: 'Edu & Experience'),
                  Tab(text: 'Salary & Bank'),
                  Tab(text: 'Statutory & Assets'),
                  Tab(text: 'Documents & Security'),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPersonalTab(),
                    _buildEduExpTab(),
                    _buildSalaryBankTab(),
                    _buildStatutoryAssetsTab(),
                    _buildDocsSecurityTab(),
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

  Widget _buildPersonalTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Personal Details'),
        _buildInfoGrid([
          _InfoItem('First Name', employee.firstName),
          _InfoItem('Last Name', employee.lastName),
          _InfoItem('Gender', employee.gender),
          _InfoItem('Date of Birth', employee.dob),
          _InfoItem('Email Address', employee.emailAddress),
          _InfoItem('Phone Number', employee.phoneNumber),
        ]),
        const SizedBox(height: 16),
        _buildSectionHeader('Organization Details'),
        _buildInfoGrid([
          _InfoItem('Organization Name', employee.organizationName),
          _InfoItem('Department', employee.department),
          _InfoItem('Designation', employee.designation),
          _InfoItem('Employment Type', employee.employmentType),
          _InfoItem('Joining Date', employee.joiningDate),
          _InfoItem('Status', employee.status),
          _InfoItem('Reporting Manager', employee.reportingManager),
          _InfoItem('Team Name', employee.teamName),
        ]),
        const SizedBox(height: 16),
        _buildSectionHeader('Address'),
        _buildInfoGrid([
          _InfoItem('Street', employee.street),
          _InfoItem('City', employee.city),
          _InfoItem('State', employee.state),
          _InfoItem('Postal Code', employee.postalCode),
          _InfoItem('Country', employee.country),
        ]),
      ],
    );
  }

  Widget _buildEduExpTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Education'),
        _buildInfoGrid([
          _InfoItem('Degree / Qualification', employee.educationDegree),
          _InfoItem('Institution / University', employee.educationInstitution),
          _InfoItem('Passing Year', employee.educationYear),
          _InfoItem('Grade / Percentage', employee.educationGrade),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Experience'),
        _buildInfoGrid([
          _InfoItem('Previous Company', employee.experienceCompany),
          _InfoItem('Previous Role', employee.experienceRole),
          _InfoItem('Years of Experience', employee.experienceYears),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Personal History'),
        Text(
          employee.personalHistoryDetails.isEmpty
              ? 'No personal history details provided.'
              : employee.personalHistoryDetails,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSalaryBankTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Employee Salary Details'),
        _buildInfoGrid([
          _InfoItem('Basic Salary', '₹${employee.salaryBasic.toStringAsFixed(2)}'),
          _InfoItem('HRA', '₹${employee.salaryHra.toStringAsFixed(2)}'),
          _InfoItem('Allowances', '₹${employee.salaryAllowances.toStringAsFixed(2)}'),
          _InfoItem('Total CTC', '₹${employee.salaryTotalCtc.toStringAsFixed(2)}'),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Bank Account Details'),
        _buildInfoGrid([
          _InfoItem('Account Holder', employee.bankAccountHolder),
          _InfoItem('Bank Name', employee.bankName),
          _InfoItem('Account Number', employee.bankAccountNumber),
          _InfoItem('IFSC Code', employee.bankIfsc),
          _InfoItem('Branch', employee.bankBranch),
        ]),
      ],
    );
  }

  Widget _buildStatutoryAssetsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('PF & ESI Details'),
        _buildInfoGrid([
          _InfoItem('PF Number', employee.pfNumber),
          _InfoItem('UAN Number', employee.pfUan),
          _InfoItem('ESI Number', employee.esiNumber),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Insurance Details'),
        _buildInfoGrid([
          _InfoItem('Policy Number', employee.insurancePolicyNo),
          _InfoItem('Insurance Provider', employee.insuranceProvider),
          _InfoItem('Coverage Amount', '₹${employee.insuranceCoverage.toStringAsFixed(2)}'),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Company Assets & Leave Details'),
        _buildInfoGrid([
          _InfoItem('Company Assets', employee.companyAssets),
          _InfoItem('Leave / Holiday Info', employee.leaveDetails),
        ]),
      ],
    );
  }

  Widget _buildDocsSecurityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Documents'),
        _buildInfoGrid([
          _InfoItem('PAN Card Number', employee.panNumber),
          _InfoItem('Aadhaar Number', employee.aadhaarNumber),
          _InfoItem('Education Certificates', employee.eduCertificatesUrl),
          _InfoItem('Blood Group Report', employee.bloodGroupReport),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader('Disciplinary & Security'),
        _buildInfoGrid([
          _InfoItem('Disciplinary Records', employee.disciplinaryRecords),
          _InfoItem('Temporary Password', employee.temporaryPassword),
        ]),
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
