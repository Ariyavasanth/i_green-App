import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/firebase_company_document_repository.dart';
import '../domain/models/bqr_requirement_item.dart';
import '../domain/models/company_document_item.dart';
import '../domain/repositories/company_document_repository.dart';
import '../../projects/domain/models/project_document.dart';

final companyDocumentRepositoryProvider =
    Provider<CompanyDocumentRepository>((ref) {
  return FirebaseCompanyDocumentRepository();
});

final companyDocumentsStreamProvider =
    StreamProvider<List<CompanyDocumentItem>>((ref) {
  return ref.watch(companyDocumentRepositoryProvider).watchDocuments();
});

/// Returns YYYY-MM strings for the past [monthsBack] months that have no
/// uploaded challan for [challanType] (e.g., PF_CHALLAN, ESI_CHALLAN, GST_CHALLAN).
List<String> findMissingChallanMonths(
  List<CompanyDocumentItem> docs,
  CompanyDocType challanType, {
  int monthsBack = 6,
}) {
  final existing = docs
      .where((d) => d.docType == challanType && (d.monthYear ?? '').isNotEmpty)
      .map((d) => d.monthYear!.trim())
      .toSet();

  final now = DateTime.now();
  final missing = <String>[];
  for (var i = 0; i < monthsBack; i++) {
    final dt = DateTime(now.year, now.month - i, 1);
    final ym = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    if (!existing.contains(ym)) {
      missing.add(ym);
    }
  }
  return missing;
}

/// AI/Smart Fetch: matches stored company documents to each BQR requirement
/// line item based on requirement keywords and document types.
List<BqrRequirementItem> matchCompanyDocsToBqr(
  List<BqrRequirementItem> bqrItems,
  List<CompanyDocumentItem> companyDocs,
) {
  return bqrItems.map((item) {
    final q = '${item.title} ${item.description}'.toLowerCase();
    final matched = <ProjectDocument>[...item.documents];
    final existingUrls = matched.map((d) => d.downloadUrl).toSet();

    for (final doc in companyDocs) {
      if (doc.isExpired) continue;
      bool hits = false;
      if ((q.contains('itr') || q.contains('income tax') || q.contains('turnover')) &&
          doc.docType == CompanyDocType.itr) {
        hits = true;
      } else if (q.contains('pf') &&
          (doc.docType == CompanyDocType.pfCertificate ||
              doc.docType == CompanyDocType.pfChallan)) {
        hits = true;
      } else if (q.contains('esi') &&
          (doc.docType == CompanyDocType.esiCertificate ||
              doc.docType == CompanyDocType.esiChallan)) {
        hits = true;
      } else if (q.contains('gst') &&
          (doc.docType == CompanyDocType.gstCertificate ||
              doc.docType == CompanyDocType.gstChallan)) {
        hits = true;
      } else if ((q.contains('experience') || q.contains('completion') || q.contains('work order')) &&
          doc.docType == CompanyDocType.experienceCertificate) {
        hits = true;
      } else if ((q.contains('licen') || q.contains('registration') || q.contains('vendor')) &&
          (doc.docType == CompanyDocType.license ||
              doc.docType == CompanyDocType.vendorAuth ||
              doc.docType == CompanyDocType.registration)) {
        hits = true;
      }

      if (hits && !existingUrls.contains(doc.document.downloadUrl)) {
        matched.add(doc.document);
        existingUrls.add(doc.document.downloadUrl);
      }
    }

    return item.copyWith(
      documents: matched,
      status: matched.isNotEmpty ? 'uploaded' : item.status,
    );
  }).toList();
}

