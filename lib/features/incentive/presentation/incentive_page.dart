import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../authentication/providers/authentication_providers.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';

import '../domain/incentive_request.dart';
import '../domain/incentive_settings.dart';
import '../domain/product_rate.dart';
import '../providers/incentive_providers.dart';

String formatIndianCurrency(num amount, {String symbol = 'Rs '}) {
  final intVal = amount.round();
  final str = intVal.abs().toString();
  if (str.length <= 3) {
    return '$symbol${intVal < 0 ? '-' : ''}$str';
  }
  final last3 = str.substring(str.length - 3);
  final otherNumbers = str.substring(0, str.length - 3);
  final formattedOther = otherNumbers.replaceAllMapped(
    RegExp(r'(\d+?)(?=(\d{2})+$)'),
    (Match m) => '${m[1]},',
  );
  return '$symbol${intVal < 0 ? '-' : ''}$formattedOther,$last3';
}

class IncentivePage extends ConsumerStatefulWidget {
  const IncentivePage({super.key});

  @override
  ConsumerState<IncentivePage> createState() => _IncentivePageState();
}

class _IncentivePageState extends ConsumerState<IncentivePage> {
  final _formKey = GlobalKey<FormState>();

  String _selectedProject = 'Site A';
  String _selectedProduct = 'Duct';
  final TextEditingController _metersController = TextEditingController(text: '50');
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String? _evidenceImage;
  bool _isCapturingImage = false;

  DateTime? _fromDate;
  DateTime? _toDate;
  String _searchQuery = '';

  final List<String> _projects = ['Site A', 'Site B', 'Project Alpha', 'Project Beta'];

  final Map<String, List<String>> _projectProductsMap = {
    'Site A': ['Duct', 'EB Cable 11kv 120sqmm', 'EB Cable 11kv 300sqmm', 'MSPIPE EB /TWAD', 'HDPE 110'],
    'Site B': ['EB Cable 33kv 3 cable', 'EB Cable 33kv single cable', 'HDPE 160 to 250 dia', 'HDPE above 500mm'],
    'Project Alpha': ['Duct', 'HDPE 250 dia above 500mm', 'EB Cable 11kv double'],
    'Project Beta': ['Eb LT cable 240 sqmm', 'EB Cable 11kv 120sqmm', 'MSPIPE EB /TWAD'],
  };

  List<String> get _availableProducts {
    return _projectProductsMap[_selectedProject] ?? defaultProductRates.map((p) => p.productName).toList();
  }

