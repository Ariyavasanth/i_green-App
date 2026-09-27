import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/organization.dart';

class OrganizationShareDialog extends StatefulWidget {
  const OrganizationShareDialog({
    required this.organization,
    super.key,
  });

  final Organization organization;

  static Future<void> show(BuildContext context, Organization organization) {
    return showDialog<void>(
      context: context,
      builder: (context) => OrganizationShareDialog(organization: organization),
    );
  }

  @override
  State<OrganizationShareDialog> createState() =>
      _OrganizationShareDialogState();
}

class _OrganizationShareDialogState extends State<OrganizationShareDialog> {
  late final Map<String, bool> _selectedFields;

  @override
  void initState() {
    super.initState();
    // Default: select key useful fields
    _selectedFields = {
      'Organization Name': true,
      'Business Type': widget.organization.businessType.isNotEmpty,
      'Industry Type': widget.organization.industryType.isNotEmpty,
      'Business Unit(s)': widget.organization.businessUnits.isNotEmpty,
      'Location(s)': widget.organization.locations.isNotEmpty,
      'Address': widget.organization.address.isNotEmpty,
      'Phone Number': widget.organization.phoneNumber.isNotEmpty ||
          widget.organization.contactNumbers.isNotEmpty,
      'Email Address': widget.organization.emailAddress.isNotEmpty,
      'Website': widget.organization.website.isNotEmpty,
      'GST / VAT Number': widget.organization.gstNumber.isNotEmpty ||
          widget.organization.taxId.isNotEmpty,
      'CIN Number': widget.organization.cinNumber.isNotEmpty,
      'PAN Number': widget.organization.panNumber.isNotEmpty,
      'TAN Number': widget.organization.tanNumber.isNotEmpty,
      'Directors / DIN': widget.organization.directors.isNotEmpty,
    };
  }

  String _getFieldValue(String key) {
    final org = widget.organization;
    switch (key) {
      case 'Organization Name':
        return org.name;
      case 'Business Type':
        return org.businessType;
      case 'Industry Type':
        return org.industryType;
      case 'Business Unit(s)':
        return org.businessUnits;
      case 'Location(s)':
        return org.locations;
      case 'Address':
        final addr = org.address;
        final pin = org.pincode.isNotEmpty ? ' - ${org.pincode}' : '';
        return addr.isNotEmpty ? '$addr$pin' : '';
      case 'Phone Number':
        if (org.contactNumbers.isNotEmpty) {
          return org.contactNumbers
              .map((c) => '${c.label}: ${c.number}')
              .join(', ');
        }
        return org.phoneNumber;
      case 'Email Address':
        return org.emailAddress;
      case 'Website':
        return org.website;
      case 'GST / VAT Number':
        return org.gstNumber.isNotEmpty ? org.gstNumber : org.taxId;
      case 'CIN Number':
        return org.cinNumber;
      case 'PAN Number':
        return org.panNumber;
      case 'TAN Number':
        return org.tanNumber;
      case 'Directors / DIN':
        return org.directors.isNotEmpty
            ? org.directors
                .map((d) => d.din.isNotEmpty ? '${d.name} (${d.din})' : d.name)
                .join(', ')
            : '';
      default:
        return '';
    }
  }

  String _generateShareText() {
    final buffer = StringBuffer();
    final orgName = widget.organization.name;
    buffer.writeln('🏢 *$orgName*');
    buffer.writeln('────────────────────────');

    for (final entry in _selectedFields.entries) {
      if (entry.key == 'Organization Name') continue;
      if (entry.value) {
        final val = _getFieldValue(entry.key);
        if (val.isNotEmpty) {
          buffer.writeln('*${entry.key}:* $val');
        }
      }
    }

    buffer.writeln('────────────────────────');
    return buffer.toString().trim();
  }

  void _selectAll(bool select) {
    setState(() {
      for (final key in _selectedFields.keys) {
        final val = _getFieldValue(key);
        _selectedFields[key] = select && val.isNotEmpty;
      }
    });
  }

  Future<void> _copyToClipboard() async {
    final text = _generateShareText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareOnWhatsApp() async {
    final text = _generateShareText();
    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) Navigator.of(context).pop();
    } else {
      await _copyToClipboard();
    }
  }

  Future<void> _nativeShare() async {
    // Triggers copy + launch intent or copy fallback with helpful alert
    await _copyToClipboard();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final shareText = _generateShareText();
    final anySelected = _selectedFields.values.any((v) => v);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.share_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share Organization',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        Text(
                          widget.organization.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF667085)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEAECF0)),
              const SizedBox(height: 10),

              // Selection Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select details to include:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _selectAll(true),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Select All',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const Text(' | ', style: TextStyle(color: Color(0xFFD0D5DD), fontSize: 11)),
                      InkWell(
                        onTap: () => _selectAll(false),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fields Checkbox List
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEAECF0)),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: _selectedFields.keys.map((fieldKey) {
                      final val = _getFieldValue(fieldKey);
                      final isAvailable = val.isNotEmpty;
                      final isChecked = _selectedFields[fieldKey] ?? false;

                      return InkWell(
                        onTap: isAvailable
                            ? () {
                                setState(() {
                                  _selectedFields[fieldKey] = !isChecked;
                                });
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              IgnorePointer(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: isChecked,
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: isAvailable ? (_) {} : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      fieldKey,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isChecked
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isAvailable
                                            ? (isChecked
                                                ? const Color(0xFF101828)
                                                : const Color(0xFF475467))
                                            : const Color(0xFF98A2B3),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        isAvailable ? '($val)' : '(Not set)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isAvailable
                                              ? const Color(0xFF667085)
                                              : const Color(0xFF98A2B3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Preview snippet
              if (anySelected) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEAECF0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preview:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475467),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shareText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF344054),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Sharing Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: anySelected ? _copyToClipboard : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      side: const BorderSide(color: Color(0xFFD0D5DD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF344054)),
                    label: const Text(
                      'Copy Text',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: anySelected ? _shareOnWhatsApp : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: anySelected ? _nativeShare : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text(
                      'Share',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
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
