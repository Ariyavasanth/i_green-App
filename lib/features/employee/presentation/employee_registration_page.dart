import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../domain/employee.dart';
import '../domain/registration_link.dart';
import '../providers/employee_providers.dart';

class EmployeeRegistrationPage extends ConsumerStatefulWidget {
  const EmployeeRegistrationPage({required this.linkId, super.key});

  final String linkId;

  @override
  ConsumerState<EmployeeRegistrationPage> createState() =>
      _EmployeeRegistrationPageState();
}

class _EmployeeRegistrationPageState
    extends ConsumerState<EmployeeRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Personal
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  String _gender = 'Male';
  final _orgController = TextEditingController();
  final _deptController = TextEditingController();
  final _designationController = TextEditingController();
  String _employmentType = 'Full-Time';
  final _joiningDateController = TextEditingController();

  // Address
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');

  // Education
  final _eduDegreeController = TextEditingController();
  final _eduInstController = TextEditingController();
  final _eduYearController = TextEditingController();
  final _eduGradeController = TextEditingController();

  // Experience
  final _expCompanyController = TextEditingController();
  final _expRoleController = TextEditingController();
  final _expYearsController = TextEditingController();

  // Bank
  final _bankHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccNumController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankBranchController = TextEditingController();

  // Documents
  final _panController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _eduCertUrlController = TextEditingController();
  final _bloodReportController = TextEditingController();

  // Other Sections
  final _personalHistoryController = TextEditingController();
  final _salaryBasicController = TextEditingController(text: '0');
  final _salaryHraController = TextEditingController(text: '0');
  final _salaryAllowancesController = TextEditingController(text: '0');
  final _salaryTotalCtcController = TextEditingController(text: '0');

  final _insurancePolicyNoController = TextEditingController();
  final _insuranceProviderController = TextEditingController();
  final _insuranceCoverageController = TextEditingController(text: '0');

  final _pfNumberController = TextEditingController();
  final _pfUanController = TextEditingController();
  final _esiNumberController = TextEditingController();

  final _leaveDetailsController = TextEditingController();
  final _companyAssetsController = TextEditingController();
  final _reportingManagerController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _disciplinaryController = TextEditingController();

  bool _isSubmitting = false;
  Employee? _submittedEmployee;

  @override
  void initState() {
    super.initState();
    _joiningDateController.text = DateTime.now().toString().split(' ')[0];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _orgController.dispose();
    _deptController.dispose();
    _designationController.dispose();
    _joiningDateController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _eduDegreeController.dispose();
    _eduInstController.dispose();
    _eduYearController.dispose();
    _eduGradeController.dispose();
    _expCompanyController.dispose();
    _expRoleController.dispose();
    _expYearsController.dispose();
    _bankHolderController.dispose();
    _bankNameController.dispose();
    _bankAccNumController.dispose();
    _bankIfscController.dispose();
    _bankBranchController.dispose();
    _panController.dispose();
    _aadhaarController.dispose();
    _eduCertUrlController.dispose();
    _bloodReportController.dispose();
    _personalHistoryController.dispose();
    _salaryBasicController.dispose();
    _salaryHraController.dispose();
    _salaryAllowancesController.dispose();
    _salaryTotalCtcController.dispose();
    _insurancePolicyNoController.dispose();
    _insuranceProviderController.dispose();
    _insuranceCoverageController.dispose();
    _pfNumberController.dispose();
    _pfUanController.dispose();
    _esiNumberController.dispose();
    _leaveDetailsController.dispose();
    _companyAssetsController.dispose();
    _reportingManagerController.dispose();
    _teamNameController.dispose();
    _passwordController.dispose();
    _disciplinaryController.dispose();
    super.dispose();
  }

  Future<void> _submitForm(RegistrationLink link) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all mandatory fields marked with *'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(employeeRepositoryProvider);

      final employeeData = Employee(
        id: 0,
        employeeId: '',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        emailAddress: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        gender: _gender,
        dob: _dobController.text.trim(),
        organizationName: _orgController.text.trim().isEmpty
            ? link.organizationName
            : _orgController.text.trim(),
        department: _deptController.text.trim().isEmpty
            ? link.department
            : _deptController.text.trim(),
        designation: _designationController.text.trim(),
        employmentType: _employmentType,
        joiningDate: _joiningDateController.text.trim(),
        status: 'Active',
        street: _streetController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        country: _countryController.text.trim(),
        educationDegree: _eduDegreeController.text.trim(),
        educationInstitution: _eduInstController.text.trim(),
        educationYear: _eduYearController.text.trim(),
        educationGrade: _eduGradeController.text.trim(),
        experienceCompany: _expCompanyController.text.trim(),
        experienceRole: _expRoleController.text.trim(),
        experienceYears: _expYearsController.text.trim(),
        bankAccountHolder: _bankHolderController.text.trim().isEmpty
            ? '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            : _bankHolderController.text.trim(),
        bankName: _bankNameController.text.trim(),
        bankAccountNumber: _bankAccNumController.text.trim(),
        bankIfsc: _bankIfscController.text.trim(),
        bankBranch: _bankBranchController.text.trim(),
        panNumber: _panController.text.trim(),
        aadhaarNumber: _aadhaarController.text.trim(),
        eduCertificatesUrl: _eduCertUrlController.text.trim(),
        bloodGroupReport: _bloodReportController.text.trim(),
        personalHistoryDetails: _personalHistoryController.text.trim(),
        salaryBasic: double.tryParse(_salaryBasicController.text.trim()) ?? 0,
        salaryHra: double.tryParse(_salaryHraController.text.trim()) ?? 0,
        salaryAllowances: double.tryParse(_salaryAllowancesController.text.trim()) ?? 0,
        salaryTotalCtc: double.tryParse(_salaryTotalCtcController.text.trim()) ?? 0,
        insurancePolicyNo: _insurancePolicyNoController.text.trim(),
        insuranceProvider: _insuranceProviderController.text.trim(),
        insuranceCoverage: double.tryParse(_insuranceCoverageController.text.trim()) ?? 0,
        pfNumber: _pfNumberController.text.trim(),
        pfUan: _pfUanController.text.trim(),
        esiNumber: _esiNumberController.text.trim(),
        leaveDetails: _leaveDetailsController.text.trim(),
        companyAssets: _companyAssetsController.text.trim(),
        reportingManager: _reportingManagerController.text.trim(),
        teamName: _teamNameController.text.trim(),
        disciplinaryRecords: _disciplinaryController.text.trim(),
        temporaryPassword: _passwordController.text.trim(),
      );

      final created = await repo.submitEmployeeRegistration(
        linkId: widget.linkId,
        employeeData: employeeData,
      );

      ref.invalidate(employeesProvider);
      ref.invalidate(registrationLinksProvider);
      ref.invalidate(registrationLinkByIdProvider(widget.linkId));

      setState(() {
        _submittedEmployee = created;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration submission failed: $e')),
        );
      }
    }
  }

  Widget _buildFieldPair({
    required Widget child1,
    required Widget child2,
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        children: [
          child1,
          const SizedBox(height: 14),
          child2,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: child1),
        const SizedBox(width: 16),
        Expanded(child: child2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final linkAsync = ref.watch(registrationLinkByIdProvider(widget.linkId));
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Employee Self-Registration'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: linkAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Invalid link or error: $err')),
        data: (link) {
          if (link == null) {
            return _buildStatusCard(
              icon: Icons.error_outline,
              color: Colors.red,
              title: 'Invalid Registration Link',
              message: 'This registration link does not exist in our system.',
            );
          }

          if (link.linkStatus == 'Completed' || _submittedEmployee != null) {
            final emp = _submittedEmployee;
            return _buildStatusCard(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              title: 'Registration Completed Successfully!',
              message:
                  'Thank you! Your employee registration has been submitted and your account has been created.\n\n'
                  '${emp != null ? "Employee ID Generated: ${emp.employeeId}\nTemporary Password: ${emp.temporaryPassword}" : "Link Status: Completed (Already Used)"}',
            );
          }

          if (link.linkStatus == 'Expired') {
            return _buildStatusCard(
              icon: Icons.timer_off_outlined,
              color: Colors.orange,
              title: 'Registration Link Expired',
              message: 'This registration link has expired. Please contact HR for a new invite link.',
            );
          }

          // Pre-fill target org / dept if set on link
          if (_orgController.text.isEmpty && link.organizationName.isNotEmpty) {
            _orgController.text = link.organizationName;
          }
          if (_deptController.text.isEmpty && link.department.isNotEmpty) {
            _deptController.text = link.department;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 18 : 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Employee Onboarding Form',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Registration Link ID: ${link.linkId}  \u00b7  Generated By: ${link.generatedBy}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),

                          _buildSectionTitle('1. Basic Personal Details'),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'First Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            child2: TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Last Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email Address *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            child2: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Male', 'Female', 'Other']
                                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _gender = val);
                              },
                            ),
                            child2: TextFormField(
                              controller: _dobController,
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth (YYYY-MM-DD)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _orgController,
                              decoration: const InputDecoration(
                                labelText: 'Organization Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            child2: TextFormField(
                              controller: _deptController,
                              decoration: const InputDecoration(
                                labelText: 'Department *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _designationController,
                              decoration: const InputDecoration(
                                labelText: 'Designation *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            child2: DropdownButtonFormField<String>(
                              initialValue: _employmentType,
                              decoration: const InputDecoration(
                                labelText: 'Employment Type',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Full-Time', 'Part-Time', 'Contract', 'Intern']
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _employmentType = val);
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildSectionTitle('2. Address Details'),
                          TextFormField(
                            controller: _streetController,
                            decoration: const InputDecoration(
                              labelText: 'Street Address',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(
                                labelText: 'State',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _postalCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Postal Code',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _countryController,
                              decoration: const InputDecoration(
                                labelText: 'Country',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildSectionTitle('3. Education & Qualification'),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _eduDegreeController,
                              decoration: const InputDecoration(
                                labelText: 'Degree / Qualification',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _eduInstController,
                              decoration: const InputDecoration(
                                labelText: 'College / University',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _eduYearController,
                              decoration: const InputDecoration(
                                labelText: 'Passing Year',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _eduGradeController,
                              decoration: const InputDecoration(
                                labelText: 'Grade / CGPA',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildSectionTitle('4. Work Experience'),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _expCompanyController,
                              decoration: const InputDecoration(
                                labelText: 'Previous Company Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _expRoleController,
                              decoration: const InputDecoration(
                                labelText: 'Previous Designation / Role',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _expYearsController,
                            decoration: const InputDecoration(
                              labelText: 'Total Experience (Years)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildSectionTitle('5. Bank Account Details'),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _bankHolderController,
                              decoration: const InputDecoration(
                                labelText: 'Account Holder Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _bankNameController,
                              decoration: const InputDecoration(
                                labelText: 'Bank Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _bankAccNumController,
                              decoration: const InputDecoration(
                                labelText: 'Account Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _bankIfscController,
                              decoration: const InputDecoration(
                                labelText: 'IFSC Code',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildSectionTitle('6. Statutory & Document Numbers'),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _panController,
                              decoration: const InputDecoration(
                                labelText: 'PAN Card Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _aadhaarController,
                              decoration: const InputDecoration(
                                labelText: 'Aadhaar Card Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _pfNumberController,
                              decoration: const InputDecoration(
                                labelText: 'PF Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _esiNumberController,
                              decoration: const InputDecoration(
                                labelText: 'ESI Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildSectionTitle('7. Document Upload / Attachments'),
                          _buildDocUploadField('Educational Certificates', _eduCertUrlController, isMobile),
                          const SizedBox(height: 14),
                          _buildDocUploadField('Blood Group Report', _bloodReportController, isMobile),
                          const SizedBox(height: 24),

                          _buildSectionTitle('8. Salary Details & Security'),
                          _buildFieldPair(
                            isMobile: isMobile,
                            child1: TextFormField(
                              controller: _salaryTotalCtcController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Offered Total CTC (Per Annum)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            child2: TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Account Password (Optional)',
                                hintText: 'Auto-generated if left empty',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.active,
                              ),
                              onPressed: _isSubmitting ? null : () => _submitForm(link),
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle, size: 20),
                              label: Text(
                                _isSubmitting ? 'Submitting Registration...' : 'Submit Employee Registration',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.active,
        ),
      ),
    );
  }

  Widget _buildDocUploadField(String label, TextEditingController controller, bool isMobile) {
    final field = TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Selected file path or reference',
        border: const OutlineInputBorder(),
      ),
    );

    final button = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      onPressed: () {
        controller.text = '${label.replaceAll(' ', '_').toLowerCase()}_attachment.pdf';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attached document for $label')),
        );
      },
      icon: const Icon(Icons.upload_file, size: 18),
      label: const Text('Upload'),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          const SizedBox(height: 8),
          button,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 10),
        button,
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 54),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
