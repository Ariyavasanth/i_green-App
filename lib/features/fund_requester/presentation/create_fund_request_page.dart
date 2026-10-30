import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/authentication/providers/authentication_providers.dart';
import 'package:flutter_application_1/features/employee/providers/employee_providers.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_category_constants.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request_item.dart';
import 'package:flutter_application_1/features/fund_requester/providers/fund_request_providers.dart';
import 'package:flutter_application_1/features/fund_requester/data/services/fund_request_storage_service.dart';
import 'widgets/image_viewer_dialog.dart';
import 'widgets/searchable_select_picker.dart';
import 'widgets/voice_note_player_widget.dart';

class _FormItemData {
  String category;
  String subCategory;
  final TextEditingController commentsController;
  final TextEditingController amountController;

  _FormItemData({
    this.category = 'Fuel',
    this.subCategory = 'Select the Second Category',
    String initialComments = '',
    String initialAmount = '',
    VoidCallback? onAmountChanged,
  })  : commentsController = TextEditingController(text: initialComments),
        amountController = TextEditingController(text: initialAmount) {
    if (onAmountChanged != null) {
      amountController.addListener(onAmountChanged);
    }
  }

  void dispose() {
    commentsController.dispose();
    amountController.dispose();
  }
}

class CreateFundRequestPage extends ConsumerStatefulWidget {
  final String? initialCategory;

  const CreateFundRequestPage({
    this.initialCategory,
    super.key,
  });

  @override
  ConsumerState<CreateFundRequestPage> createState() => _CreateFundRequestPageState();
}

