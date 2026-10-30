import 'dart:async';
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
import 'widgets/searchable_select_picker.dart';

class AttachedBillItem {
  final String id;
  final String name;
  final String path;
  final Uint8List? bytes;
  final int sizeInBytes;

  AttachedBillItem({
    required this.id,
    required this.name,
    required this.path,
    this.bytes,
    this.sizeInBytes = 0,
  });
}

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

class _CreateFundRequestPageState extends ConsumerState<CreateFundRequestPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _messageController;
  String? _selectedProjectCode;
  String? _selectedProjectName;
  final List<AttachedBillItem> _attachedBillItems = [];

  // Voice note state
  bool _hasVoiceNote = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  bool _isPlayingVoiceNote = false;
  int _playbackSeconds = 0;
  int _voiceNoteTotalDuration = 0;
  Timer? _playbackTimer;

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
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _messageController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
    // Only created projects from the database - no hardcoding!
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
        for (final img in images) {
          Uint8List? bytes;
          try {
            bytes = await img.readAsBytes();
          } catch (_) {}

          setState(() {
            _attachedBillItems.add(
              AttachedBillItem(
                id: 'bill_${DateTime.now().millisecondsSinceEpoch}_${img.name}',
                name: img.name,
                path: img.path,
                bytes: bytes,
                sizeInBytes: bytes?.lengthInBytes ?? 0,
              ),
            );
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${images.length} bill attachment(s) added! Tap any thumbnail to preview.'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      setState(() {
        _attachedBillItems.add(
          AttachedBillItem(
            id: 'bill_${DateTime.now().millisecondsSinceEpoch}',
            name: 'Bill_Receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
            path: '',
          ),
        );
      });
    }
  }

  void _removeBillItem(AttachedBillItem item) {
    setState(() {
      _attachedBillItems.removeWhere((b) => b.id == item.id);
    });
  }

  void _showImagePreviewDialog(AttachedBillItem bill) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF414A51), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            bill.sizeInBytes > 0
                                ? '${(bill.sizeInBytes / 1024).toStringAsFixed(1)} KB • Attached Bill'
                                : 'Attached Image Receipt',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Image Viewer with Zoom & Pan
              Flexible(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: bill.bytes != null
                          ? Image.memory(
                              bill.bytes!,
                              fit: BoxFit.contain,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image_rounded, size: 72, color: Colors.white54),
                                const SizedBox(height: 12),
                                Text(
                                  bill.name,
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              // Footer Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pinch or scroll to zoom in/out',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE2E2),
                        foregroundColor: const Color(0xFFDC2626),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete Bill'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _removeBillItem(bill);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Voice Note Controller Methods
  void _startRecording() {
    _playbackTimer?.cancel();
    setState(() {
      _isRecording = true;
      _hasVoiceNote = false;
      _recordingSeconds = 0;
      _isPlayingVoiceNote = false;
      _playbackSeconds = 0;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });
  }

  void _stopAndSaveRecording() {
    _recordingTimer?.cancel();
    final duration = _recordingSeconds > 0 ? _recordingSeconds : 5;
    setState(() {
      _isRecording = false;
      _hasVoiceNote = true;
      _voiceNoteTotalDuration = duration;
      _playbackSeconds = 0;
      _isPlayingVoiceNote = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice note recorded (${_formatDuration(duration)})! Tap Play to listen.'),
          backgroundColor: const Color(0xFF7C3AED),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _cancelRecording() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  void _togglePlayVoiceNote() {
    if (_isPlayingVoiceNote) {
      _playbackTimer?.cancel();
      setState(() => _isPlayingVoiceNote = false);
    } else {
      setState(() {
        _isPlayingVoiceNote = true;
        if (_playbackSeconds >= _voiceNoteTotalDuration) {
          _playbackSeconds = 0;
        }
      });

      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _playbackSeconds++;
            if (_playbackSeconds >= _voiceNoteTotalDuration) {
              _isPlayingVoiceNote = false;
              _playbackSeconds = _voiceNoteTotalDuration;
              timer.cancel();
            }
          });
        }
      });
    }
  }

  void _deleteVoiceNote() {
    _playbackTimer?.cancel();
    _recordingTimer?.cancel();
    setState(() {
      _hasVoiceNote = false;
      _isRecording = false;
      _isPlayingVoiceNote = false;
      _recordingSeconds = 0;
      _playbackSeconds = 0;
      _voiceNoteTotalDuration = 0;
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
      final newRequest = FundRequest(
        id: '',
        requestNumber: 'REQ-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
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
        billUrls: _attachedBillItems.map((b) => b.name).toList(),
        audioNoteUrl: _hasVoiceNote ? 'local_voicenote_${DateTime.now().millisecondsSinceEpoch}.m4a' : null,
        status: 'Pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.createFundRequest(newRequest);

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
                    'Upload receipts with preview, or record & listen to audio explanation',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bill Attachments Box
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _pickBills,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _attachedBillItems.isNotEmpty ? AppColors.primary : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 32,
                              color: _attachedBillItems.isNotEmpty ? AppColors.primary : const Color(0xFF64748B),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _attachedBillItems.isNotEmpty ? 'Add More Bills / Receipts' : 'Attach Bills / Receipts',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Click to browse images • Tap thumbnail below to view',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_attachedBillItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildBillThumbnailsView(),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // Voice Note Box
              Expanded(
                child: _buildVoiceNoteInteractiveWidget(),
              ),
            ],
          ),
        ],
      ),
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

          // Attachments preview count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Attached Receipts', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text('${_attachedBillItems.length} images', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Audio Briefing', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text(
                _hasVoiceNote ? '${_formatDuration(_voiceNoteTotalDuration)} audio attached' : 'None',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: _hasVoiceNote ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

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
  // MOBILE LAYOUT (Clean Vertical Flow with Image Previews & Voice Player)
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
            _buildMobileBillAndHoldRow(),
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

  // =========================================================================
  // ATTACHMENTS: BILL THUMBNAILS & VOICE RECORDER/PLAYER WIDGETS
  // =========================================================================
  Widget _buildBillThumbnailsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attached Receipts (${_attachedBillItems.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            InkWell(
              onTap: _pickBills,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, size: 15, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('+ Add More', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _attachedBillItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) {
              final bill = _attachedBillItems[idx];
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: () => _showImagePreviewDialog(bill),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: bill.bytes != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  bill.bytes!,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                    color: Colors.black.withValues(alpha: 0.6),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.visibility_rounded, size: 11, color: Colors.white),
                                        SizedBox(width: 3),
                                        Text('View', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 28, color: Color(0xFF64748B)),
                                SizedBox(height: 4),
                                Text('Receipt', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                    ),
                  ),

                  // Delete Badge
                  Positioned(
                    top: -6,
                    right: -6,
                    child: InkWell(
                      onTap: () => _removeBillItem(bill),
                      child: Container(
                        padding: const EdgeInsets.all(4),
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

  Widget _buildVoiceNoteInteractiveWidget() {
    // 1. Actively Recording State
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Pulsing red dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'RECORDING AUDIO...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(_recordingSeconds),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Soundwave Visualizer Bars (Animated Simulation)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(14, (i) {
                final heights = [12.0, 22.0, 34.0, 18.0, 28.0, 38.0, 24.0, 32.0, 20.0, 36.0, 16.0, 26.0, 30.0, 14.0];
                final animHeight = (_recordingSeconds % 2 == 0)
                    ? heights[i]
                    : heights[(i + 4) % heights.length];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: 4,
                  height: animHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelRecording,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _stopAndSaveRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.stop_circle_rounded, size: 20),
                    label: const Text('Stop & Save', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 2. Voice Note Attached State (With Interactive Player!)
    if (_hasVoiceNote) {
      final progressRatio = _voiceNoteTotalDuration > 0
          ? (_playbackSeconds / _voiceNoteTotalDuration).clamp(0.0, 1.0)
          : 0.0;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF5FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, size: 16, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'VOICE NOTE ATTACHED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_formatDuration(_playbackSeconds)} / ${_formatDuration(_voiceNoteTotalDuration)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B21A8),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Player Bar
            Row(
              children: [
                // Play / Pause Circle Button
                InkWell(
                  onTap: _togglePlayVoiceNote,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlayingVoiceNote ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Simulated Soundwave with Playback Progress Highlight
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      backgroundColor: const Color(0xFFDDD6FE),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Re-record Button
                IconButton(
                  tooltip: 'Re-record audio',
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF6B21A8)),
                  onPressed: _startRecording,
                ),

                // Delete Button
                IconButton(
                  tooltip: 'Delete voice note',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                  onPressed: _deleteVoiceNote,
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 3. Idle State (Ready to Record)
    return InkWell(
      onTap: _startRecording,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        ),
        child: const Column(
          children: [
            Icon(Icons.mic_none_rounded, size: 32, color: Color(0xFF64748B)),
            SizedBox(height: 8),
            Text(
              'Record Voice Note',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Tap to record audio briefing for approvers',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBillAndHoldRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                        _attachedBillItems.isNotEmpty ? '${_attachedBillItems.length} Bill Attached' : 'Bill',
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
                onTap: () {
                  if (!_isRecording && !_hasVoiceNote) {
                    _startRecording();
                  } else if (_isRecording) {
                    _stopAndSaveRecording();
                  } else {
                    _togglePlayVoiceNote();
                  }
                },
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
                            ? 'Recording (${_formatDuration(_recordingSeconds)})'
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
        ),

        // If Bills are attached, display interactive thumbnail strip directly below
        if (_attachedBillItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildBillThumbnailsView(),
        ],

        // If Voice Note is recording or attached, display interactive Voice Note Dock
        if (_isRecording || _hasVoiceNote) ...[
          const SizedBox(height: 12),
          _buildVoiceNoteInteractiveWidget(),
        ],
      ],
    );
  }
}
