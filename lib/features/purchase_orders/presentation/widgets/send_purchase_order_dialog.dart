import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../vendors/domain/vendor.dart';
import '../../domain/purchase_order.dart';
import '../../providers/purchase_order_providers.dart';
import 'purchase_order_pdf_dialog.dart';

class SendPurchaseOrderDialog extends ConsumerStatefulWidget {
  const SendPurchaseOrderDialog({
    super.key,
    required this.order,
    this.vendor,
  });

  final PurchaseOrder order;
  final Vendor? vendor;

  @override
  ConsumerState<SendPurchaseOrderDialog> createState() => _SendPurchaseOrderDialogState();
}

class _SendPurchaseOrderDialogState extends ConsumerState<SendPurchaseOrderDialog> {
  late final TextEditingController _recipientEmail;
  late final TextEditingController _ccEmail;
  late final TextEditingController _subject;
  late final TextEditingController _message;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _moneyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final defaultEmail = widget.vendor?.email.isNotEmpty == true
        ? widget.vendor!.email
        : 'orders@${widget.order.vendorName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}.com';

    _recipientEmail = TextEditingController(text: defaultEmail);
    _ccEmail = TextEditingController(text: 'purchasing@igreentech.com');
    _subject = TextEditingController(text: 'Purchase Order ${widget.order.number} from IGreen Technologies');

    final deliveryStr = widget.order.deliveryDate != null ? _dateFormat.format(widget.order.deliveryDate!) : 'As agreed';

    _message = TextEditingController(
      text: '''Dear ${widget.order.vendorName},

Please find attached Purchase Order ${widget.order.number} from IGreen Technologies for your review and processing.

Order Summary:
------------------------------------------
Purchase Order #: ${widget.order.number}
Order Date: ${_dateFormat.format(widget.order.date)}
Expected Delivery: $deliveryStr
Total Order Value: ${_moneyFormat.format(widget.order.amount)}

Kindly confirm receipt of this purchase order and advise estimated delivery schedule.

Best regards,

Procurement Department
IGreen Technologies
No. 25, Industrial Estate, Chennai - 600058
Phone: +91 98765 43210
Email: procurement@igreentech.com''',
    );
  }

  @override
  void dispose() {
    _recipientEmail.dispose();
    _ccEmail.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _recipientEmail.text.trim(),
      queryParameters: {
        'subject': _subject.text.trim(),
        'body': _message.text.trim(),
      },
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      }
      await _confirmSentStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opened email client. (${e.toString()})')),
        );
      }
      await _confirmSentStatus();
    }
  }

  Future<void> _launchWhatsApp() async {
    var rawPhone = widget.vendor?.workPhone.replaceAll(RegExp(r'[^0-9]'), '') ??
        widget.vendor?.mobile.replaceAll(RegExp(r'[^0-9]'), '') ??
        '';
    if (rawPhone.length == 10) {
      rawPhone = '91$rawPhone';
    }

    final messageText =
        'Hello ${widget.order.vendorName},\n\nWe have issued Purchase Order *${widget.order.number}* for total value *${_moneyFormat.format(widget.order.amount)}*.\n\nPlease review and confirm delivery.\n\nThank you,\nIGreen Technologies';

    final nativeUrl = rawPhone.isNotEmpty
        ? 'whatsapp://send?phone=$rawPhone&text=${Uri.encodeComponent(messageText)}'
        : 'whatsapp://send?text=${Uri.encodeComponent(messageText)}';

    final webUrl = rawPhone.isNotEmpty
        ? 'https://api.whatsapp.com/send?phone=$rawPhone&text=${Uri.encodeComponent(messageText)}'
        : 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(messageText)}';

    try {
      final nativeUri = Uri.parse(nativeUrl);
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse(webUrl);
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      await _confirmSentStatus();
    } catch (e) {
      try {
        final webUri = Uri.parse(webUrl);
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        await _confirmSentStatus();
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to launch WhatsApp: $err')),
          );
        }
      }
    }
  }

  Future<void> _confirmSentStatus() async {
    setState(() => _sending = true);
    try {
      await ref.read(purchaseOrderRepositoryProvider).updatePoStatus(widget.order.id, 'SENT');
      ref.invalidate(purchaseOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase Order ${widget.order.number} marked as SENT to Vendor')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating PO status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _previewPdf() {
    showDialog(
      context: context,
      builder: (_) => PurchaseOrderPdfDialog(order: widget.order),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 480;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isNarrow) ...[
                            TextField(
                              controller: _recipientEmail,
                              decoration: _input(label: 'To (Vendor Email)*', icon: Icons.email_outlined),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _ccEmail,
                              decoration: _input(label: 'CC Email', icon: Icons.alternate_email),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _recipientEmail,
                                    decoration: _input(label: 'To (Vendor Email)*', icon: Icons.email_outlined),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _ccEmail,
                                    decoration: _input(label: 'CC Email', icon: Icons.alternate_email),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _subject,
                            decoration: _input(label: 'Subject Line*', icon: Icons.subject),
                          ),
                          const SizedBox(height: 12),
                          const Text('Email Message Body:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _message,
                            maxLines: 5,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _attachmentBadge(isNarrow),
                        ],
                      );
                    },
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.active,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Row(
          children: [
            const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Send Purchase Order — ${widget.order.number}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  Widget _attachmentBadge(bool isNarrow) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.order.number}.pdf',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_moneyFormat.format(widget.order.amount)} • Standard ERP Template',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _previewPdf,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.remove_red_eye, size: 14),
                        label: const Text('Preview PDF', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.order.number}.pdf', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${_moneyFormat.format(widget.order.amount)}  •  Standard ERP Template', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _previewPdf,
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.remove_red_eye, size: 14),
                    label: const Text('Preview PDF', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
      );

  Widget _footer() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _sending ? null : _launchWhatsApp,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
            ),
            OutlinedButton.icon(
              onPressed: _sending ? null : _launchEmail,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.email_outlined, size: 16),
              label: const Text('Send via Mail Client', style: TextStyle(fontSize: 12)),
            ),
            FilledButton.icon(
              onPressed: _sending ? null : _confirmSentStatus,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.active,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: Text(_sending ? 'Processing…' : 'Mark as Sent', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );

  InputDecoration _input({required String label, required IconData icon}) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: const OutlineInputBorder(),
      );
}
