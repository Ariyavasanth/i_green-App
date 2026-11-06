import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../employee/providers/employee_providers.dart';
import '../../domain/models/project_breakdown_item.dart';
import '../../domain/models/site_project.dart';
import '../../providers/project_providers.dart';

class ProjectBreakdownScreen extends ConsumerStatefulWidget {
  const ProjectBreakdownScreen({
    super.key,
    required this.projectId,
    this.initialProject,
  });

  final String projectId;
  final SiteProject? initialProject;

  @override
  ConsumerState<ProjectBreakdownScreen> createState() =>
      _ProjectBreakdownScreenState();
}

class _ProjectBreakdownScreenState
    extends ConsumerState<ProjectBreakdownScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  SiteProject? _project;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final List<ProjectBreakdownItem> _materials = [];
  final List<ProjectBreakdownItem> _services = [];

  // Controllers for Add Item form
  final _descCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.initialProject != null) {
      _loadProjectData(widget.initialProject!);
    } else {
      _fetchProject();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descCtrl.dispose();
    _unitCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _loadProjectData(SiteProject project) {
    setState(() {
      _project = project;
      _isLoading = false;
      _materials.clear();
      _services.clear();

      _materials.addAll(project.breakdownMaterials);
      _services.addAll(project.breakdownServices);

      // Backwards-compatibility: If breakdown was empty but tenderDescriptions had items,
      // load them into materials by default.
      if (_materials.isEmpty &&
          _services.isEmpty &&
          project.tenderDescriptions.isNotEmpty) {
        for (final td in project.tenderDescriptions) {
          _materials.add(
            ProjectBreakdownItem.create(
              description: td.description,
              unit: td.unit,
              quantity: td.quantity,
              rate: td.rate,
              type: BreakdownItemType.material,
            ),
          );
        }
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

  double get _totalMaterials =>
      _materials.fold(0.0, (sum, i) => sum + i.amount);

  double get _totalServices =>
      _services.fold(0.0, (sum, i) => sum + i.amount);

  double get _totalBreakdown => _totalMaterials + _totalServices;

  double get _contractValue => _project?.actualProjectValue ?? 0.0;

  double get _variance => _contractValue - _totalBreakdown;

  void _calcAmount() {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final amount = (qty * rate * 100).roundToDouble() / 100;
    _amountCtrl.text = _currencyFormatter.format(amount).replaceAll('₹ ', '');
  }

  void _addItem() {
    final desc = _descCtrl.text.trim();
    final unit = _unitCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final remarks = _remarksCtrl.text.trim();

    if (desc.isEmpty) {
      _showToast('Please enter an item description');
      return;
    }
    if (unit.isEmpty) {
      _showToast('Please specify a unit');
      return;
    }
    if (qty <= 0) {
      _showToast('Please enter a valid quantity greater than zero');
      return;
    }
    if (rate <= 0) {
      _showToast('Please enter a valid rate greater than zero');
      return;
    }

    final isMaterial = _tabController.index == 0;
    final item = ProjectBreakdownItem.create(
      description: desc,
      unit: unit,
      quantity: qty,
      rate: rate,
      type: isMaterial ? BreakdownItemType.material : BreakdownItemType.service,
      remarks: remarks,
    );

    setState(() {
      if (isMaterial) {
        _materials.add(item);
      } else {
        _services.add(item);
      }
      _descCtrl.clear();
      _qtyCtrl.clear();
      _rateCtrl.clear();
      _amountCtrl.clear();
      _remarksCtrl.clear();
    });

    _showToast(
      'Added ${isMaterial ? 'Material' : 'Service'}: $desc',
      isError: false,
    );
  }

  void _removeItem(ProjectBreakdownItem item) {
    setState(() {
      if (item.type == BreakdownItemType.material) {
        _materials.removeWhere((i) => i.id == item.id);
      } else {
        _services.removeWhere((i) => i.id == item.id);
      }
    });
    _showToast('Removed "${item.description}"', isError: false);
  }

  Future<void> _editItemDialog(ProjectBreakdownItem item) async {
    final descC = TextEditingController(text: item.description);
    final unitC = TextEditingController(text: item.unit);
    final qtyC = TextEditingController(text: item.quantity.toString());
    final rateC = TextEditingController(text: item.rate.toString());
    final amtC = TextEditingController(
      text: _currencyFormatter.format(item.amount).replaceAll('₹ ', ''),
    );
    final remarksC = TextEditingController(text: item.remarks);

    void calcDialogAmt() {
      final q = double.tryParse(qtyC.text.trim()) ?? 0.0;
      final r = double.tryParse(rateC.text.trim()) ?? 0.0;
      final a = (q * r * 100).roundToDouble() / 100;
      amtC.text = _currencyFormatter.format(a).replaceAll('₹ ', '');
    }

    final result = await showDialog<ProjectBreakdownItem?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(
                item.type == BreakdownItemType.material
                    ? Icons.inventory_2_outlined
                    : Icons.engineering_outlined,
                color: const Color(0xFF414A51),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Edit ${item.type.label}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF414A51),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: descC,
                    decoration: _inputDeco('Description *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: unitC,
                          decoration: _inputDeco('Unit *'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: qtyC,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: _inputDeco('Quantity *'),
                          onChanged: (_) => calcDialogAmt(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: rateC,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: _inputDeco('Rate (₹) *'),
                          onChanged: (_) => calcDialogAmt(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amtC,
                    readOnly: true,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Total Amount (₹)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: remarksC,
                    decoration: _inputDeco('Remarks / Specification (optional)'),
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
                final u = unitC.text.trim();
                final q = double.tryParse(qtyC.text.trim()) ?? 0.0;
                final r = double.tryParse(rateC.text.trim()) ?? 0.0;
                if (d.isEmpty || u.isEmpty || q <= 0 || r <= 0) {
                  return;
                }
                final updated = item.copyWith(
                  description: d,
                  unit: u,
                  quantity: q,
                  rate: r,
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

    if (result != null) {
      setState(() {
        if (result.type == BreakdownItemType.material) {
          final idx = _materials.indexWhere((i) => i.id == result.id);
          if (idx != -1) _materials[idx] = result;
        } else {
          final idx = _services.indexWhere((i) => i.id == result.id);
          if (idx != -1) _services[idx] = result;
        }
      });
      _showToast('Updated "${result.description}"', isError: false);
    }
  }

  Future<void> _saveBreakdown() async {
    if (_project == null) return;

    setState(() => _isSaving = true);
    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final repo = ref.read(projectRepositoryProvider);

      await repo.updateProjectBreakdown(
        projectId: _project!.id,
        materials: _materials,
        services: _services,
        auditEmployeeId: currentEmp != null ? currentEmp.id.toString() : _project!.updatedBy,
        auditEmployeeName: currentEmp?.fullName ?? _project!.updatedByName,
        auditDesignation: currentEmp?.designation ?? 'Project Manager',
        auditNote:
            'Updated Project Breakdown: ${_materials.length} Materials (${_currencyFormatter.format(_totalMaterials)}), '
            '${_services.length} Services (${_currencyFormatter.format(_totalServices)})',
      );

      if (!mounted) return;
      _showToast('Project Breakdown saved successfully!', isError: false);
      setState(() {
        _isSaving = false;
        _project = _project!.copyWith(
          breakdownMaterials: List.from(_materials),
          breakdownServices: List.from(_services),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showToast('Failed to save breakdown: $e', isError: true);
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
          title: const Text(
            'Project Breakdown',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF414A51)),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Project not found',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
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
            const Text(
              'PROJECT BREAKDOWN – MATERIALS & SERVICES',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF414A51),
                letterSpacing: 0.3,
              ),
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
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: const Color(0xFF414A51),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving ? null : _saveBreakdown,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF414A51),
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Breakdown',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
            // ─── Summary Cards ───
            _buildSummaryMetrics(isMobile),
            const SizedBox(height: 16),

            // ─── Main Breakdown Card ───
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tab Bar Header
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF9CC70A),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFF414A51),
                      unselectedLabelColor: const Color(0xFF64748B),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.inventory_2_outlined, size: 18),
                          text: 'Materials / Supplies (${_materials.length})',
                        ),
                        Tab(
                          icon: const Icon(Icons.engineering_outlined, size: 18),
                          text: 'Services / Works (${_services.length})',
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Add Item Form
                        _buildAddItemSection(isMobile),
                        const SizedBox(height: 20),

                        // Section Heading
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _tabController.index == 0
                                  ? 'MATERIALS & SUPPLIES LIST'
                                  : 'SERVICES & WORKS LIST',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF414A51),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Subtotal: ${_currencyFormatter.format(_tabController.index == 0 ? _totalMaterials : _totalServices)}',
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
                        _buildItemsTable(
                          _tabController.index == 0 ? _materials : _services,
                          _tabController.index == 0
                              ? BreakdownItemType.material
                              : BreakdownItemType.service,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Summary Metrics Cards ───
  Widget _buildSummaryMetrics(bool isMobile) {
    final diff = _variance;
    final isExact = diff.abs() < 0.01;
    final isUnder = diff > 0.01;

    final List<Widget> cards = [
      _buildMetricCard(
        title: 'Contract / WO Value',
        value: _currencyFormatter.format(_contractValue),
        icon: Icons.assignment_outlined,
        accentColor: const Color(0xFF414A51),
        subtitle: 'From Work Order',
      ),
      _buildMetricCard(
        title: 'Total Supplies (Materials)',
        value: _currencyFormatter.format(_totalMaterials),
        icon: Icons.inventory_2_outlined,
        accentColor: const Color(0xFF0284C7),
        subtitle: '${_materials.length} line items',
      ),
      _buildMetricCard(
        title: 'Total Services (Works)',
        value: _currencyFormatter.format(_totalServices),
        icon: Icons.engineering_outlined,
        accentColor: const Color(0xFF0D9488),
        subtitle: '${_services.length} line items',
      ),
      _buildMetricCard(
        title: 'Total Breakdown Value',
        value: _currencyFormatter.format(_totalBreakdown),
        icon: Icons.account_balance_wallet_outlined,
        accentColor: const Color(0xFF9CC70A),
        subtitleWidget: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isExact
                    ? Colors.green.shade50
                    : (isUnder ? Colors.orange.shade50 : Colors.red.shade50),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isExact
                    ? '100% Balanced'
                    : (isUnder
                        ? 'Pending: ${_currencyFormatter.format(diff)}'
                        : 'Exceeds: ${_currencyFormatter.format(diff.abs())}'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isExact
                      ? Colors.green.shade700
                      : (isUnder ? Colors.orange.shade800 : Colors.red.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: c,
                ))
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

  // ─── Add Item Form Section ───
  Widget _buildAddItemSection(bool isMobile) {
    final isMaterial = _tabController.index == 0;
    final itemCategoryLabel = isMaterial ? 'Material / Supply' : 'Service / Work';

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
          Row(
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                size: 16,
                color: const Color(0xFF414A51),
              ),
              const SizedBox(width: 6),
              Text(
                'Add New $itemCategoryLabel',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF414A51),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMobile) ...[
            TextFormField(
              controller: _descCtrl,
              decoration: _inputDeco(
                'Item Description *',
                hint: isMaterial
                    ? 'e.g. PLB Duct 40/33mm, 24F OFC Cable'
                    : 'e.g. HDD Boring in Soil, Road Cutting',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _unitCtrl,
                    decoration: _inputDeco('Unit *', hint: 'm, nos, kg'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: _inputDeco('Quantity *'),
                    onChanged: (_) => _calcAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: _inputDeco('Rate (₹) *'),
                    onChanged: (_) => _calcAmount(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    readOnly: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
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
                  label: const Text(
                    'Add',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksCtrl,
              decoration: _inputDeco('Remarks / Technical Note (optional)'),
            ),
          ] else ...[
            // Desktop horizontal row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _descCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco(
                      'Item Description *',
                      hint: isMaterial
                          ? 'e.g. PLB Duct 40/33mm, 24F OFC Cable'
                          : 'e.g. HDD Boring in Soil, Road Cutting',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _unitCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Unit *', hint: 'm, nos, kg'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Quantity *'),
                    onChanged: (_) => _calcAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Rate (₹) *'),
                    onChanged: (_) => _calcAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    readOnly: true,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
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
                  label: const Text(
                    'Add',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Remarks / Technical Note (optional)'),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Items Table ───
  Widget _buildItemsTable(List<ProjectBreakdownItem> items, BreakdownItemType type) {
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
                  1: FlexColumnWidth(4),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(2),
                  4: FlexColumnWidth(2),
                  5: FlexColumnWidth(2.5),
                  6: FlexColumnWidth(3),
                  7: FixedColumnWidth(90),
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
                          'Description',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text(
                          'Unit',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text(
                          'Quantity',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text(
                          'Rate (₹)',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text(
                          'Amount (₹)',
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
                  if (items.isEmpty)
                    TableRow(
                      children: [
                        const SizedBox(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
                          child: Text(
                            'No ${type.label.toLowerCase()} added yet. Use the form above to add items.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                      ],
                    )
                  else
                    ...items.asMap().entries.map((entry) {
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
                              item.description,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              item.unit,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              NumberFormat('#,##0.##').format(item.quantity),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              NumberFormat('#,##0.00').format(item.rate),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              _currencyFormatter.format(item.amount),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              item.remarks.isEmpty ? '-' : item.remarks,
                              style: TextStyle(
                                fontSize: 11,
                                color: item.remarks.isEmpty
                                    ? Colors.grey.shade400
                                    : const Color(0xFF475569),
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
                                  tooltip: 'Edit item',
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => _editItemDialog(item),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  color: Colors.red.shade600,
                                  tooltip: 'Remove item',
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
