import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/employee.dart';
import '../../domain/registration_link.dart';
import '../../providers/employee_providers.dart';

class RequestCorrectionDialog extends ConsumerStatefulWidget {
  const RequestCorrectionDialog({
    required this.link,
    this.employee,
    this.candidateId = '',
    this.candidateName = '',
    this.candidateEmail = '',
    super.key,
  });

  final RegistrationLink link;
  final Employee? employee;
  final String candidateId;
  final String candidateName;
  final String candidateEmail;

  @override
  ConsumerState<RequestCorrectionDialog> createState() =>
      _RequestCorrectionDialogState();
}

class _RequestCorrectionDialogState
    extends ConsumerState<RequestCorrectionDialog> {
  final _remarksController = TextEditingController();
  bool _allowEditing = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  String _getBaseOrigin() {
    try {
      final uri = Uri.base;
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        final origin = uri.origin;
        if (origin.isNotEmpty) {
          return origin;
        }
      }
    } catch (_) {}
    return '';
  }

  String _buildEditUrl(String rawToken) {
    final base = _getBaseOrigin();
    final linkId = widget.link.linkId.isNotEmpty ? widget.link.linkId : widget.candidateId;
    final prefix = base.isNotEmpty ? '$base/' : '';
    return '$prefix#/employee/register/$linkId?correctionToken=$rawToken';
  }

  Future<String?> _generateCorrectionRequest() async {
    final remarks = _remarksController.text.trim();
    if (remarks.isEmpty) {
      setState(() => _errorMessage = 'Please enter a reason or remarks for correction.');
      return null;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final adminName = currentEmp?.fullName.isNotEmpty == true ? currentEmp!.fullName : 'HR Admin';
      final repo = ref.read(employeeRepositoryProvider);

      final candId = widget.candidateId.isNotEmpty
          ? widget.candidateId
          : (widget.link.employeeId.isNotEmpty ? widget.link.employeeId : 'CAN-${widget.link.id}');

      final rawToken = await repo.createCorrectionRequest(
        candidateId: candId,
        linkId: widget.link.linkId,
        candidateResponseId: candId,
        remarks: remarks,
        requestedBy: adminName,
        allowEditing: _allowEditing,
        validity: const Duration(days: 7),
      );

      ref.invalidate(registrationLinksProvider);
      ref.invalidate(candidateResponsesProvider);
      ref.invalidate(activeResponsesProvider);
      if (candId.isNotEmpty) {
        ref.invalidate(correctionRequestsForCandidateProvider(candId));
      }

      setState(() => _isSubmitting = false);
      return rawToken;
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to generate correction request: $e';
      });
      return null;
    }
  }

  Future<void> _handleCopyLink() async {
    final rawToken = await _generateCorrectionRequest();
    if (rawToken == null) return;

    final editUrl = _buildEditUrl(rawToken);
    await Clipboard.setData(ClipboardData(text: editUrl));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secure correction link copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleSendEmail() async {
    final rawToken = await _generateCorrectionRequest();
    if (rawToken == null) return;

    final editUrl = _buildEditUrl(rawToken);
    await Clipboard.setData(ClipboardData(text: editUrl));

    final name = widget.candidateName.isNotEmpty ? widget.candidateName : 'Candidate';
    final remarks = _remarksController.text.trim();
    final subject = Uri.encodeComponent('Action Required: Correction Requested for your Registration ($name)');
    final body = Uri.encodeComponent(
      'Dear $name,\n\n'
      'The HR team has reviewed your registration details and requested updates before approval.\n\n'
      'Reason / Remarks:\n'
      '$remarks\n\n'
      'Please click the secure link below to update and resubmit your details:\n'
      '$editUrl\n\n'
      'Thank you,\n'
      'HR Department',
    );

    final email = widget.candidateEmail.trim();
    final mailtoUri = Uri.parse('mailto:$email?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(mailtoUri);
      }
    } catch (_) {
      try {
        await launchUrl(mailtoUri);
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correction request created & link copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title + Close X
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.assignment_return_outlined,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Request Form Correction',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
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
            const SizedBox(height: 16),

            // Candidate info subtitle
            if (widget.candidateName.isNotEmpty || widget.candidateId.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      widget.candidateName.isNotEmpty ? widget.candidateName : 'Candidate',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.candidateId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${widget.candidateId})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Remarks field label
            const Text(
              'Reason for Resubmission / Remarks *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _remarksController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g. Please correct the district in your permanent address and re-upload the PAN card document.',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.active, width: 1.5),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 14),

            // Explicit permission checkbox
            InkWell(
              onTap: () {
                setState(() => _allowEditing = !_allowEditing);
              },
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _allowEditing,
                      activeColor: AppColors.active,
                      onChanged: (val) {
                        setState(() => _allowEditing = val ?? true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Allow candidate to edit previously submitted fields',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Bottom Actions: [ Cancel ]        [ Copy Edit Link ]  [ Send ]
            Row(
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _handleCopyLink,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 15, color: AppColors.textPrimary),
                  label: const Text(
                    'Copy Edit Link',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _handleSendEmail,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 15),
                  label: Text(
                    _isSubmitting ? 'Sending...' : 'Send',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
