import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/tender.dart';
import '../../providers/tender_providers.dart';
import 'tender_form_screen.dart';

class TenderListScreen extends ConsumerStatefulWidget {
  const TenderListScreen({super.key});

  @override
  ConsumerState<TenderListScreen> createState() => _TenderListScreenState();
}

class _TenderListScreenState extends ConsumerState<TenderListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tendersAsync = ref.watch(tendersStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF414A51)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/module/project');
            }
          },
        ),
        title: const Text(
          'TENDERS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF414A51),
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TenderFormScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('NEW TENDER'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFF718096), size: 20),
                      hintText: 'Search by Tender ID, Title, Client...',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFFA0AEC0)),
                      filled: true,
                      fillColor: const Color(0xFFF7FAFC),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF9CC70A), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: tendersAsync.when(
              data: (tenders) {
                final filtered = tenders.where((t) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return t.tenderId.toLowerCase().contains(q) ||
                      t.title.toLowerCase().contains(q) ||
                      t.clientName.toLowerCase().contains(q) ||
                      t.tenderType.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 14),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No Tenders Created Yet'
                              : 'No matching tenders found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_searchQuery.isEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9CC70A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TenderFormScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('CREATE FIRST TENDER'),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildTenderCard(context, item);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
              ),
              error: (err, _) => Center(
                child: Text('Error loading tenders: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenderCard(BuildContext context, Tender tender) {
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tender.tenderId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF414A51),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF414A51).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tender.tenderType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF414A51),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF414A51)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TenderFormScreen(tender: tender),
                    ),
                  );
                },
                tooltip: 'Edit Tender',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (tender.title.isNotEmpty || tender.clientName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              tender.title.isNotEmpty ? tender.title : tender.clientName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D3748),
              ),
            ),
            if (tender.title.isNotEmpty && tender.clientName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Client: ${tender.clientName}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
              ),
            ],
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F2ED)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              if (tender.tenderAmount > 0)
                _InfoItem(
                  label: 'Tender Amount',
                  value: currencyFmt.format(tender.tenderAmount),
                  valueColor: const Color(0xFF9CC70A),
                  bold: true,
                ),
              _InfoItem(
                label: 'Qualified',
                value: tender.qualified,
              ),
              if (tender.openingDate != null)
                _InfoItem(
                  label: 'Opening Date',
                  value: dateFmt.format(tender.openingDate!),
                ),
              if (tender.closingDate != null)
                _InfoItem(
                  label: 'Closing Date',
                  value: dateFmt.format(tender.closingDate!),
                ),
              if (tender.tenderSpecDocuments.isNotEmpty)
                _InfoItem(
                  label: 'Spec Files',
                  value: '${tender.tenderSpecDocuments.length}',
                ),
              if (tender.bqrDocuments.isNotEmpty)
                _InfoItem(
                  label: 'BQR Files',
                  value: '${tender.bqrDocuments.length}',
                ),
              if (tender.emdDocuments.isNotEmpty)
                _InfoItem(
                  label: 'EMD Files',
                  value: '${tender.emdDocuments.length}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF718096)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? const Color(0xFF414A51),
          ),
        ),
      ],
    );
  }
}

