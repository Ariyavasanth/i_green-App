import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/registration_link.dart';
import '../../providers/employee_providers.dart';

import '../../../../core/widgets/app_searchable_dropdown.dart';
import '../../../organization/providers/organization_providers.dart';

class AddEmployeeLinkDialog extends ConsumerStatefulWidget {
  const AddEmployeeLinkDialog({super.key});

  @override
  ConsumerState<AddEmployeeLinkDialog> createState() =>
      _AddEmployeeLinkDialogState();
}

class _AddEmployeeLinkDialogState
    extends ConsumerState<AddEmployeeLinkDialog> {
  final _generatedByController = TextEditingController(text: 'HR Admin');
  String? _selectedOrg;
  String? _selectedDept;
  late final TextEditingController _baseUrlController;

  RegistrationLink? _generatedLink;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    String origin = '';
    try {
      final uri = Uri.base;
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        origin = uri.origin;
      }
    } catch (_) {}
    final initialUrl = (origin.startsWith('http') &&
            !origin.contains('localhost') &&
            !origin.contains('127.0.0.1'))
        ? origin
        : 'https://i-green-tech.web.app';
    _baseUrlController = TextEditingController(text: initialUrl);
  }

  @override
  void dispose() {
    _generatedByController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _generateLink() async {
    setState(() => _isGenerating = true);
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final link = await repo.createRegistrationLink(
        generatedBy: _generatedByController.text.trim(),
        organizationName: _selectedOrg ?? '',
        department: _selectedDept ?? '',
      );
      ref.invalidate(registrationLinksProvider);
      setState(() {
        _generatedLink = link;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate link: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareViaAction(String channel, String url) async {
    final text = Uri.encodeComponent(
        'Please complete your employee onboarding registration using this link:\n$url');

    Uri? uri;
    if (channel == 'Email') {
      uri = Uri.parse(
          'mailto:?subject=${Uri.encodeComponent("Employee Onboarding Registration Link")}&body=$text');
    } else if (channel == 'WhatsApp') {
      uri = Uri.parse('https://wa.me/?text=$text');
    } else if (channel == 'SMS') {
      uri = Uri.parse('sms:?body=$text');
    }

    if (uri != null) {
      try {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          _copyToClipboard(url);
        }
      } catch (_) {
        _copyToClipboard(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = _generatedLink?.buildFullUrl(
      customBaseUrl: _baseUrlController.text,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Top Header: Icon + Title + Close Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.active.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_outlined,
                    color: AppColors.active,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Registration link',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Send this secure link to the new employee to fill out their onboarding form.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
            ),
            const SizedBox(height: 16),

            if (_generatedLink == null) ...[
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Production App Domain / Base URL *',
                  hintText: 'e.g. https://app.igreentech.in',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _generatedByController,
                decoration: const InputDecoration(
                  labelText: 'Generated By *',
                  hintText: 'e.g. HR Admin / John Doe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ref.watch(organizationsProvider).when(
                    loading: () => const SizedBox(height: 48, child: Center(child: LinearProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (orgs) {
                      final orgNames = orgs.map((o) => o.name).where((s) => s.isNotEmpty).toList();
                      return AppSearchableDropdown<String>(
                        label: 'Target Organization (Optional)',
                        value: _selectedOrg,
                        items: orgNames,
                        placeholder: 'Select Target Organization',
                        searchHint: 'Search organization...',
                        onChanged: (val) {
                          setState(() {
                            _selectedOrg = val;
                            _selectedDept = null;
                          });
                        },
                      );
                    },
                  ),
              const SizedBox(height: 12),
              ref.watch(departmentsProvider).when(
                    loading: () => const SizedBox(height: 48, child: Center(child: LinearProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (depts) {
                      var filteredDepts = depts;
                      if (_selectedOrg != null && _selectedOrg!.isNotEmpty) {
                        filteredDepts = depts.where((d) => d.organizationName == _selectedOrg).toList();
                      }
                      final deptNames = filteredDepts.map((d) => d.departmentName).where((s) => s.isNotEmpty).toSet().toList();
                      return AppSearchableDropdown<String>(
                        label: 'Target Department (Optional)',
                        value: _selectedDept,
                        items: deptNames,
                        placeholder: 'Select Target Department',
                        searchHint: 'Search department...',
                        onChanged: (val) {
                          setState(() => _selectedDept = val);
                        },
                      );
                    },
                  ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.active,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isGenerating ? null : _generateLink,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link, size: 18),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate Registration Link'),
                ),
              ),
            ] else ...[
              // Link Generated Container (Reflected from Reference Image 1 Layout)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCFCE7), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Link generated',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Dark/Monospace URL Code Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        displayUrl ?? _generatedLink!.fullUrl,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID ${_generatedLink!.linkId} · expires ${_generatedLink!.expiryDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Share via',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Full-width Primary Action Button: Open Registration Form
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF363E45),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final linkId = _generatedLink!.linkId;
                    Navigator.of(context).pop();
                    GoRouter.of(context).push('/employee/register/$linkId?acceptedLinkId=$linkId');
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text(
                    'Open registration form',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 2-Column Action Buttons Grid (Copy Link, Email, WhatsApp, SMS)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _copyToClipboard(displayUrl ?? _generatedLink!.fullUrl),
                      icon: const Icon(Icons.copy, size: 16, color: AppColors.textPrimary),
                      label: const Text(
                        'Copy link',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _shareViaAction('Email', displayUrl ?? _generatedLink!.fullUrl),
                      icon: const Icon(Icons.email_outlined, size: 16, color: AppColors.textPrimary),
                      label: const Text(
                        'Email',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _shareViaAction('WhatsApp', displayUrl ?? _generatedLink!.fullUrl),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textPrimary),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _shareViaAction('SMS', displayUrl ?? _generatedLink!.fullUrl),
                      icon: const Icon(Icons.sms_outlined, size: 16, color: AppColors.textPrimary),
                      label: const Text(
                        'SMS',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Bottom Action Row (Generate another link on left, Close on right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_generatedLink != null)
                  TextButton(
                    onPressed: () => setState(() => _generatedLink = null),
                    child: const Text(
                      'Generate another link',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.active,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}
