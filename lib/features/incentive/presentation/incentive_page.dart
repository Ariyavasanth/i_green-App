import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../authentication/providers/authentication_providers.dart';

import '../domain/incentive_request.dart';
import '../domain/product_rate.dart';
import '../providers/incentive_providers.dart';

class IncentivePage extends ConsumerStatefulWidget {
  const IncentivePage({super.key});

  @override
  ConsumerState<IncentivePage> createState() => _IncentivePageState();
}

class _IncentivePageState extends ConsumerState<IncentivePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _siteController = TextEditingController(text: 'Site A');
  String _selectedProduct = 'Duct';
  String _selectedDesignation = 'Operator';
  final TextEditingController _metersController = TextEditingController(text: '50');
  final TextEditingController _remarksController = TextEditingController();

  final List<String> _designations = ['Operator', 'Tracker', 'Supervisor'];

  @override
  void dispose() {
    _siteController.dispose();
    _metersController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _currentRate {
    return calculateIncentiveRate(_selectedProduct, _selectedDesignation);
  }

  double get _expectedIncentive {
    final meters = double.tryParse(_metersController.text.trim()) ?? 0.0;
    return meters * _currentRate;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final meters = double.tryParse(_metersController.text.trim()) ?? 0.0;
    final rate = _currentRate;
    final amount = meters * rate;

    final userEmail = ref.read(currentUserEmailProvider) ?? 'Employee';
    final empName = userEmail.contains('@')
        ? userEmail.split('@').first.replaceFirst(
              userEmail[0],
              userEmail[0].toUpperCase(),
            )
        : userEmail.isEmpty ? 'Ramesh' : userEmail;

    final newRequest = IncentiveRequest(
      requestId: 'INC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      employeeName: empName,
      designation: _selectedDesignation,
      site: _siteController.text.trim().isEmpty ? 'Site A' : _siteController.text.trim(),
      productName: _selectedProduct,
      meters: meters,
      rate: rate,
      amount: amount,
      status: 'Pending',
      remarks: _remarksController.text.trim().isEmpty ? '-' : _remarksController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      await ref.read(incentiveRepositoryProvider).createRequest(newRequest);
      ref.invalidate(allIncentiveRequestsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incentive request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _remarksController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelRequest(int id) async {
    try {
      await ref.read(incentiveRepositoryProvider).cancelRequest(id);
      ref.invalidate(allIncentiveRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allIncentiveRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              children: [
                const Icon(Icons.request_quote_outlined, color: AppColors.active, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Incentive Request',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Form & Request Tracking Section
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildFormCard()),
                          const SizedBox(width: 24),
                          Expanded(flex: 7, child: _buildRequestsSummaryCard(requestsAsync)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildFormCard(),
                          const SizedBox(height: 24),
                          _buildRequestsSummaryCard(requestsAsync),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final rate = _currentRate;
    final expected = _expectedIncentive;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Incentive Request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 20),

              // Designation Selector (Operator / Tracker / Supervisor)
              const Text(
                'Employee Designation',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: _designations.map((des) {
                    final selected = _selectedDesignation == des;
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDesignation = des;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.active : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            des,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              color: selected ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Project / Site Input Box
              const Text(
                'Project / Site',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _siteController,
                decoration: InputDecoration(
                  hintText: 'Enter project / site',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.active),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter project / site';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Product Dropdown (replaces Work Type from Image 2)
              const Text(
                'Product',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedProduct,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: defaultProductRates.map((p) {
                  return DropdownMenuItem(
                    value: p.productName,
                    child: Text(
                      p.productName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedProduct = val);
                },
              ),
              const SizedBox(height: 16),

              // Total Meters Completed (in meters)
              const Text(
                'Total Meters Completed (in meters)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _metersController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: const Padding(
                    padding: EdgeInsets.only(right: 12, top: 12),
                    child: Text(
                      'm',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter completed meters';
                  if (double.tryParse(val.trim()) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Incentive Rate (per meter)
              const Text(
                'Incentive Rate (per meter)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  '₹${rate.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Expected Incentive Banner (matching Image 2)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expected Incentive',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${expected.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Remarks (Optional)
              const Text(
                'Remarks (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _remarksController,
                decoration: InputDecoration(
                  hintText: 'Enter remarks',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Send Request Button (matching Image 2 style)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'Send Request',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsSummaryCard(AsyncValue<List<IncentiveRequest>> requestsAsync) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Incentive Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                IconButton(
                  onPressed: () => ref.invalidate(allIncentiveRequestsProvider),
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),

            requestsAsync.when(
              data: (allRequests) {
                final pendingCount = allRequests.where((r) => r.status == 'Pending').length;
                final approvedCount = allRequests.where((r) => r.status == 'Approved').length;
                final rejectedCount = allRequests.where((r) => r.status == 'Rejected').length;

                return Column(
                  children: [
                    // Stat summary pills
                    Row(
                      children: [
                        _buildStatBadge('Pending', '$pendingCount', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
                        const SizedBox(width: 8),
                        _buildStatBadge('Approved', '$approvedCount', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        _buildStatBadge('Rejected', '$rejectedCount', const Color(0xFFFFEBEE), const Color(0xFFC62828)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (allRequests.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No incentive requests submitted yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: allRequests.length,
                        separatorBuilder: (context, index) => const Divider(height: 20),
                        itemBuilder: (context, index) {
                          final req = allRequests[index];
                          return _buildRequestRowItem(req);
                        },
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text('Error loading requests: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color bg, Color textCol) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textCol),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestRowItem(IncentiveRequest req) {
    final isPending = req.status == 'Pending';
    final isApproved = req.status == 'Approved';
    final isRejected = req.status == 'Rejected';

    Color statusBg = Colors.grey.shade200;
    Color statusText = Colors.grey.shade700;

    if (isPending) {
      statusBg = const Color(0xFFFFF3E0);
      statusText = const Color(0xFFF57C00);
    } else if (isApproved) {
      statusBg = const Color(0xFFE8F5E9);
      statusText = const Color(0xFF2E7D32);
    } else if (isRejected) {
      statusBg = const Color(0xFFFFEBEE);
      statusText = const Color(0xFFC62828);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${req.productName} • ${req.site}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  req.status,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meters: ${req.meters.toInt()}m  |  Rate: ₹${req.rate.toInt()}/m',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                'Expected: ₹${req.amount.toInt()}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          if (isApproved && req.approvedAmount != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  Text(
                    'Approved Amount: ₹${req.approvedAmount?.toInt()}  (Verified Meters: ${req.verifiedMeters?.toInt()}m)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),
          ],

          if (isPending && req.id != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _cancelRequest(req.id!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 14),
                label: const Text('Cancel Request', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
