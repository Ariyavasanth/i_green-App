import 'package:flutter/material.dart';
import '../../domain/models/site_project.dart';

/// Searchable modal dialog for picking a [SiteProject].
class ProjectPickerDialog extends StatefulWidget {
  const ProjectPickerDialog({
    super.key,
    required this.projects,
    this.selectedProjectCode,
    required this.onSelected,
  });

  final List<SiteProject> projects;
  final String? selectedProjectCode;
  final ValueChanged<SiteProject> onSelected;

  static Future<SiteProject?> show(
    BuildContext context, {
    required List<SiteProject> projects,
    String? selectedProjectCode,
  }) async {
    return showDialog<SiteProject>(
      context: context,
      builder: (ctx) => ProjectPickerDialog(
        projects: projects,
        selectedProjectCode: selectedProjectCode,
        onSelected: (project) => Navigator.pop(ctx, project),
      ),
    );
  }

  @override
  State<ProjectPickerDialog> createState() => _ProjectPickerDialogState();
}

class _ProjectPickerDialogState extends State<ProjectPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    const darkTextColor = Color(0xFF414A51);

    final filtered = widget.projects.where((p) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase().trim();
      final code = p.projectCode.toLowerCase();
      final client = p.clientName.toLowerCase();
      final place = p.place.toLowerCase();
      final district = p.district.toLowerCase();
      final general = p.generalCode.toLowerCase();
      return code.contains(q) ||
          client.contains(q) ||
          place.contains(q) ||
          district.contains(q) ||
          general.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF8FAFC),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 420,
        height: 520,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_outlined, color: darkTextColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Select Project Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkTextColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by project code, client, place...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 12),

            // List of Projects
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _query.isEmpty ? 'No projects available' : 'No matching project codes found',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final project = filtered[i];
                        final isSelected = widget.selectedProjectCode != null &&
                            widget.selectedProjectCode == project.projectCode;

                        final subtitleParts = <String>[];
                        if (project.clientName.trim().isNotEmpty) subtitleParts.add(project.clientName.trim());
                        if (project.place.trim().isNotEmpty) subtitleParts.add(project.place.trim());

                        return InkWell(
                          onTap: () => widget.onSelected(project),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.25)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.folder_open_rounded,
                                    size: 18,
                                    color: isSelected ? darkTextColor : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        project.projectCode,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? darkTextColor : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      if (subtitleParts.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitleParts.join(' • '),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: primaryColor, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
