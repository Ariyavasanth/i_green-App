import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum VendorGstTreatment { registeredRegular, unregistered }

@immutable
class VendorListItem {
  const VendorListItem({
    required this.id,
    required this.name,
    required this.companyName,
    required this.gstTreatment,
    this.payables = 0,
    this.email,
    this.workPhone,
  });

  final String id;
  final String name;
  final String companyName;
  final VendorGstTreatment gstTreatment;
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
  bool _showSearch = false;
  VendorGstTreatment? _filter;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  List<VendorListItem> get _visibleVendors {
    final query = _searchController.text.trim().toLowerCase();
    return widget.vendors
        .where((vendor) {
          final matchesFilter =
              _filter == null || vendor.gstTreatment == _filter;
          final searchable =
              '${vendor.name} ${vendor.companyName} '
                      '${vendor.email ?? ''} ${vendor.workPhone ?? ''}'
                  .toLowerCase();
          return matchesFilter && (query.isEmpty || searchable.contains(query));
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
    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                tooltip: 'Cancel selection',
                onPressed: () => setState(_selectedIds.clear),
                icon: const Icon(Icons.close),
              )
            : null,
        title: _selectionMode
            ? Text('${_selectedIds.length} selected')
            : PopupMenuButton<String>(
                initialValue: _filter?.name ?? 'all',
                onSelected: (value) => setState(() {
                  _filter = switch (value) {
                    'registeredRegular' => VendorGstTreatment.registeredRegular,
                    'unregistered' => VendorGstTreatment.unregistered,
                    _ => null,
                  };
                }),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'all', child: Text('All Vendors')),
                  PopupMenuItem(
                    value: 'registeredRegular',
                    child: Text('Registered Business - Regular'),
                  ),
                  PopupMenuItem(
                    value: 'unregistered',
                    child: Text('Unregistered Business'),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_filter == null ? 'All Vendors' : 'Filtered Vendors'),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
        actions: [
          if (!_selectionMode)
            IconButton(
              tooltip: 'Search vendors',
              onPressed: () => setState(() => _showSearch = !_showSearch),
              icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            ),
          if (!_selectionMode && desktop) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: FilledButton.icon(
                onPressed: widget.onNewVendor,
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
        bottom: _showSearch && !_selectionMode
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search vendors',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: vendors.isEmpty
            ? _EmptyVendorsState(
                hasFilters:
                    _filter != null || _searchController.text.isNotEmpty,
                onClear: () {
                  _searchController.clear();
                  setState(() => _filter = null);
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
                        12,
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
                      16,
                      horizontal,
                      88,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 196,
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
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 920),
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  theme.colorScheme.surfaceContainerLowest,
                ),
                showCheckboxColumn: true,
                horizontalMargin: 18,
                columnSpacing: 32,
                columns: const [
                  DataColumn(label: Text('NAME')),
                  DataColumn(label: Text('COMPANY NAME')),
                  DataColumn(label: Text('EMAIL')),
                  DataColumn(label: Text('WORK PHONE')),
                  DataColumn(label: Text('GST TREATMENT')),
                  DataColumn(label: Text('PAYABLES'), numeric: true),
                  DataColumn(label: SizedBox.shrink()),
                ],
                rows: vendors
                    .map((vendor) {
                      final selected = selectedIds.contains(vendor.id);
                      return DataRow(
                        selected: selected,
                        onSelectChanged: (_) => onSelect(vendor),
                        onLongPress: () => onSelect(vendor),
                        cells: [
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
    return Card(
      color: selected ? colors.primaryContainer : theme.cardTheme.color,
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
                    Text(
                      vendor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vendor.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GstChip(treatment: vendor.gstTreatment),
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
                            ),
                          if (vendor.workPhone?.isNotEmpty ?? false)
                            _Contact(
                              icon: Icons.phone_outlined,
                              text: vendor.workPhone!,
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
                      color: vendor.payables == 0
                          ? colors.onSurfaceVariant
                          : colors.error,
                      fontWeight: vendor.payables == 0
                          ? FontWeight.w600
                          : FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Payables',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
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

class _GstChip extends StatelessWidget {
  const _GstChip({required this.treatment});

  final VendorGstTreatment treatment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final registered = treatment == VendorGstTreatment.registeredRegular;
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
        registered ? 'Registered Business - Regular' : 'Unregistered Business',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