  @override
  void dispose() {
    _metersController.dispose();
    _remarksController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _getRate(String designation) {
    return calculateIncentiveRate(_selectedProduct, designation);
  }

  double _getExpectedIncentive(String designation) {
    final meters = double.tryParse(_metersController.text.trim()) ?? 0.0;
    return meters * _getRate(designation);
  }

  String _formatRequestDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _captureEvidenceImage() async {
    setState(() => _isCapturingImage = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 35,
        maxWidth: 720,
        maxHeight: 720,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final extension = image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      if (mounted) {
        setState(() => _evidenceImage = 'data:image/$extension;base64,${base64Encode(bytes)}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture image: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturingImage = false);
    }
  }

  Future<void> _submitRequest(String activeDesignation) async {
    if (!_formKey.currentState!.validate()) return;
    if (activeDesignation.toLowerCase().contains('tracker') && _evidenceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture a work image before sending the request.'), backgroundColor: Colors.red),
      );
      return;
    }

    final meters = double.tryParse(_metersController.text.trim()) ?? 0.0;
    final rate = _getRate(activeDesignation);
    final amount = meters * rate;

    final userEmail = ref.read(currentUserEmailProvider) ?? '';
    String empName = 'Ramesh';
    if (userEmail.trim().isNotEmpty) {
      if (userEmail.contains('@')) {
        final prefix = userEmail.split('@').first;
        if (prefix.isNotEmpty) {
          empName = prefix[0].toUpperCase() + (prefix.length > 1 ? prefix.substring(1) : '');
        }
      } else {
        empName = userEmail;
      }
    }

    final newRequest = IncentiveRequest(
      requestId: 'INC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      employeeName: empName,
      designation: activeDesignation,
      site: _selectedProject,
      productName: _selectedProduct,
      meters: meters,
      rate: rate,
      amount: amount,
      status: 'Pending',
      remarks: _remarksController.text.trim().isEmpty ? '-' : _remarksController.text.trim(),
      evidenceImage: _evidenceImage,
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      await ref.read(incentiveRepositoryProvider).createRequest(newRequest);
      // Do not report success until My Requests has re-read Firestore. This
      // prevents the tab from continuing to display a stale cached result.
      await ref.refresh(allIncentiveRequestsProvider.future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incentive request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _remarksController.clear();
        _metersController.clear();
        _evidenceImage = null;
        _formKey.currentState?.reset();
        setState(() {});
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

  void _showEditDialog(IncentiveRequest req) {
    String editProject = req.site;
    String editProduct = req.productName;
    final editMetersController = TextEditingController(text: req.meters.toInt().toString());
    final editRemarksController = TextEditingController(text: (req.remarks == '-' || req.remarks == null) ? '' : req.remarks!);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final availableProds = _projectProductsMap[editProject] ?? defaultProductRates.map((p) => p.productName).toList();
            if (!availableProds.contains(editProduct)) {
              editProduct = availableProds.first;
            }

            final currentRate = calculateIncentiveRate(editProduct, req.designation);
            final meters = double.tryParse(editMetersController.text.trim()) ?? 0.0;
            final expected = meters * currentRate;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Edit Incentive Request (${req.requestId})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Employee Designation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(req.designation, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    const SizedBox(height: 14),

                    const Text('Project / Site', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _projects.contains(editProject) ? editProject : _projects.first,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _projects.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            editProject = val;
                            final newProds = _projectProductsMap[val] ?? defaultProductRates.map((pr) => pr.productName).toList();
                            if (!newProds.contains(editProduct)) {
                              editProduct = newProds.first;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    const Text('Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: availableProds.contains(editProduct) ? editProduct : availableProds.first,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: availableProds.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => editProduct = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    const Text('Total Meters Completed (in meters)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: editMetersController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: const Padding(
                          padding: EdgeInsets.only(right: 12, top: 12),
                          child: Text('m', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 14),

                    const Text('Incentive Rate (per meter)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(formatIndianCurrency(currentRate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFC8E6C9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expected Incentive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                          const SizedBox(height: 2),
                          Text(formatIndianCurrency(expected), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text('Remarks (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: editRemarksController,
                      decoration: InputDecoration(
                        hintText: 'Enter remarks',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final updatedMeters = double.tryParse(editMetersController.text.trim()) ?? req.meters;
                    final updatedRate = currentRate;
                    final updatedAmount = updatedMeters * updatedRate;

                    final updatedReq = req.copyWith(
                      site: editProject,
                      productName: editProduct,
                      meters: updatedMeters,
                      rate: updatedRate,
                      amount: updatedAmount,
                      remarks: editRemarksController.text.trim().isEmpty ? '-' : editRemarksController.text.trim(),
                    );

                    try {
                      await ref.read(incentiveRepositoryProvider).updateRequest(updatedReq);
                      ref.invalidate(allIncentiveRequestsProvider);
                      if (mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Incentive request updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update request: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
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

  List<IncentiveRequest> _filterRequests(List<IncentiveRequest> allRequests) {
    var filtered = allRequests;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((req) {
        final prod = req.productName.toLowerCase();
        final site = req.site.toLowerCase();
        final status = req.status.toLowerCase();
        final remarks = (req.remarks ?? '').toLowerCase();
        final emp = req.employeeName.toLowerCase();
        return prod.contains(_searchQuery) ||
            site.contains(_searchQuery) ||
            status.contains(_searchQuery) ||
            remarks.contains(_searchQuery) ||
            emp.contains(_searchQuery);
      }).toList();
    }

    if (_fromDate != null || _toDate != null) {
      final fromMidnight = _fromDate != null
          ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day)
          : null;
      final toMidnight = _toDate != null
          ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59)
          : null;

      filtered = filtered.where((req) {
        final reqDate = DateTime.tryParse(req.createdAt);
        if (reqDate == null) return true;

        if (fromMidnight != null && reqDate.isBefore(fromMidnight)) {
          return false;
        }
        if (toMidnight != null && reqDate.isAfter(toMidnight)) {
          return false;
        }
        return true;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allIncentiveRequestsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              // Navigation Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TabBar(
                  labelColor: AppColors.active,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: AppColors.active,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.add_task_outlined, size: 20),
                      text: 'New Request',
                    ),
                    Tab(
                      icon: Icon(Icons.list_alt_outlined, size: 20),
                      text: 'My Requests',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.active,
                  onRefresh: () async {
                    ref.invalidate(allIncentiveRequestsProvider);
                    ref.invalidate(incentiveSettingsProvider);
                    await Future.delayed(const Duration(milliseconds: 500));
                  },

                  child: TabBarView(
                    children: [
                      // Tab 1: New Incentive Request Form
                      SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: _buildFormCard(),
                      ),
                      // Tab 2: My Incentive Requests List & Date Filter
                      _buildRequestsTabContent(requestsAsync),
                    ],
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final employees = ref.watch(allEmployeesProvider).asData?.value ?? [];
    final userEmail = ref.watch(currentUserEmailProvider) ?? '';
    final settingsAsync = ref.watch(incentiveSettingsProvider);
    final settings = settingsAsync.asData?.value;

    bool isSubmissionLocked = false;
    String lockMessage = '';

    if (settings != null && settings.isLockActive) {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      DateTime? fromDate;
      DateTime? toDate;
      try {
        if (settings.lockFromDate.isNotEmpty) {
          fromDate = DateTime.parse(settings.lockFromDate);
        }
        if (settings.lockToDate.isNotEmpty) {
          toDate = DateTime.parse(settings.lockToDate);
        }
      } catch (_) {}

      if (fromDate != null && toDate != null) {
        final fromMidnight = DateTime(fromDate.year, fromDate.month, fromDate.day);
        final toMidnight = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

        if ((todayDate.isAfter(fromMidnight) || todayDate.isAtSameMomentAs(fromMidnight)) &&
            (todayDate.isBefore(toMidnight) || todayDate.isAtSameMomentAs(toMidnight))) {
          isSubmissionLocked = true;
          lockMessage = 'Incentive requests are locked from ${settings.lockFromDate} to ${settings.lockToDate} by Admin.';
        }
      }
    }

    String activeDesignation = 'Operator';
    try {
      if (employees.isNotEmpty) {
        final lowerUserEmail = userEmail.trim().toLowerCase();
        final firstPart = lowerUserEmail.contains('@') ? lowerUserEmail.split('@').first : lowerUserEmail;

        for (final e in employees) {
          final empEmail = (e.emailAddress ?? '').toLowerCase();
          final empFirstName = (e.firstName ?? '').toLowerCase();
          if ((lowerUserEmail.isNotEmpty && empEmail == lowerUserEmail) ||
              (firstPart.isNotEmpty && empFirstName.contains(firstPart))) {
            if (e.designation.trim().isNotEmpty) {
              activeDesignation = e.designation.trim();
              break;
            }
          }
        }
      }
    } catch (_) {}

    final availableProducts = _availableProducts;
    if (!availableProducts.contains(_selectedProduct)) {
      _selectedProduct = availableProducts.first;
    }

    final rate = _getRate(activeDesignation);
    final expected = _getExpectedIncentive(activeDesignation);

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
              if (isSubmissionLocked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_outlined, color: Color(0xFFC62828), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lockMessage,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC62828)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'New Incentive Request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 20),

              // Employee Designation (read-only container matching employee management)
              const Text(
                'Employee Designation',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      activeDesignation,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Project / Site Dropdown
              const Text(
                'Project / Site',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _projects.contains(_selectedProject) ? _selectedProject : _projects.first,
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.active),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _projects.map((project) {
                  return DropdownMenuItem(
                    value: project,
                    child: Text(
                      project,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedProject = val;
                      final updatedAvailable = _availableProducts;
                      if (!updatedAvailable.contains(_selectedProduct)) {
                        _selectedProduct = updatedAvailable.first;
                      }
                    });
                  }
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Select project / site';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dynamic Product Dropdown
              const Text(
                'Product',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: availableProducts.contains(_selectedProduct) ? _selectedProduct : availableProducts.first,
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.active),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: availableProducts.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(
                      p,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedProduct = val);
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Select product';
                  return null;
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
                  final meters = double.tryParse(val.trim());
                  if (meters == null || meters <= 0) return 'Enter valid meters (> 0)';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              if (activeDesignation.toLowerCase().contains('tracker')) ...[
                const Text(
                  'Work Image',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _isCapturingImage ? null : _captureEvidenceImage,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    height: _evidenceImage == null ? 96 : 190,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _evidenceImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isCapturingImage
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.camera_alt_outlined, color: AppColors.active),
                              const SizedBox(height: 6),
                              Text(_isCapturingImage ? 'Opening camera...' : 'Capture work image', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(base64Decode(_evidenceImage!.split(',').last), fit: BoxFit.cover),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Retake', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Incentive Rate (per meter) - Non-editable read-only container
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
                  formatIndianCurrency(rate),
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
                      formatIndianCurrency(expected),
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

              // Send Request Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isSubmissionLocked ? null : () => _submitRequest(activeDesignation),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSubmissionLocked ? Colors.grey : AppColors.active,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(isSubmissionLocked ? Icons.lock_outline : Icons.send_rounded, size: 18),
                  label: Text(
                    isSubmissionLocked ? 'Submissions Restricted' : 'Send Request',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsTabContent(AsyncValue<List<IncentiveRequest>> requestsAsync) {
    return SizedBox.expand(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
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
              const SizedBox(height: 12),

              requestsAsync.when(
                data: (allRequests) {
                  final filteredRequests = _filterRequests(allRequests);

                  final pendingCount = filteredRequests.where((r) => r.status == 'Pending').length;
                  final approvedCount = filteredRequests.where((r) => r.status == 'Approved').length;
                  final rejectedCount = filteredRequests.where((r) => r.status == 'Rejected').length;

                  return Expanded(
                    child: ListView(
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
                        const SizedBox(height: 12),

                        // Search Bar
                        _buildSearchBar(),
                        const SizedBox(height: 12),

                        // Date Filter Bar
                        _buildDateFilterBar(),
                        const SizedBox(height: 16),

                        // Keep the controls and results in one scrollable area.
                        // This prevents a vertical Flex overflow on short
                        // windows while preserving the existing layout.
                        if (filteredRequests.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                'No incentive requests match your search or filter.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ...filteredRequests.indexed.expand((entry) sync* {
                            if (entry.$1 > 0) {
                              yield const SizedBox(height: 12);
                            }
                            yield _buildRequestRowItem(entry.$2);
                          }),
                      ],
                    ),
                  );
                },
                loading: () => const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Expanded(
                  child: Center(child: Text('Error loading requests: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search requests by product, site, status...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        filled: true,
        fillColor: Colors.grey.shade50,
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
      ),
      onChanged: (val) {
        setState(() => _searchQuery = val.trim().toLowerCase());
      },
    );
  }

  Widget _buildDateFilterBar() {
    final hasFilter = _fromDate != null || _toDate != null;

    String formatDate(DateTime dt) {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 18, color: AppColors.active),
          const SizedBox(width: 6),
          const Text(
            'Date Range:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fromDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  setState(() => _fromDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _fromDate != null ? formatDate(_fromDate!) : 'From Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: _fromDate != null ? Colors.black87 : Colors.grey.shade600,
                          fontWeight: _fromDate != null ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('-', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _toDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  setState(() => _toDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _toDate != null ? formatDate(_toDate!) : 'To Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: _toDate != null ? Colors.black87 : Colors.grey.shade600,
                          fontWeight: _toDate != null ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: () {
                setState(() {
                  _fromDate = null;
                  _toDate = null;
                });
              },
              icon: const Icon(Icons.clear, size: 18, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Clear Filter',
            ),
          ],
        ],
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
      clipBehavior: Clip.hardEdge,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${req.productName} • ${req.site}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
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
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text(
                'Request date: ${_formatRequestDate(req.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Meters: ${req.meters.toInt()}m  |  Rate: ${formatIndianCurrency(req.rate)}/m',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Expected: ${formatIndianCurrency(req.amount)}',
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
                  Expanded(
                    child: Text(
                      'Approved Amount: ${formatIndianCurrency(req.approvedAmount!)}  (Verified Meters: ${req.verifiedMeters?.toInt()}m)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isPending && req.id != null) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditDialog(req),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.active,
                    side: const BorderSide(color: AppColors.active),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Request', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _cancelRequest(req.id!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 14),
                  label: const Text('Cancel Request', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
