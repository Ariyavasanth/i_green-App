import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../tenders/domain/models/company_document_item.dart';
import '../../../tenders/providers/company_document_providers.dart';
import '../widgets/site_projects_dashboard_card.dart';

class ProjectDashboardScreen extends ConsumerWidget {
  const ProjectDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 1200
        ? 32.0
        : screenWidth > 650
            ? 24.0
            : 16.0;

    final companyDocsAsync = ref.watch(companyDocumentsStreamProvider);
    final expiringLicences = companyDocsAsync.valueOrNull
            ?.where((d) =>
                (d.docType == CompanyDocType.license ||
                    d.title.toLowerCase().contains('labour') ||
                    d.title.toLowerCase().contains('license')) &&
                (d.isExpiringSoon || d.isExpired))
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/module/project');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.dashboard_rounded,
                size: 20,
                color: Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'DASHBOARD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E8E2), height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/new'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'NEW PROJECT',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            80, // Padding for floating action button
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (expiringLicences.isNotEmpty) ...[
                    Card(
                      color: const Color(0xFFFFFBEB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFD97706), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Labour Licence Expiry Warning',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    expiringLicences
                                        .map((l) =>
                                            '${l.title} (${l.isExpired ? "EXPIRED" : "Expires: ${DateFormat("dd-MM-yyyy").format(l.expiryDate!)}"})')
                                        .join(' • '),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF78350F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF92400E)),
                              onPressed: () =>
                                  context.push('/projects/company-documents'),
                              icon: const Icon(Icons.folder_shared_outlined,
                                  size: 16),
                              label: const Text('Open Vault',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SiteProjectsDashboardCard(
                    showTitleHeader: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
