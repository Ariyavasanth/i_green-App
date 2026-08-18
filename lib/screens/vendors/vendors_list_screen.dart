import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum VendorGstTreatment { registeredRegular, unregistered }

@immutable
class VendorListItem {
  const VendorListItem({
    required this.id,
    required this.vendorCode,
    required this.name,
    required this.companyName,
    required this.gstTreatment,
    this.status = 'Active',
    this.payables = 0,
    this.email,
    this.workPhone,
  });

  final String id;
  final String vendorCode;
  final String name;
  final String companyName;
  final VendorGstTreatment gstTreatment;
  final String status;
  final double payables;
  final String? email;
  final String? workPhone;
}

class VendorsListScreen extends StatefulWidget {
  const VendorsListScreen({
    super.key,
    this.vendors = const <VendorListItem>[],
    this.onRefresh,
    this.onNewVendor,
    this.onVendorTap,
    this.onVendorAction,
  });

  final List<VendorListItem> vendors;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onNewVendor;
  final ValueChanged<VendorListItem>? onVendorTap;
  final void Function(VendorListItem vendor, String action)? onVendorAction;

  @override
  State<VendorsListScreen> createState() => _VendorsListScreenState();
}

class _VendorsListScreenState extends State<VendorsListScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  VendorGstTreatment? _filter;
  String? _statusFilter;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  List<VendorListItem> get _visibleVendors {
    final query = _searchController.text.trim().toLowerCase();
    return widget.vendors
        .where((vendor) {
          final matchesFilter =
              _filter == null || vendor.gstTreatment == _filter;
          final matchesStatus =
              _statusFilter == null || vendor.status == _statusFilter;
          final searchable =
              '${vendor.vendorCode} ${vendor.name} ${vendor.companyName} '
                      '${vendor.email ?? ''} ${vendor.workPhone ?? ''}'
                  .toLowerCase();
          return matchesFilter && matchesStatus && (query.isEmpty || searchable.contains(query));
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(VendorListItem vendor) {
    setState(() {
      if (!_selectedIds.add(vendor.id)) _selectedIds.remove(vendor.id);
    });
  }

  Future<void> _refresh() async {
    await widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vendors = _visibleVendors;
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    final isFiltered = _filter != null || _statusFilter != null;

    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                tooltip: 'Cancel selection',
                onPressed: () => setState(_selectedIds.clear),
                icon: const Icon(Icons.close),
              ),
              title: Text('${_selectedIds.length} selected'),
            )
          : null,
      body: Column(
        children: [
          // Permanent Unified Search & Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // Search Input (Left 80% width)
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                      decoration: InputDecoration(
                        hintText: 'Search vendors by name, code...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF6B7280), // medium gray readable contrast
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF6B7280),
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF6B7280)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Filter Button (Right 20% width / Square Icon Button)
                PopupMenuButton<String>(
                  tooltip: 'Filter Vendors',
                  offset: const Offset(0, 52),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.white,
                  initialValue: _statusFilter ?? _filter?.name ?? 'all',
                  onSelected: (value) => setState(() {
                    switch (value) {
                      case 'registeredRegular':
                        _filter = VendorGstTreatment.registeredRegular;
                        _statusFilter = null;
                        break;
                      case 'unregistered':
                        _filter = VendorGstTreatment.unregistered;
                        _statusFilter = null;
                        break;
                      case 'Active':
                        _statusFilter = 'Active';
                        _filter = null;
                        break;
                      case 'Inactive':
                        _statusFilter = 'Inactive';
                        _filter = null;
                        break;
                      case 'Blocked':
                        _statusFilter = 'Blocked';
                        _filter = null;
                        break;
                      default:
                        _filter = null;
                        _statusFilter = null;
                    }
                  }),
                  itemBuilder: (context) => [
                    // Section 1: STATUS
                    const PopupMenuItem<String>(
                      enabled: false,
                      height: 32,
                      child: Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildFilterMenuItem('all', 'All Vendors', isSelected: !isFiltered),
                    _buildFilterMenuItem('Active', 'Active', isSelected: _statusFilter == 'Active'),
                    _buildFilterMenuItem('Inactive', 'Inactive', isSelected: _statusFilter == 'Inactive'),
                    _buildFilterMenuItem('Blocked', 'Blocked', isSelected: _statusFilter == 'Blocked'),
                    const PopupMenuDivider(),
                    // Section 2: BUSINESS TYPE
                    const PopupMenuItem<String>(
                      enabled: false,
                      height: 32,
                      child: Text(
                        'BUSINESS TYPE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildFilterMenuItem(
                      'registeredRegular',
                      'Registered Business - Regular',
                      isSelected: _filter == VendorGstTreatment.registeredRegular,
                    ),
                    _buildFilterMenuItem(
                      'unregistered',
                      'Unregistered Business',
                      isSelected: _filter == VendorGstTreatment.unregistered,
                    ),
                  ],
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isFiltered ? const Color(0xFFF4F8E8) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFiltered ? const Color(0xFF84B01E) : const Color(0xFFE5E7EB),
                        width: isFiltered ? 1.5 : 1.0,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 22,
                          color: isFiltered ? const Color(0xFF84B01E) : const Color(0xFF374151),
                        ),
                        if (isFiltered)
                          Positioned(
                            top: 9,
                            right: 9,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF84B01E),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Vendors Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: vendors.isEmpty
                  ? _EmptyVendorsState(
                      hasFilters:
                          _filter != null || _statusFilter != null || _searchController.text.isNotEmpty,
                      onClear: () {
                        _searchController.clear();
                        setState(() {
                          _filter = null;
                          _statusFilter = null;
                        });
                      },
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 900) {
                          return _VendorTable(
                            vendors: vendors,
                            selectedIds: _selectedIds,
                            onSelect: _toggleSelection,
                            onOpen: (vendor) => widget.onVendorTap?.call(vendor),
                            onAction: (vendor, action) =>
                                widget.onVendorAction?.call(vendor, action),
                          );
                        }
                        final tablet = constraints.maxWidth >= 720;
                        final horizontal = tablet ? 24.0 : 12.0;
                        if (!tablet) {
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              8,
                              horizontal,
                              88,
                            ),
                            itemCount: vendors.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _VendorCard(
                              vendor: vendors[index],
                              selected: _selectedIds.contains(vendors[index].id),
                              selectionMode: _selectionMode,
                              onTap: () => _selectionMode
                                  ? _toggleSelection(vendors[index])
                                  : widget.onVendorTap?.call(vendors[index]),
                              onLongPress: () => _toggleSelection(vendors[index]),
                              onAction: (action) =>
                                  widget.onVendorAction?.call(vendors[index], action),
                            ),
                          );
                        }
                        return GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            12,
                            horizontal,
                            88,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 210,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: vendors.length,
                          itemBuilder: (context, index) => _VendorCard(
                            vendor: vendors[index],
                            selected: _selectedIds.contains(vendors[index].id),
                            selectionMode: _selectionMode,
                            onTap: () => _selectionMode
                                ? _toggleSelection(vendors[index])
                                : widget.onVendorTap?.call(vendors[index]),
                            onLongPress: () => _toggleSelection(vendors[index]),
                            onAction: (action) =>
                                widget.onVendorAction?.call(vendors[index], action),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectionMode || desktop
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onNewVendor,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(
    String value,
    String label, {
    required bool isSelected,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF84B01E).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF84B01E) : const Color(0xFF1F2937),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: Color(0xFF84B01E),
              ),
          ],
        ),
      ),
    );
  }
}

