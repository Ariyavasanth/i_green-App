import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/project_document.dart';
import '../../domain/models/site_project.dart';
import '../../../employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../../employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../../employee/services/offer_letter_save_io.dart';

class ProjectDetailsDialog extends StatelessWidget {
  const ProjectDetailsDialog({required this.project, super.key});

  final SiteProject project;

  static String? _formatStorageError(dynamic e) {
    if (e == null) return null;
    final str = e.toString().toLowerCase();
    final message = (e is FirebaseException ? e.message?.toLowerCase() : '') ?? '';

    if (str.contains('402') ||
        str.contains('payment required') ||
        message.contains('402') ||
        message.contains('payment required') ||
        str.contains('delinquent')) {
      return 'Firebase Cloud Storage requires an active Blaze plan or billing account (HTTP 402 Payment Required). Please check your Firebase Console.';
    }

    if (str.contains('quota-exceeded') ||
        (e is FirebaseException && e.code == 'quota-exceeded')) {
      return 'Firebase Cloud Storage quota exceeded. Please check your storage quota in Firebase Console.';
    }

    if (str.contains('unauthorized') ||
        str.contains('permission-denied') ||
        (e is FirebaseException &&
            (e.code == 'permission-denied' || e.code == 'unauthenticated'))) {
      return 'Storage permission denied. Please verify your Firebase Storage security rules.';
    }

    return null;
  }