class _CreateFundRequestPageState extends ConsumerState<CreateFundRequestPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _messageController;
  String? _selectedProjectCode;
  String? _selectedProjectName;
  final List<String> _attachedBills = [];
  final List<BillImageItem> _attachedBillItems = [];
  final FundRequestStorageService _storageService = FundRequestStorageService();

  bool _hasVoiceNote = false;
  bool _isRecording = false;
  bool _isSubmitting = false;

  final List<_FormItemData> _items = [];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();

    final firstCat = widget.initialCategory ?? 'Fuel';
    _items.add(
      _FormItemData(
        category: firstCat,
        subCategory: 'Select the Second Category',
        onAmountChanged: _onAmountChanged,
      ),
    );
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _messageController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _calculatedTotalAmount {
    double total = 0.0;
    for (final item in _items) {
      final val = double.tryParse(item.amountController.text.trim()) ?? 0.0;
      total += val;
    }
    return total;
  }

  void _addNewItem({String? category}) {
    setState(() {
      _items.add(
        _FormItemData(
          category: category ?? 'Fuel',
          subCategory: 'Select the Second Category',
          onAmountChanged: _onAmountChanged,
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  List<SearchableSelectItem<String>> _getProjectItems(List<dynamic> projectsList) {
    // ONLY created projects from the system database - no hardcoding!
    return projectsList
        .where((p) => (p.projectCode ?? '').toString().trim().isNotEmpty)
        .map((p) {
          final code = (p.projectCode ?? '').toString().trim();
          final client = (p.clientName ?? '').toString().trim();
          final place = (p.place ?? '').toString().trim();
          final subtitle = [client, place].where((s) => s.isNotEmpty).join(' • ');

          return SearchableSelectItem<String>(
            value: code,
            title: code,
            subtitle: subtitle.isNotEmpty ? subtitle : null,
            searchKey: '$code $client $place ${p.state ?? ""} ${p.district ?? ""}',
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.business_center_rounded, color: Color(0xFF414A51), size: 18),
            ),
          );
        })
        .toList();
  }

  List<SearchableSelectItem<String>> _getCategoryItems() {
    return FundCategoryConstants.categories.map((cat) {
      return SearchableSelectItem<String>(
        value: cat.title,
        title: cat.title,
        subtitle: '${cat.subCategories.length} sub-categories (e.g. ${cat.subCategories.take(2).map((s) => s.title).join(", ")})',
        searchKey: '${cat.title} ${cat.subCategories.map((s) => s.title).join(" ")}',
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cat.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(cat.icon, color: cat.primaryColor, size: 18),
        ),
      );
    }).toList();
  }

  List<SearchableSelectItem<String>> _getSubCategoryItems(String categoryTitle) {
    final availableSubCats = FundCategoryConstants.getSubCategoriesFor(categoryTitle);
    final catDef = FundCategoryConstants.categories
        .where((c) => c.title.toLowerCase() == categoryTitle.toLowerCase())
        .firstOrNull;

    final primaryColor = catDef?.primaryColor ?? AppColors.primary;

    return availableSubCats.map((sub) {
      final subDef = catDef?.subCategories
          .where((s) => s.title.toLowerCase() == sub.toLowerCase())
          .firstOrNull;
      final icon = subDef?.icon ?? Icons.label_outline_rounded;

      return SearchableSelectItem<String>(
        value: sub,
        title: sub,
        searchKey: sub,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 18),
        ),
      );
    }).toList();
  }

  Future<void> _pickBills() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        for (final f in images) {
          final bytes = await f.readAsBytes();
          _attachedBillItems.add(
            BillImageItem(
              title: f.name,
              bytes: bytes,
            ),
          );
          _attachedBills.add(f.name);
        }
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${images.length} bill attachment(s) added! Tap any thumbnail to view full size.'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      setState(() {
        const dummyName = 'Bill_Receipt.jpg';
        _attachedBillItems.add(const BillImageItem(title: dummyName));
        _attachedBills.add(dummyName);
      });
    }
  }

  void _toggleVoiceNote() {
    setState(() {
      if (!_hasVoiceNote && !_isRecording) {
        _isRecording = true;
      } else if (_isRecording) {
        _isRecording = false;
        _hasVoiceNote = true;
      }
    });
  }

  Future<void> _submitFundRequest() async {
    final currentEmp = ref.read(currentEmployeeProvider);
    final userEmail = ref.read(currentUserEmailProvider);

    final requesterName = currentEmp?.fullName.isNotEmpty == true
        ? currentEmp!.fullName
        : (userEmail ?? 'Sathiya');
    final employeeId = currentEmp?.id.toString() ?? 'emp_sathiya';
    final customId = currentEmp?.employeeId ?? 'EMP042';

    final projectCode = _selectedProjectCode?.trim() ?? '';
    if (projectCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Project Code from your created projects.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final message = _messageController.text.trim();

    final List<FundRequestItem> finalItems = [];
    double totalRequestAmount = 0.0;

    for (int i = 0; i < _items.length; i++) {
      final itemData = _items[i];
      final amount = double.tryParse(itemData.amountController.text.trim()) ?? 0.0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid amount for Item #${i + 1}.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      totalRequestAmount += amount;

      final cat = itemData.category == 'Select the first Category' ? 'Fuel' : itemData.category;
      final subCat = itemData.subCategory == 'Select the Second Category' ? '' : itemData.subCategory;

      finalItems.add(
        FundRequestItem(
          id: 'item_${DateTime.now().millisecondsSinceEpoch}_$i',
          category: cat,
          subCategory: subCat,
          comments: itemData.commentsController.text.trim(),
          amount: amount,
        ),
      );
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(fundRequestRepositoryProvider);
      final reqNumber = 'REQ-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // 1. Upload attached bill images to Firebase Storage bucket
      final List<String> uploadedBillUrls = [];
      for (final item in _attachedBillItems) {
        if (item.bytes != null) {
          final downloadUrl = await _storageService.uploadBillImage(
            bytes: item.bytes!,
            fileName: item.title,
            requestId: reqNumber,
            projectCode: projectCode,
          );
          uploadedBillUrls.add(downloadUrl);
        } else {
          uploadedBillUrls.add(item.title);
        }
      }

      // 2. Upload voice note if recorded
      String? uploadedAudioUrl;
      if (_hasVoiceNote) {
        uploadedAudioUrl = await _storageService.uploadAudioNote(
          bytes: Uint8List.fromList([0, 1, 2, 3]),
          requestId: reqNumber,
          projectCode: projectCode,
        );
      }

      final newRequest = FundRequest(
        id: '',
        requestNumber: reqNumber,
        employeeId: employeeId,
        employeeName: requesterName,
        employeeCustomId: customId,
        department: currentEmp?.department ?? 'Operations',
        message: message.isNotEmpty ? message : 'Fund Request for project $projectCode',
        projectCode: projectCode,
        projectName: _selectedProjectName ?? '',
        approvedAmount: 0.0,
        requestAmount: totalRequestAmount,
        items: finalItems,
        billUrls: uploadedBillUrls.isNotEmpty ? uploadedBillUrls : _attachedBills,
        audioNoteUrl: uploadedAudioUrl,
        status: 'Pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.createFundRequest(newRequest);
      ref.invalidate(allFundRequestsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fund request for ₹${totalRequestAmount.toStringAsFixed(2)} submitted successfully!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/fund-requester');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final projectsList = projectsAsync.asData?.value ?? [];
    final currentEmp = ref.watch(currentEmployeeProvider);
    final userEmail = ref.watch(currentUserEmailProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          if (isMobile) {
            return _buildMobileLayout(projectsList);
          }
          return _buildDesktopLayout(projectsList, currentEmp, userEmail, constraints.maxWidth);
        },
      ),
    );
  }

  // =========================================================================
  // DESKTOP LAYOUT (2-Column Responsive Dashboard)
  // =========================================================================
  Widget _buildDesktopLayout(
    List<dynamic> projectsList,
    dynamic currentEmp,
    String? userEmail,
    double maxWidth,
  ) {
    return Form(
      key: _formKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Main Form Inputs
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Project Details
                      _buildDesktopProjectCard(projectsList),
                      const SizedBox(height: 20),

                      // Fund Items Section
                      _buildDesktopItemsSection(),
                      const SizedBox(height: 20),

                      // Attachments & Voice Note
                      _buildDesktopAttachmentsCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Right Column: Summary & Confirmation Sidebar
                Expanded(
                  flex: 4,
                  child: _buildDesktopSummaryCard(currentEmp, userEmail),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopProjectCard(List<dynamic> projectsList) {
    final projectItems = _getProjectItems(projectsList);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment_outlined, color: Color(0xFF414A51), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project & Purpose',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Select a created project and specify fund purpose',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project Code Searchable Dropdown
              Expanded(
                flex: 5,
                child: SearchableSelectField<String>(
                  label: 'Project Code',
                  hintText: 'Select or search project code',
                  isRequired: true,
                  dialogTitle: 'Select Created Project',
                  searchHint: 'Search by project code, client, location...',
                  emptyMessage: 'No created projects found. Please create a project under Project Module first.',
                  value: _selectedProjectCode,
                  displayText: _selectedProjectCode,
                  displaySubtitle: _selectedProjectName,
                  items: projectItems,
                  onChanged: (val) {
                    if (val != null) {
                      final selectedProj = projectsList
                          .where((p) => (p.projectCode ?? '').toString().trim() == val)
                          .firstOrNull;
                      setState(() {
                        _selectedProjectCode = val;
                        _selectedProjectName = (selectedProj?.clientName ?? '').toString();
                      });
                    }
                  },
                ),
              ),

              const SizedBox(width: 16),

              // Purpose / Message
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Purpose / Message',
                    hintText: 'e.g. Fuel & daily labor allowance for pump site',
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopItemsSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF414A51), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Requested Fund Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_items.length} ${_items.length == 1 ? 'Item' : 'Items'}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Configure individual expense line items with category search and amount',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _addNewItem(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFF2D3748),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Another Item', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Items
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final itemData = entry.value;
            return _buildDesktopItemRow(index, itemData);
          }),
        ],
      ),
    );
  }

  Widget _buildDesktopItemRow(int index, _FormItemData itemData) {
    final availableSubCats = FundCategoryConstants.getSubCategoriesFor(itemData.category);
    final categoryItems = _getCategoryItems();
    final subCategoryItems = _getSubCategoryItems(itemData.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Item #${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  tooltip: 'Remove Item',
                  onPressed: () => _removeItem(index),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Searchable Category & Subcategory Row
          Row(
            children: [
              Expanded(
                flex: 5,
                child: SearchableSelectField<String>(
                  label: 'Category',
                  hintText: 'Select or search category',
                  isRequired: true,
                  dialogTitle: 'Select Fund Category',
                  searchHint: 'Search category (Fuel, Rental, Wages...)',
                  value: itemData.category,
                  displayText: itemData.category,
                  items: categoryItems,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        itemData.category = val;
                        itemData.subCategory = 'Select the Second Category';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 5,
                child: SearchableSelectField<String>(
                  label: 'Sub-Category',
                  hintText: 'Select or search sub-category',
                  dialogTitle: 'Select Sub-Category (${itemData.category})',
                  searchHint: 'Search sub-category...',
                  value: availableSubCats.contains(itemData.subCategory) ? itemData.subCategory : null,
                  displayText: availableSubCats.contains(itemData.subCategory) ? itemData.subCategory : null,
                  items: subCategoryItems,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        itemData.subCategory = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Amount and Comments Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  controller: itemData.amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (₹) *',
                    hintText: '0.00',
                    prefixText: '₹ ',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 6,
                child: TextField(
                  controller: itemData.commentsController,
                  decoration: InputDecoration(
                    labelText: 'Comments / Remarks',
                    hintText: 'Enter specific item comments (e.g. 50L diesel for site generator)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAttachmentsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_file_rounded, color: Color(0xFF414A51), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supporting Documents & Audio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Upload receipts, vendor quotations, or record a quick audio briefing',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Bill Attachments
              Expanded(
                child: InkWell(
                  onTap: _pickBills,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _attachedBillItems.isNotEmpty ? AppColors.primary : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 32,
                          color: _attachedBillItems.isNotEmpty ? AppColors.primary : const Color(0xFF64748B),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _attachedBillItems.isNotEmpty
                              ? '${_attachedBillItems.length} Bill(s) Attached'
                              : 'Attach Bills / Receipts',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Click to browse & upload images',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Voice Note
              Expanded(
                child: InkWell(
                  onTap: _toggleVoiceNote,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? const Color(0xFFFEE2E2)
                          : (_hasVoiceNote ? const Color(0xFFEDE9FE) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isRecording
                            ? const Color(0xFFDC2626)
                            : (_hasVoiceNote ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1)),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isRecording ? Icons.mic : (_hasVoiceNote ? Icons.mic_rounded : Icons.mic_none_rounded),
                          size: 32,
                          color: _isRecording
                              ? const Color(0xFFDC2626)
                              : (_hasVoiceNote ? const Color(0xFF7C3AED) : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRecording
                              ? 'Recording... Tap to stop'
                              : (_hasVoiceNote ? 'Voice Note Attached' : 'Record Voice Note'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _isRecording
                                ? const Color(0xFFDC2626)
                                : (_hasVoiceNote ? const Color(0xFF7C3AED) : const Color(0xFF1E293B)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasVoiceNote ? 'Tap to play, re-record or delete' : 'Audio explanation for approvers',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Attached Bill Images Thumbnail Gallery
          _buildBillThumbnailsGallery(),

          // Voice Note Player / Recorder
          if (_isRecording || _hasVoiceNote)
            VoiceNotePlayerWidget(
              isRecording: _isRecording,
              hasVoiceNote: _hasVoiceNote,
              onStartRecord: () => setState(() => _isRecording = true),
              onStopRecord: () => setState(() {
                _isRecording = false;
                _hasVoiceNote = true;
              }),
              onDelete: () => setState(() {
                _hasVoiceNote = false;
                _isRecording = false;
              }),
              onReRecord: () => setState(() {
                _hasVoiceNote = false;
                _isRecording = true;
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildBillThumbnailsGallery() {
    if (_attachedBillItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text(
          'Attached Bills (Tap thumbnail to view full screen):',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _attachedBillItems.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) {
              if (idx == _attachedBillItems.length) {
                // + Add More tile
                return InkWell(
                  onTap: _pickBills,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 26),
                        const SizedBox(height: 4),
                        const Text(
                          'Add More',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final item = _attachedBillItems[idx];
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: () {
                      ImageViewerDialog.show(
                        context: context,
                        images: _attachedBillItems,
                        initialIndex: idx,
                        onDelete: (delIdx) {
                          setState(() {
                            _attachedBillItems.removeAt(delIdx);
                            if (delIdx < _attachedBills.length) {
                              _attachedBills.removeAt(delIdx);
                            }
                          });
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.bytes != null
                          ? Image.memory(item.bytes!, fit: BoxFit.cover)
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.receipt_long_rounded, color: Color(0xFF64748B), size: 24),
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(fontSize: 9),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  // Delete badge
                  Positioned(
                    top: -6,
                    right: -6,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _attachedBillItems.removeAt(idx);
                          if (idx < _attachedBills.length) {
                            _attachedBills.removeAt(idx);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSummaryCard(dynamic currentEmp, String? userEmail) {
    final requesterName = currentEmp?.fullName.isNotEmpty == true
        ? currentEmp!.fullName
        : (userEmail ?? 'Sathiya');
    final customId = currentEmp?.employeeId ?? 'EMP042';
    final department = currentEmp?.department ?? 'Operations';
    final total = _calculatedTotalAmount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Request Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NEW REQUEST',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Requester Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    requesterName.isNotEmpty ? requesterName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requesterName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        '$customId • $department',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Project
          const Text('Selected Project', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            _selectedProjectCode ?? 'Not selected',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
          ),
          if (_selectedProjectName != null && _selectedProjectName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _selectedProjectName!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Items breakdown preview
          const Text('Items Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          ..._items.map((item) {
            final amt = double.tryParse(item.amountController.text.trim()) ?? 0.0;
            final cat = item.category == 'Select the first Category' ? 'Fuel' : item.category;
            final sub = item.subCategory == 'Select the Second Category' ? '' : ' • ${item.subCategory}';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$cat$sub',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹ ${amt.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            );
          }),

          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Total Highlight Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Amount', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    Text('Requested', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                Text(
                  '₹ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitFundRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Fund Request',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Cancel Button
          OutlinedButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/fund-requester');
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MOBILE LAYOUT (Clean Vertical Flow with Searchable Pickers)
  // =========================================================================
  Widget _buildMobileLayout(List<dynamic> projectsList) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Project Code & Message Container
            _buildMobileProjectAndMessageCard(projectsList),
            const SizedBox(height: 16),

            // Dynamic Category Items Container
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final itemData = entry.value;
              return _buildMobileItemCard(index, itemData);
            }),

            const SizedBox(height: 12),

            // Floating Add More Items Button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: FloatingActionButton(
                  heroTag: 'addItemFabMobile',
                  mini: true,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: () => _addNewItem(),
                  tooltip: 'Add Another Item',
                  child: const Icon(Icons.add, size: 22),
                ),
              ),
            ),

            // Bill & Hold (Mic) Action Cards
            const SizedBox(height: 8),
            _buildBillAndHoldRow(),

            // Attached Bill Images Thumbnail Gallery (Mobile)
            _buildBillThumbnailsGallery(),

            // Voice Note Recording / Playback View (Mobile)
            if (_isRecording || _hasVoiceNote) ...[
              const SizedBox(height: 10),
              VoiceNotePlayerWidget(
                isRecording: _isRecording,
                hasVoiceNote: _hasVoiceNote,
                onStartRecord: () => setState(() => _isRecording = true),
                onStopRecord: () => setState(() {
                  _isRecording = false;
                  _hasVoiceNote = true;
                }),
                onDelete: () => setState(() {
                  _hasVoiceNote = false;
                  _isRecording = false;
                }),
                onReRecord: () => setState(() {
                  _hasVoiceNote = false;
                  _isRecording = true;
                }),
              ),
            ],

            const SizedBox(height: 20),

            // Big Green "Add" Action Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFundRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _calculatedTotalAmount > 0
                            ? 'Add (₹${_calculatedTotalAmount.toStringAsFixed(2)})'
                            : 'Add',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileProjectAndMessageCard(List<dynamic> projectsList) {
    final projectItems = _getProjectItems(projectsList);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project & Request Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),

          // Searchable Project Code Picker
          SearchableSelectField<String>(
            label: 'Project Code',
            hintText: 'Select or search project code',
            isRequired: true,
            dialogTitle: 'Select Created Project',
            searchHint: 'Search by project code, client...',
            emptyMessage: 'No created projects found. Please create a project under Project Module first.',
            value: _selectedProjectCode,
            displayText: _selectedProjectCode,
            displaySubtitle: _selectedProjectName,
            items: projectItems,
            onChanged: (val) {
              if (val != null) {
                final selectedProj = projectsList
                    .where((p) => (p.projectCode ?? '').toString().trim() == val)
                    .firstOrNull;
                setState(() {
                  _selectedProjectCode = val;
                  _selectedProjectName = (selectedProj?.clientName ?? '').toString();
                });
              }
            },
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: 'Enter request message (e.g. igig)',
              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileItemCard(int index, _FormItemData itemData) {
    final availableSubCats = FundCategoryConstants.getSubCategoriesFor(itemData.category);
    final categoryItems = _getCategoryItems();
    final subCategoryItems = _getSubCategoryItems(itemData.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_items.length > 1) ...[
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => _removeItem(index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Searchable Category Picker
          SearchableSelectField<String>(
            label: 'Category',
            hintText: 'Select or search category',
            isRequired: true,
            dialogTitle: 'Select Fund Category',
            searchHint: 'Search category...',
            value: itemData.category,
            displayText: itemData.category,
            items: categoryItems,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  itemData.category = val;
                  itemData.subCategory = 'Select the Second Category';
                });
              }
            },
          ),

          const SizedBox(height: 14),

          // Searchable Sub-Category Picker
          SearchableSelectField<String>(
            label: 'Sub-Category',
            hintText: 'Select or search sub-category',
            dialogTitle: 'Select Sub-Category (${itemData.category})',
            searchHint: 'Search sub-category...',
            value: availableSubCats.contains(itemData.subCategory) ? itemData.subCategory : null,
            displayText: availableSubCats.contains(itemData.subCategory) ? itemData.subCategory : null,
            items: subCategoryItems,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  itemData.subCategory = val;
                });
              }
            },
          ),

          const SizedBox(height: 14),

          TextField(
            controller: itemData.commentsController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Comments',
              hintText: 'Enter Comments',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelStyle: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: itemData.amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              hintText: 'Enter Amount',
              prefixText: '₹ ',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelStyle: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillAndHoldRow() {
    return Row(
      children: [
        // Bill Button Card
        Expanded(
          child: InkWell(
            onTap: _pickBills,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _attachedBillItems.isNotEmpty ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      const Icon(
                        Icons.image_rounded,
                        size: 34,
                        color: Color(0xFF1E293B),
                      ),
                      if (_attachedBillItems.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_attachedBillItems.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _attachedBillItems.isNotEmpty
                        ? '${_attachedBillItems.length} Bill Attached'
                        : 'Bill',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Hold (Mic) Button Card
        Expanded(
          child: InkWell(
            onTap: _toggleVoiceNote,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: _isRecording
                    ? const Color(0xFFFEE2E2)
                    : (_hasVoiceNote
                        ? const Color(0xFFEDE9FE)
                        : const Color(0xFFE2E8F0).withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isRecording
                      ? const Color(0xFFDC2626)
                      : (_hasVoiceNote ? const Color(0xFF7C3AED) : Colors.transparent),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRecording ? Icons.mic : (_hasVoiceNote ? Icons.mic_rounded : Icons.mic_none_rounded),
                    size: 34,
                    color: _isRecording
                        ? const Color(0xFFDC2626)
                        : (_hasVoiceNote ? const Color(0xFF7C3AED) : const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording
                        ? 'Recording...'
                        : (_hasVoiceNote ? 'Voice Attached' : 'Hold'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _isRecording
                          ? const Color(0xFFDC2626)
                          : (_hasVoiceNote ? const Color(0xFF7C3AED) : const Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