class _VendorTable extends StatelessWidget {
  const _VendorTable({
    required this.vendors,
    required this.selectedIds,
    required this.onSelect,
    required this.onOpen,
    required this.onAction,
  });

  final List<VendorListItem> vendors;
  final Set<String> selectedIds;
  final ValueChanged<VendorListItem> onSelect;
  final ValueChanged<VendorListItem> onOpen;
  final void Function(VendorListItem vendor, String action) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '\u20b9');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1040),
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  theme.colorScheme.surfaceContainerLowest,
                ),
                showCheckboxColumn: true,
                horizontalMargin: 18,
                columnSpacing: 28,
                columns: const [
                  DataColumn(label: Text('CODE')),
                  DataColumn(label: Text('NAME')),
                  DataColumn(label: Text('COMPANY NAME')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('EMAIL')),
                  DataColumn(label: Text('WORK PHONE')),
                  DataColumn(label: Text('GST TREATMENT')),
                  DataColumn(label: Text('PAYABLES'), numeric: true),
                  DataColumn(label: SizedBox.shrink()),
                ],
                rows: vendors
                    .map((vendor) {
                      final selected = selectedIds.contains(vendor.id);
                      Color? rowColor;
                      if (vendor.status == 'Inactive') {
                        rowColor = const Color(0xFFF3F4F6);
                      } else if (vendor.status == 'Blocked') {
                        rowColor = const Color(0xFFFEF2F2);
                      }

                      return DataRow(
                        color: rowColor != null ? WidgetStatePropertyAll(rowColor) : null,
                        selected: selected,
                        onSelectChanged: (_) => onSelect(vendor),
                        onLongPress: () => onSelect(vendor),
                        cells: [
                          DataCell(
                            Text(
                              vendor.vendorCode.isNotEmpty ? vendor.vendorCode : '-',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              vendor.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => onOpen(vendor),
                          ),
                          DataCell(Text(vendor.companyName)),
                          DataCell(_StatusChip(status: vendor.status)),
                          DataCell(Text(vendor.email ?? '')),
                          DataCell(Text(vendor.workPhone ?? '')),
                          DataCell(
                            Text(
                              vendor.gstTreatment ==
                                      VendorGstTreatment.registeredRegular
                                  ? 'Registered Business - Regular'
                                  : 'Unregistered Business',
                            ),
                          ),
                          DataCell(
                            Text(
                              money.format(vendor.payables),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: vendor.payables == 0
                                    ? FontWeight.w500
                                    : FontWeight.w800,
                                color: vendor.payables == 0
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ),
                          DataCell(
                            PopupMenuButton<String>(
                              tooltip: 'Vendor actions',
                              onSelected: (action) => onAction(vendor, action),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'view',
                                  child: Text('View details'),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  final VendorListItem vendor;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '\u20b9');
    final hasContact =
        (vendor.email?.isNotEmpty ?? false) ||
        (vendor.workPhone?.isNotEmpty ?? false);
    final isInactive = vendor.status == 'Inactive';
    final isBlocked = vendor.status == 'Blocked';

    Color cardColor;
    if (selected) {
      cardColor = colors.primaryContainer;
    } else if (isInactive) {
      cardColor = const Color(0xFF374151); // Dark Charcoal Slate for inactive
    } else if (isBlocked) {
      cardColor = const Color(0xFF7F1D1D); // Dark Crimson Maroon for blocked
    } else {
      cardColor = theme.cardTheme.color ?? colors.surface;
    }

    final isDarkCard = isInactive || isBlocked;
    final titleColor = isDarkCard
        ? Colors.white
        : colors.primary;
    final subtitleColor = isDarkCard
        ? (isBlocked ? const Color(0xFFFCA5A5) : const Color(0xFFD1D5DB))
        : colors.onSurfaceVariant;
    final codeBg = isDarkCard
        ? (isBlocked ? const Color(0xFF450A0A) : const Color(0xFF1F2937))
        : colors.surfaceContainerHighest;
    final codeFg = isDarkCard ? Colors.white : colors.onSurface;

    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                Checkbox(value: selected, onChanged: (_) => onTap()),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (vendor.vendorCode.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: codeBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              vendor.vendorCode,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: codeFg,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            vendor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vendor.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _GstChip(treatment: vendor.gstTreatment, isDarkParent: isDarkCard),
                        const SizedBox(width: 6),
                        _StatusChip(status: vendor.status),
                      ],
                    ),
                    if (hasContact) ...[
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          if (vendor.email?.isNotEmpty ?? false)
                            _Contact(
                              icon: Icons.email_outlined,
                              text: vendor.email!,
                              textColor: isDarkCard ? const Color(0xFF9CA3AF) : null,
                            ),
                          if (vendor.workPhone?.isNotEmpty ?? false)
                            _Contact(
                              icon: Icons.phone_outlined,
                              text: vendor.workPhone!,
                              textColor: isDarkCard ? const Color(0xFF9CA3AF) : null,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Vendor actions',
                    padding: EdgeInsets.zero,
                    onSelected: onAction,
                    iconColor: isDarkCard ? Colors.white70 : null,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'view', child: Text('View details')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    money.format(vendor.payables),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isDarkCard
                          ? Colors.white
                          : (vendor.payables == 0
                              ? colors.onSurfaceVariant
                              : colors.error),
                      fontWeight: vendor.payables == 0
                          ? FontWeight.w600
                          : FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Payables',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDarkCard ? const Color(0xFFD1D5DB) : colors.onSurfaceVariant,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Inactive':
        bg = const Color(0xFF1F2937);
        fg = const Color(0xFFE5E7EB);
        break;
      case 'Blocked':
        bg = const Color(0xFF991B1B);
        fg = Colors.white;
        break;
      case 'Active':
      default:
        bg = const Color(0xFFF4F8E8);
        fg = const Color(0xFF84B01E);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _GstChip extends StatelessWidget {
  const _GstChip({required this.treatment, this.isDarkParent = false});

  final VendorGstTreatment treatment;
  final bool isDarkParent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final registered = treatment == VendorGstTreatment.registeredRegular;

    if (isDarkParent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          registered ? 'Registered Business' : 'Unregistered',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFFD1D5DB),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final foreground = registered ? colors.primary : colors.secondary;
    final background = registered
        ? colors.primaryContainer
        : colors.secondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: foreground.withValues(alpha: .35)),
      ),
      child: Text(
        registered ? 'Registered Business' : 'Unregistered',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.icon, required this.text, this.textColor});

  final IconData icon;
  final String text;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = textColor ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptyVendorsState extends StatelessWidget {
  const _EmptyVendorsState({required this.hasFilters, required this.onClear});

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * .24),
        Icon(
          Icons.storefront_outlined,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        Text(
          'No vendors found',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (hasFilters) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: onClear,
              child: const Text('Clear filters'),
            ),
          ),
        ],
      ],
    );
  }
}