  Future<({String url, String? error})> _resolveFileUrl(ProjectDocument doc) async {
    String url = doc.downloadUrl.trim();
    if (url.isNotEmpty) return (url: url, error: null);

    try {
      final storage = FirebaseStorage.instance;
      final projId = project.id.isNotEmpty ? project.id : '';
      final projCode = project.projectCode.isNotEmpty ? project.projectCode : '';
      final cleanFileName = doc.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final rawFileName = doc.name;

      final candidates = <String>[
        if (doc.storagePath.isNotEmpty) doc.storagePath,
        if (projCode.isNotEmpty) ...[
          'project module/$projCode/$rawFileName',
          'project module/$projCode/$cleanFileName',
          if (doc.category.isNotEmpty) ...[
            'project module/$projCode/${doc.category}/$rawFileName',
            'project module/$projCode/${doc.category}/$cleanFileName',
          ],
          'Project module/$projCode/$rawFileName',
          'Project module/$projCode/$cleanFileName',
          'projects/$projCode/$rawFileName',
          'projects/$projCode/$cleanFileName',
          if (doc.category.isNotEmpty) ...[
            'projects/$projCode/${doc.category}/$rawFileName',
            'projects/$projCode/${doc.category}/$cleanFileName',
          ],
        ],
        if (projId.isNotEmpty) ...[
          'project module/$projId/$rawFileName',
          'project module/$projId/$cleanFileName',
          if (doc.category.isNotEmpty) ...[
            'project module/$projId/${doc.category}/$rawFileName',
            'project module/$projId/${doc.category}/$cleanFileName',
          ],
          'Project module/$projId/$rawFileName',
          'Project module/$projId/$cleanFileName',
          'projects/$projId/$rawFileName',
          'projects/$projId/$cleanFileName',
          if (doc.category.isNotEmpty) ...[
            'projects/$projId/${doc.category}/$rawFileName',
            'projects/$projId/${doc.category}/$cleanFileName',
          ],
        ],
      ];

      for (final path in candidates) {
        try {
          final resolved = await storage.ref().child(path).getDownloadURL();
          if (resolved.isNotEmpty) return (url: resolved, error: null);
        } catch (e) {
          final fatal = _formatStorageError(e);
          if (fatal != null) return (url: '', error: fatal);
        }
      }

      final folderCandidates = <String>[
        if (projCode.isNotEmpty) ...[
          'project module/$projCode',
          if (doc.category.isNotEmpty) 'project module/$projCode/${doc.category}',
          'Project module/$projCode',
          'projects/$projCode',
          if (doc.category.isNotEmpty) 'projects/$projCode/${doc.category}',
        ],
        if (projId.isNotEmpty) ...[
          'project module/$projId',
          if (doc.category.isNotEmpty) 'project module/$projId/${doc.category}',
          'Project module/$projId',
          'projects/$projId',
          if (doc.category.isNotEmpty) 'projects/$projId/${doc.category}',
        ],
      ];

      for (final folder in folderCandidates) {
        try {
          final listResult = await storage.ref().child(folder).listAll();
          for (final item in listResult.items) {
            if (item.name.toLowerCase().contains(cleanFileName.toLowerCase()) ||
                item.name.toLowerCase().contains(rawFileName.toLowerCase())) {
              final resolved = await item.getDownloadURL();
              if (resolved.isNotEmpty) return (url: resolved, error: null);
            }
          }
        } catch (e) {
          final fatal = _formatStorageError(e);
          if (fatal != null) return (url: '', error: fatal);
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('[FirebaseStorage] Error: ${e.code} - ${e.message}');
      final msg = _formatStorageError(e) ?? (e.message ?? e.code);
      return (url: '', error: msg);
    } catch (e) {
      debugPrint('[FirebaseStorage] Unexpected error: $e');
      final msg = _formatStorageError(e) ?? e.toString();
      return (url: '', error: msg);
    }

    return (url: '', error: null);
  }

  Future<void> _handleView(BuildContext context, ProjectDocument doc) async {
    final result = await _resolveFileUrl(doc);
    final url = result.url;
    if (url.isEmpty) {
      if (context.mounted) {
        final msg = (result.error != null && result.error!.isNotEmpty)
            ? result.error!
            : 'Document link not available for ${doc.name}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document link.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  Future<void> _handleDownload(BuildContext context, ProjectDocument doc) async {
    final result = await _resolveFileUrl(doc);
    final url = result.url;
    if (url.isEmpty) {
      if (context.mounted) {
        final msg = (result.error != null && result.error!.isNotEmpty)
            ? result.error!
            : 'Document link not available for ${doc.name}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      await downloadFileFromUrl(
        context: context,
        url: url,
        fileName: doc.name.isNotEmpty ? doc.name : 'project_document',
        docTitle: doc.name,
      );
    }
  }

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
                          _InfoPair('Approximate Project Value',
                              project.approximateProjectValue > 0
                                  ? NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(project.approximateProjectValue)
                                  : '—'),
                          _InfoPair('Actual Project Value',
                              project.actualProjectValue > 0
                                  ? NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(project.actualProjectValue)
                                  : '—'),
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
                          context,
                          title: 'TENDER / ENQUIRY SPEC',
                          remark: project.tenderSpecRemark,
                          docs: project.tenderSpecDocuments,
                        ),
                      ],
                      if (project.bqrRemark.isNotEmpty || project.bqrDocuments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildDocsSection(
                          context,
                          title: 'BQR (BIDDER QUALIFICATION REQUIREMENT)',
                          remark: project.bqrRemark,
                          docs: project.bqrDocuments,
                        ),
                      ],
                      if (project.emdRemark.isNotEmpty || project.emdDocuments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildDocsSection(
                          context,
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

  Widget _buildDocsSection(
    BuildContext context, {
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
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E8E2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attachment_rounded, size: 16, color: Color(0xFF718096)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF414A51),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (doc.size > 0) ...[
                      Text(
                        '${(doc.size / 1024).toStringAsFixed(0)} KB',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF414A51),
                        side: const BorderSide(color: Color(0xFFD0D5DD)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(54, 28),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _handleView(context, doc),
                      icon: const Icon(Icons.open_in_new_rounded, size: 12),
                      label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(64, 28),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _handleDownload(context, doc),
                      icon: const Icon(Icons.download_rounded, size: 13),
                      label: const Text('Download', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
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
