import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/registration_link.dart';
import '../../providers/employee_providers.dart';

class AddEmployeeLinkDialog extends ConsumerStatefulWidget {
  const AddEmployeeLinkDialog({super.key});

  @override
  ConsumerState<AddEmployeeLinkDialog> createState() =>
      _AddEmployeeLinkDialogState();
}

class _AddEmployeeLinkDialogState
    extends ConsumerState<AddEmployeeLinkDialog> {
  final _generatedByController = TextEditingController(text: 'HR Admin');
  final _orgController = TextEditingController();
  final _deptController = TextEditingController();
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
    _orgController.dispose();
    _deptController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _generateLink() async {
    setState(() => _isGenerating = true);
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final link = await repo.createRegistrationLink(
        generatedBy: _generatedByController.text.trim(),
        organizationName: _orgController.text.trim(),
        department: _deptController.text.trim(),
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

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.person_add_alt_1_outlined, color: AppColors.active),
          const SizedBox(width: 8),
          const Text(
            'Add Employee - Registration Link',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Generate a secure registration link to send to the new employee. They will use this link to fill out their onboarding form.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _orgController,
                        decoration: const InputDecoration(
                          labelText: 'Target Organization (Optional)',
                          hintText: 'e.g. Acme Corp',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _deptController,
                        decoration: const InputDecoration(
                          labelText: 'Target Department (Optional)',
                          hintText: 'e.g. IT Department',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.active,
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.active, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Registration Link Generated Successfully!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.active,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        displayUrl ?? _generatedLink!.fullUrl,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.active,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Link ID: ${_generatedLink!.linkId}  \u00b7  Expires: ${_generatedLink!.expiryDate}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Share link via:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.active),
                      onPressed: () {
                        final linkId = _generatedLink!.linkId;
                        Navigator.of(context).pop();
                        GoRouter.of(context).push('/employee/register/$linkId');
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open Registration Form'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(displayUrl ?? _generatedLink!.fullUrl),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Link'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _shareViaAction('Email', displayUrl ?? _generatedLink!.fullUrl),
                      icon: const Icon(Icons.email_outlined, size: 16),
                      label: const Text('Email'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _shareViaAction('WhatsApp', displayUrl ?? _generatedLink!.fullUrl),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('WhatsApp'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _shareViaAction('SMS', displayUrl ?? _generatedLink!.fullUrl),
                      icon: const Icon(Icons.sms_outlined, size: 16),
                      label: const Text('SMS'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_generatedLink != null)
          TextButton(
            onPressed: () => setState(() => _generatedLink = null),
            child: const Text('Generate Another Link'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
