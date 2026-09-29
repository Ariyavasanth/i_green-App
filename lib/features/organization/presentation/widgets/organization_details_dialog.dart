import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/organization.dart';
import '../../../employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../../employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../../employee/services/offer_letter_save_io.dart';

class OrganizationDetailsDialog extends StatelessWidget {
  const OrganizationDetailsDialog({
    required this.organization,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final Organization organization;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Future<String> _resolveFileUrl(OrgDocument doc) async {
    String url = doc.fileUrl.trim();
    if (url.isNotEmpty) return url;

    try {
      final storage = FirebaseStorage.instance;
      final orgId = organization.canonicalId.isNotEmpty
          ? organization.canonicalId
          : (organization.id != 0 ? '${organization.id}' : '1');

      final cleanFileName = doc.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final cleanTitle = doc.title.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final candidates = [
        'organizations/$orgId/documents/$cleanTitle/${doc.fileName}',
        'organizations/$orgId/images/$cleanTitle/${doc.fileName}',
        'organizations/$orgId/documents/$cleanTitle/$cleanFileName',
        'organizations/$orgId/images/$cleanTitle/$cleanFileName',
        'organizations/$orgId/$cleanTitle/${doc.fileName}',
        'organizations/$orgId/$cleanTitle/$cleanFileName',
        'organizations/$orgId/${doc.fileName}',
        'organizations/$orgId/$cleanFileName',
      ];

      for (final path in candidates) {
        try {
          final resolved = await storage.ref().child(path).getDownloadURL();
          if (resolved.isNotEmpty) return resolved;
        } catch (_) {}
      }
    } catch (_) {}

    return '';
  }

  Future<void> _handleDownload(BuildContext context, OrgDocument doc) async {
    final url = await _resolveFileUrl(doc);
    if (url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document link not available for ${doc.title} (${doc.fileName})'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      await downloadFileFromUrl(
        context: context,
        url: url,
        fileName: doc.fileName.isNotEmpty ? doc.fileName : '${doc.title}.pdf',
        docTitle: doc.title,
      );
    }
  }

  Future<void> _handleView(BuildContext context, OrgDocument doc) async {
    final url = await _resolveFileUrl(doc);
    if (url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document link not available for ${doc.title} (${doc.fileName})'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      await _openDocUrl(context, url);
    }
  }

  Future<void> _openDocUrl(BuildContext context, String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document link.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 620,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Eye Icon + Title + Close Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove_red_eye_outlined, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Organization Profile & Statutory Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Card inside Modal
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          organization.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (organization.businessType.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  organization.businessType,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                              ),
                            if (organization.industryType.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF414A51).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  organization.industryType,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF414A51)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Basic Information
                    _buildSectionContainer(
                      title: 'General Information',
                      icon: Icons.info_outline,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                label: 'Business Unit(s)',
                                value: organization.businessUnits,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDetailRow(
                                label: 'Location(s)',
                                value: organization.locations,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18, color: Color(0xFFF2F4F7)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildDetailRow(
                                label: 'Registered Office Address',
                                value: organization.address,
                              ),
                            ),
                            if (organization.pincode.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: _buildDetailRow(
                                  label: 'PIN Code',
                                  value: organization.pincode,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Divider(height: 18, color: Color(0xFFF2F4F7)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                label: 'Official Email Address',
                                value: organization.emailAddress,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDetailRow(
                                label: 'Website',
                                value: organization.website,
                                isLink: organization.website.isNotEmpty,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Contact Numbers
                    _buildSectionContainer(
                      title: 'Contact Numbers',
                      icon: Icons.phone_outlined,
                      children: [
                        if (organization.contactNumbers.isEmpty && organization.phoneNumber.isEmpty)
                          const Text('No contact numbers registered', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)))
                        else if (organization.contactNumbers.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: organization.contactNumbers.map((c) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          c.label,
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                        ),
                                        Text(
                                          c.number,
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _copyToClipboard(context, c.number, c.label),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                        else
                          _buildDetailRow(
                            label: 'Primary Phone',
                            value: organization.phoneNumber,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 3: Tax & Legal Identification
                    _buildSectionContainer(
                      title: 'Tax & Legal Identification Details',
                      icon: Icons.gavel_outlined,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildIdChip(
                                context,
                                label: 'GST / VAT Number',
                                value: organization.gstNumber.isNotEmpty ? organization.gstNumber : organization.taxId,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildIdChip(
                                context,
                                label: 'CIN (Corporate ID)',
                                value: organization.cinNumber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildIdChip(
                                context,
                                label: 'PAN (Income Tax PAN)',
                                value: organization.panNumber,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildIdChip(
                                context,
                                label: 'TAN (Tax Deduction No.)',
                                value: organization.tanNumber,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 4: Directors & DIN
                    _buildSectionContainer(
                      title: 'Board of Directors & DIN',
                      icon: Icons.people_outline_rounded,
                      children: [
                        if (organization.directors.isEmpty)
                          const Text('No directors registered yet', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)))
                        else
                          Column(
                            children: organization.directors.map((d) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person, size: 15, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.name.isNotEmpty ? d.name : 'Director',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                          ),
                                          if (d.din.isNotEmpty)
                                            Text(
                                              'DIN: ${d.din}',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (d.din.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                                        tooltip: 'Copy DIN',
                                        onPressed: () => _copyToClipboard(context, d.din, 'DIN'),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 5: Incorporation & Statutory Documents
                    _buildSectionContainer(
                      title: 'Incorporation & Statutory Documents',
                      icon: Icons.folder_open_outlined,
                      children: [
                        if (organization.documents.isEmpty)
                          const Text('No statutory documents uploaded yet', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)))
                        else
                          Column(
                            children: organization.documents.map((doc) {
                              return InkWell(
                                onTap: () => _handleDownload(context, doc),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.description_rounded, size: 18, color: Color(0xFF15803D)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              doc.title,
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                            ),
                                            if (doc.fileName.isNotEmpty)
                                              Text(
                                                doc.fileName,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF414A51),
                                          side: const BorderSide(color: Color(0xFFD0D5DD)),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          minimumSize: const Size(60, 30),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: () => _handleView(context, doc),
                                        icon: const Icon(Icons.open_in_new_rounded, size: 12),
                                        label: const Text('View', style: TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: const Size(80, 30),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: () => _handleDownload(context, doc),
                                        icon: const Icon(Icons.file_download_outlined, size: 14),
                                        label: const Text('Download', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF414A51)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildIdChip(BuildContext context, {required String label, required String value}) {
    final hasVal = value.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasVal ? value : '-',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: hasVal ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              if (hasVal)
                InkWell(
                  onTap: () => _copyToClipboard(context, value, label),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isLink = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF667085)),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '-' : value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isLink ? AppColors.primary : const Color(0xFF101828),
          ),
        ),
      ],
    );
  }
}
