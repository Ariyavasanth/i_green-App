import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../employee/providers/employee_providers.dart';
import '../../domain/models/project_budget.dart';
import '../../domain/models/site_project.dart';
import '../../providers/project_providers.dart';

class ProjectBudgetScreen extends ConsumerStatefulWidget {
  const ProjectBudgetScreen({
    super.key,
    required this.projectId,
    this.initialProject,
  });

  final String projectId;
  final SiteProject? initialProject;

  @override
  ConsumerState<ProjectBudgetScreen> createState() => _ProjectBudgetScreenState();
}

class _ProjectBudgetScreenState extends ConsumerState<ProjectBudgetScreen> {
  SiteProject? _project;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  BudgetStatus _status = BudgetStatus.draft;
  int _revision = 1;
  final List<ProjectBudgetItem> _items = [];

  // Controllers for Add Head form
  String _selectedCategory = 'Material Procurement';
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _pctCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  static const List<String> _standardCategories = [
    'Material Procurement',
    'Subcontractor & Labor Services',
    'Machinery, Equipment & Fuel',
    'Permits & Statutory Fees',
    'Site Operations & Consumables',
    'Contingency Reserve',
    'Other Execution Costs',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialProject != null) {
      _loadProjectData(widget.initialProject!);
    } else {
      _fetchProject();
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _pctCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _loadProjectData(SiteProject project) {
    setState(() {
      _project = project;
      _isLoading = false;
      _items.clear();

      final existingBudget = project.budget;
      if (existingBudget != null) {
        _status = existingBudget.status;
        _revision = existingBudget.revision;
        _items.addAll(existingBudget.items);
      } else {
        _status = BudgetStatus.draft;
        _revision = 1;
      }
    });
  }

  Future<void> _fetchProject() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(projectRepositoryProvider);
      final p = await repo.getProjectById(widget.projectId);
      if (!mounted) return;
      if (p != null) {
        _loadProjectData(p);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Project not found';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load project: $e';
      });
    }
  }

  double get _contractValue => _project?.actualProjectValue ?? 0.0;

  double get _totalBudget =>
      _items.fold(0.0, (acc, item) => acc + item.allocatedAmount);

  double get _plannedProfit => _contractValue - _totalBudget;

  double get _plannedMarginPct {
    if (_contractValue <= 0) return 0.0;
    return ((_plannedProfit / _contractValue) * 10000).roundToDouble() / 100;
  }

  void _calcPct() {
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (_contractValue > 0) {
      final pct = ((amt / _contractValue) * 10000).roundToDouble() / 100;
      _pctCtrl.text = '$pct %';
    } else {
      _pctCtrl.text = '0.0 %';
    }
  }

  void _addItem() {
    final desc = _descCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final remarks = _remarksCtrl.text.trim();

    if (desc.isEmpty) {
      _showToast('Please enter a description for this budget head');
      return;
    }
    if (amt <= 0) {
      _showToast('Please enter an allocated budget amount greater than zero');
      return;
    }

    final item = ProjectBudgetItem.create(
      category: _selectedCategory,
      description: desc,
      allocatedAmount: amt,
      contractValue: _contractValue,
      remarks: remarks,
    );

    setState(() {
      _items.add(item);
      _descCtrl.clear();
      _amountCtrl.clear();
      _pctCtrl.clear();
      _remarksCtrl.clear();
    });

    _showToast('Added budget head: $desc', isError: false);
  }

  void _removeItem(ProjectBudgetItem item) {
    setState(() {
      _items.removeWhere((i) => i.id == item.id);
    });
    _showToast('Removed budget head "${item.description}"', isError: false);
  }

  Future<void> _editItemDialog(ProjectBudgetItem item) async {
    String category = item.category;
    final descC = TextEditingController(text: item.description);
    final amtC = TextEditingController(text: item.allocatedAmount.toString());
    final remarksC = TextEditingController(text: item.remarks);

    final result = await showDialog<ProjectBudgetItem?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Color(0xFF414A51), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Edit Budget Head',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF414A51),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: category,
                        decoration: _inputDeco('Category *'),
                        items: _standardCategories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descC,
                        decoration: _inputDeco('Head Description *'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amtC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: _inputDeco('Allocated Amount (₹) *', prefixText: '₹ '),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarksC,
                        decoration: _inputDeco('Remarks / Calculation Basis (optional)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final d = descC.text.trim();
                    final a = double.tryParse(amtC.text.trim()) ?? 0.0;
                    if (d.isEmpty || a <= 0) return;

                    final updated = item.copyWith(
                      category: category,
                      description: d,
                      allocatedAmount: a,
                      percentageOfContract: _contractValue > 0
                          ? ((a / _contractValue) * 10000).roundToDouble() / 100
                          : 0.0,
                      remarks: remarksC.text.trim(),
                    );
                    Navigator.pop(ctx, updated);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        final idx = _items.indexWhere((i) => i.id == result.id);
        if (idx != -1) _items[idx] = result;
      });
      _showToast('Updated "${result.description}"', isError: false);
    }
  }

  void _prefillFromBreakdown() {
    if (_project == null) return;

    final matVal = _project!.totalMaterialsValue;
    final serVal = _project!.totalServicesValue;

    if (matVal <= 0 && serVal <= 0) {
      _showToast('No materials or services breakdown items found for this project.');
      return;
    }

    setState(() {
      // Suggesting 85% cost allocation for materials (15% procurement buffer)
      if (matVal > 0) {
        final matBudget = (matVal * 0.85 * 100).roundToDouble() / 100;
        _items.add(
          ProjectBudgetItem.create(
            category: 'Material Procurement',
            description: 'Materials & Equipment Procurement (from BOQ Breakdown)',
            allocatedAmount: matBudget,
            contractValue: _contractValue,
            remarks: 'Estimated @ 85% of breakdown selling value (₹${_currencyFormatter.format(matVal)})',
          ),
        );
      }

      // Suggesting 80% cost allocation for labor/subcontractor services
      if (serVal > 0) {
        final serBudget = (serVal * 0.80 * 100).roundToDouble() / 100;
        _items.add(
          ProjectBudgetItem.create(
            category: 'Subcontractor & Labor Services',
            description: 'HDD, Civil & Installation Works (from BOQ Breakdown)',
            allocatedAmount: serBudget,
            contractValue: _contractValue,
            remarks: 'Estimated @ 80% of breakdown service value (₹${_currencyFormatter.format(serVal)})',
          ),
        );
      }

      // Add a standard 3% contingency
      if (_contractValue > 0) {
        final contingency = (_contractValue * 0.03 * 100).roundToDouble() / 100;
        _items.add(
          ProjectBudgetItem.create(
            category: 'Contingency Reserve',
            description: 'Unforeseen Site Variances & Contingency (3%)',
            allocatedAmount: contingency,
            contractValue: _contractValue,
            remarks: 'Standard 3% contingency reserve',
          ),
        );
      }
    });

    _showToast('Pre-filled baseline budget heads from Breakdown!', isError: false);
  }

  Future<void> _saveBudget({BudgetStatus? newStatus}) async {
    if (_project == null) return;

    setState(() => _isSaving = true);
    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final repo = ref.read(projectRepositoryProvider);

      final statusToSave = newStatus ?? _status;
      final now = DateTime.now();

      final updatedBudget = ProjectBudget(
        status: statusToSave,
        revision: statusToSave == BudgetStatus.approved ? _revision : _revision,
        items: List.from(_items),
        createdAt: _project!.budget?.createdAt ?? now,
        updatedAt: now,
        updatedBy: currentEmp != null ? currentEmp.id.toString() : _project!.updatedBy,
        approvedBy: statusToSave == BudgetStatus.approved
            ? (currentEmp?.fullName ?? 'Authorized Manager')
            : _project!.budget?.approvedBy,
        approvedAt: statusToSave == BudgetStatus.approved
            ? now
            : _project!.budget?.approvedAt,
      );

      await repo.updateProjectBudget(
        projectId: _project!.id,
        budget: updatedBudget,
        contractValue: _contractValue,
        auditEmployeeId: currentEmp != null ? currentEmp.id.toString() : _project!.updatedBy,
        auditEmployeeName: currentEmp?.fullName ?? _project!.updatedByName,
        auditDesignation: currentEmp?.designation ?? 'Project Manager',
        auditNote:
            'Project Budget ${statusToSave.label}: Total ₹${_currencyFormatter.format(_totalBudget)}, '
            'Planned Profit ₹${_currencyFormatter.format(_plannedProfit)} ($_plannedMarginPct%)',
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _status = statusToSave;
        _project = _project!.copyWith(budget: updatedBudget);
      });

      _showToast(
        statusToSave == BudgetStatus.approved
            ? 'Project Budget Approved successfully!'
            : 'Project Budget saved as ${statusToSave.label}!',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showToast('Failed to save budget: $e', isError: true);
    }
  }

  void _showToast(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF414A51),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
        borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6F3),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
        ),
      );
    }

    if (_errorMessage != null || _project == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F3),
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51)),
            onPressed: () => context.pop(),
          ),
          title: const Text('Project Budget', style: TextStyle(color: Color(0xFF414A51))),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_errorMessage ?? 'Project not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF414A51)),
                onPressed: _fetchProject,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51)),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'PROJECT BUDGET & PROFITABILITY',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF414A51),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _status == BudgetStatus.approved
                        ? Colors.green.shade50
                        : (_status == BudgetStatus.submitted
                            ? Colors.blue.shade50
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _status == BudgetStatus.approved
                          ? Colors.green.shade300
                          : (_status == BudgetStatus.submitted
                              ? Colors.blue.shade300
                              : Colors.grey.shade400),
                    ),
                  ),
                  child: Text(
                    _status.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _status == BudgetStatus.approved
                          ? Colors.green.shade800
                          : (_status == BudgetStatus.submitted
                              ? Colors.blue.shade800
                              : const Color(0xFF414A51)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${_project!.projectCode} • ${_project!.clientName}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF414A51),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving ? null : () => _saveBudget(newStatus: BudgetStatus.draft),
              child: const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: const Color(0xFF414A51),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving
                  ? null
                  : () => _saveBudget(
                        newStatus: _status == BudgetStatus.approved
                            ? BudgetStatus.approved
                            : BudgetStatus.approved,
                      ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF414A51),
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 16),
              label: Text(
                _isSaving ? 'Saving...' : 'Approve Budget',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Profitability Metrics Row ───
            _buildProfitabilityCards(isMobile),
            const SizedBox(height: 16),

            // ─── Main Budget Container ───
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pre-fill Helper Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_outlined, size: 18, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Breakdown Baseline: Supplies ₹${_currencyFormatter.format(_project!.totalMaterialsValue)} • '
                            'Services ₹${_currencyFormatter.format(_project!.totalServicesValue)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: _prefillFromBreakdown,
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Auto-fill Baseline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Add Budget Head Form
                  _buildAddHeadSection(isMobile),
                  const SizedBox(height: 20),

                  // Allocation Table Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SANCTIONED BUDGET ALLOCATIONS',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF414A51),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Total Sanctioned: ${_currencyFormatter.format(_totalBudget)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF414A51),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Table of items
                  _buildAllocationsTable(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Profitability Metrics Cards ───
  Widget _buildProfitabilityCards(bool isMobile) {
    final profit = _plannedProfit;
    final isLoss = profit < 0;
    final isHealthy = _plannedMarginPct >= 15.0;

    final List<Widget> cards = [
      _buildMetricCard(
        title: 'Contract / WO Value',
        value: _currencyFormatter.format(_contractValue),
        icon: Icons.assignment_outlined,
        accentColor: const Color(0xFF414A51),
        subtitle: 'Target Project Revenue',
      ),
      _buildMetricCard(
        title: 'Total Sanctioned Budget',
        value: _currencyFormatter.format(_totalBudget),
        icon: Icons.account_balance_wallet_outlined,
        accentColor: isLoss ? Colors.redAccent : const Color(0xFF0284C7),
        subtitle: '${_items.length} budget heads',
      ),
      _buildMetricCard(
        title: 'Planned Gross Profit',
        value: _currencyFormatter.format(profit),
        icon: Icons.trending_up_rounded,
        accentColor: isLoss ? Colors.redAccent : const Color(0xFF9CC70A),
        subtitleWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isLoss ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isLoss ? 'Projected Deficit / Loss' : 'Gross Margin',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isLoss ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        ),
      ),
      _buildMetricCard(
        title: 'Planned Profit Margin',
        value: '$_plannedMarginPct %',
        icon: Icons.pie_chart_outline_rounded,
        accentColor: isLoss
            ? Colors.redAccent
            : (isHealthy ? const Color(0xFF9CC70A) : Colors.orangeAccent),
        subtitleWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isLoss
                ? Colors.red.shade50
                : (isHealthy ? Colors.green.shade50 : Colors.orange.shade50),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isLoss
                ? 'OVER-BUDGET'
                : (isHealthy ? 'Healthy Target Margin' : 'Low Margin (<15%)'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isLoss
                  ? Colors.red.shade700
                  : (isHealthy ? Colors.green.shade700 : Colors.orange.shade800),
            ),
          ),
        ),
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (3 * 12)) / 4;
        final cardWidgets = <Widget>[];
        for (int i = 0; i < cards.length; i++) {
          cardWidgets.add(
            Container(
              width: cardWidth,
              margin: EdgeInsets.only(right: i < cards.length - 1 ? 12 : 0),
              child: cards[i],
            ),
          );
        }
        return Row(children: cardWidgets);
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    String? subtitle,
    Widget? subtitleWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          if (subtitleWidget != null)
            subtitleWidget
          else if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
        ],
      ),
    );
  }

  // ─── Add Head Section ───
  Widget _buildAddHeadSection(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF414A51)),
              SizedBox(width: 6),
              Text(
                'Add Budget Allocation Head',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF414A51),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMobile) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedCategory,
              decoration: _inputDeco('Cost Category *'),
              items: _standardCategories.map((c) {
                return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              decoration: _inputDeco('Description / Head Name *', hint: 'e.g. HDD Operator Team, Raw Materials'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: _inputDeco('Allocated Amount *', prefixText: '₹ '),
                    onChanged: (_) => _calcPct(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _pctCtrl,
                    readOnly: true,
                    decoration: _inputDeco('% of WO'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _remarksCtrl,
                    decoration: _inputDeco('Remarks / Basis of Cost (optional)'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ] else ...[
            // Desktop horizontal row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedCategory,
                    decoration: _inputDeco('Cost Category *'),
                    items: _standardCategories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _descCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Head Description *', hint: 'e.g. HDD Operator Team, Raw Materials'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Allocated Amount *', prefixText: '₹ '),
                    onChanged: (_) => _calcPct(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _pctCtrl,
                    readOnly: true,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('% of WO'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Remarks / Basis of Cost (optional)'),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Allocations Table ───
  Widget _buildAllocationsTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = math.max(constraints.maxWidth, 700.0);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Table(
                border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(4),
                  3: FlexColumnWidth(2.5),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(3),
                  6: FixedColumnWidth(90),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFF414A51)),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        child: Text(
                          '#',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text(
                          'Category',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text(
                          'Description',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text(
                          'Allocated (₹)',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text(
                          '% WO',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text(
                          'Remarks',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                        child: Text(
                          'Action',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  if (_items.isEmpty)
                    TableRow(
                      children: [
                        const SizedBox(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
                          child: Text(
                            'No budget allocation heads added yet. Use the form above or click "Auto-fill Baseline".',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                          ),
                        ),
                        const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                      ],
                    )
                  else
                    ..._items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return TableRow(
                        decoration: BoxDecoration(
                          color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: Text(
                              '${idx + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              item.category,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              item.description,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              _currencyFormatter.format(item.allocatedAmount),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              '${item.percentageOfContract.toStringAsFixed(1)} %',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              item.remarks.isEmpty ? '-' : item.remarks,
                              style: TextStyle(
                                fontSize: 11,
                                color: item.remarks.isEmpty ? Colors.grey.shade400 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  color: const Color(0xFF414A51),
                                  tooltip: 'Edit allocation',
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => _editItemDialog(item),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  color: Colors.red.shade600,
                                  tooltip: 'Remove allocation',
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => _removeItem(item),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
