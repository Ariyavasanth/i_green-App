import 'package:flutter/material.dart';

/// Modal dialog matching the user reference screenshots 1 & 2.
class RejectReasonDialog extends StatefulWidget {
  final String requestNumber;
  final Function(String reason) onConfirm;

  const RejectReasonDialog({
    super.key,
    required this.requestNumber,
    required this.onConfirm,
  });

  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  final _reasonController = TextEditingController();
  bool _hasError = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _reasonController.text.trim();
    if (text.isEmpty) {
      setState(() => _hasError = true);
      return;
    }
    Navigator.of(context).pop();
    widget.onConfirm(text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      backgroundColor: Colors.white,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reason For Rejection',
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF22282D),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Type Your Reason For Rejecting this Fund Request.',
                style: TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF555E65),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _hasError ? Colors.red : const Color(0xFFCCCCCC),
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _reasonController,
                  maxLines: 4,
                  onChanged: (_) {
                    if (_hasError) setState(() => _hasError = false);
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    hintText: 'Enter rejection notes...',
                    hintStyle: TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 14,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF22282D),
                  ),
                ),
              ),
              if (_hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Please enter a valid rejection reason.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF456B75),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _submit,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF456B75),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text(
                      'REJECT',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        fontSize: 13.5,
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

