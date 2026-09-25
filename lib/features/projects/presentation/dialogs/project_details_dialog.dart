import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/project_document.dart';
import '../../domain/models/site_project.dart';

class ProjectDetailsDialog extends StatelessWidget {
  const ProjectDetailsDialog({required this.project, super.key});

  final SiteProject project;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            size: 20,
                            color: Color(0xFF9C27B0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.projectCode.isNotEmpty
                                    ? project.projectCode
                                    : 'Site Project Details',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF414A51),
                                ),
                              ),
                              if (project.generalCode.isNotEmpty)
                                Text(
                                  'General Code: ${project.generalCode}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CC70A),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE5E8E2)),
              const SizedBox(height: 14),

              // Details Body
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(
                        title: 'GENERAL & CLIENT DETAILS',
                        items: [
                          _InfoPair('Client Name', project.clientName),
                          _InfoPair('Place', project.place.isNotEmpty ? project.place : '—'),
                          _InfoPair('Created By', project.employeeName),
                          _InfoPair('General Details', project.generalDetails.isNotEmpty ? project.generalDetails : '—'),
                        ],
                        isMobile: isMobile,
                      ),
                      const SizedBox(height: 14),
                      _buildInfoSection(
                        title: 'LOCATION & CLASSIFICATION',
                        items: [
                          _InfoPair('Sub or Own', project.subOrOwn),
                          _InfoPair('State', project.state.isNotEmpty ? project.state : '—'),
                          _InfoPair('District', project.district.isNotEmpty ? project.district : '—'),
                          _InfoPair('Area', project.area.isNotEmpty ? project.area : '—'),
                        ],
                        isMobile: isMobile,
                      ),
                      const SizedBox(height: 14),
                      _buildInfoSection(
                        title: 'TENDER & ASSIGNMENT',
                        items: [
                          _InfoPair('Tender Type', project.tenderType.isNotEmpty ? project.tenderType : '—'),
                          _InfoPair('Assigned To', project.assignedToEmployeeName),
                          _InfoPair('Opening Date', project.openingDate != null ? DateFormat('dd-MM-yyyy').format(project.openingDate!) : '—'),
                          _InfoPair('Closing Date', project.closingDate != null ? DateFormat('dd-MM-yyyy').format(project.closingDate!) : '—'),
                        ],
                        isMobile: isMobile,
                      ),
                      if (project.openingDateRemark.isNotEmpty || project.closingDateRemark.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildInfoSection(
                          title: 'DATE REMARKS',
                          items: [
                            if (project.openingDateRemark.isNotEmpty)
                              _InfoPair('Opening Date Remark', project.openingDateRemark),
                            if (project.closingDateRemark.isNotEmpty)
                              _InfoPair('Closing Date Remark', project.closingDateRemark),
                          ],
                          isMobile: isMobile,
                        ),
                      ],
                      if (project.tenderSpecRemark.isNotEmpty || project.tenderSpecDocuments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildDocsSection(
                          title: 'TENDER / ENQUIRY SPEC',
                          remark: project.tenderSpecRemark,
                          docs: project.tenderSpecDocuments,
                        ),
                      ],
                      if (project.bqrRemark.isNotEmpty || project.bqrDocuments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildDocsSection(
                          title: 'BQR (BIDDER QUALIFICATION REQUIREMENT)',
                          remark: project.bqrRemark,
                          docs: project.bqrDocuments,
                        ),
                      ],
                      if (project.emdRemark.isNotEmpty || project.emdDocuments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildDocsSection(
                          title: 'EMD / EMD EXEMPTION',
                          remark: project.emdRemark,
                          docs: project.emdDocuments,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'Created on ${DateFormat('dd MMM yyyy, hh:mm a').format(project.createdAt)} by ${project.createdBy.isNotEmpty ? project.createdBy : project.employeeName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<_InfoPair> items,
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CC70A),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          if (isMobile)
            Column(
              children: items.map((i) => _buildRow(i.label, i.value)).toList(),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: items
                  .map((i) => SizedBox(
                        width: 280,
                        child: _buildRow(i.label, i.value),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF414A51),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocsSection({
    required String title,
    required String remark,
    required List<ProjectDocument> docs,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CC70A),
              letterSpacing: 0.8,
            ),
          ),
          if (remark.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              remark,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF414A51),
              ),
            ),
          ],
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final doc in docs)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.attachment_rounded, size: 16, color: Color(0xFF718096)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        doc.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(doc.size / 1024).toStringAsFixed(0)} KB',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (doc.downloadUrl.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final uri = Uri.tryParse(doc.downloadUrl);
                          if (uri != null) launchUrl(uri);
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoPair {
  const _InfoPair(this.label, this.value);
  final String label;
  final String value;
}
