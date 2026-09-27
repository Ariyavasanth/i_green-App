import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/organization.dart';

class CollectionMigrationSummary {
  final String collectionName;
  final int totalScanned;
  final int alreadyMigrated;
  final int matched;
  final int unmatched;
  final int ambiguous;
  final List<String> unmatchedDetails;
  final List<String> ambiguousDetails;
  final List<String> matchedDetails;

  const CollectionMigrationSummary({
    required this.collectionName,
    required this.totalScanned,
    required this.alreadyMigrated,
    required this.matched,
    required this.unmatched,
    required this.ambiguous,
    this.unmatchedDetails = const [],
    this.ambiguousDetails = const [],
    this.matchedDetails = const [],
  });
}

class MigrationReport {
  final bool isDryRun;
  final int totalOrganizationsFound;
  final List<Organization> organizations;
  final Map<String, CollectionMigrationSummary> collectionSummaries;
  final DateTime timestamp;

  const MigrationReport({
    required this.isDryRun,
    required this.totalOrganizationsFound,
    required this.organizations,
    required this.collectionSummaries,
    required this.timestamp,
  });

  int get totalMatched =>
      collectionSummaries.values.fold(0, (sum, s) => sum + s.matched);
  int get totalUnmatched =>
      collectionSummaries.values.fold(0, (sum, s) => sum + s.unmatched);
  int get totalAmbiguous =>
      collectionSummaries.values.fold(0, (sum, s) => sum + s.ambiguous);
  int get totalAlreadyMigrated =>
      collectionSummaries.values.fold(0, (sum, s) => sum + s.alreadyMigrated);

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln(' HRMS ORGANIZATION ID MIGRATION REPORT (${isDryRun ? "DRY-RUN" : "APPLIED"})');
    buffer.writeln(' Timestamp: ${timestamp.toIso8601String()}');
    buffer.writeln('====================================================');
    buffer.writeln('Organizations Found in Firestore: $totalOrganizationsFound');
    for (final org in organizations) {
      buffer.writeln(' - [ID: ${org.canonicalId}] "${org.name}" (status: ${org.status})');
    }
    buffer.writeln('----------------------------------------------------');

    for (final entry in collectionSummaries.entries) {
      final s = entry.value;
      buffer.writeln('Collection: ${s.collectionName}');
      buffer.writeln('  • Total scanned: ${s.totalScanned}');
      buffer.writeln('  • Already has organization_id: ${s.alreadyMigrated}');
      buffer.writeln('  • Matched (ready to migrate): ${s.matched}');
      buffer.writeln('  • Unmatched (no matching org): ${s.unmatched}');
      buffer.writeln('  • Ambiguous (multiple matches): ${s.ambiguous}');

      if (s.unmatchedDetails.isNotEmpty) {
        buffer.writeln('  Unmatched Records:');
        for (final u in s.unmatchedDetails.take(10)) {
          buffer.writeln('    - $u');
        }
        if (s.unmatchedDetails.length > 10) {
          buffer.writeln('    ... and ${s.unmatchedDetails.length - 10} more');
        }
      }

      if (s.ambiguousDetails.isNotEmpty) {
        buffer.writeln('  Ambiguous Records:');
        for (final a in s.ambiguousDetails.take(10)) {
          buffer.writeln('    - $a');
        }
      }
      buffer.writeln('');
    }

    buffer.writeln('====================================================');
    buffer.writeln('TOTAL SUMMARY:');
    buffer.writeln('  Already Migrated: $totalAlreadyMigrated');
    buffer.writeln('  Matched: $totalMatched');
    buffer.writeln('  Unmatched: $totalUnmatched');
    buffer.writeln('  Ambiguous: $totalAmbiguous');
    buffer.writeln('====================================================');
    return buffer.toString();
  }
}

/// Generic, client-agnostic migration utility to bind existing Firestore records to canonical organization IDs.
class OrganizationMigrationService {
  final FirebaseFirestore _firestore;

  OrganizationMigrationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const List<String> targetCollections = [
    'employees',
    'departments',
    'designations',
    'business_units',
    'locations',
    'registration_links',
    'candidate_responses',
  ];

  /// Runs a safe dry-run (read-only) or actual migration.
  Future<MigrationReport> runMigration({bool dryRun = true}) async {
    final orgsSnap = await _firestore.collection('organizations').get();
    final organizations = orgsSnap.docs.map((d) {
      return Organization.fromMap(d.data(), d.id);
    }).toList();

    // Index organizations by normalized name
    final Map<String, List<Organization>> nameToOrgs = {};
    for (final org in organizations) {
      final normName = _normalize(org.name);
      if (normName.isNotEmpty) {
        nameToOrgs.putIfAbsent(normName, () => []).add(org);
      }
    }

    final collectionSummaries = <String, CollectionMigrationSummary>{};

    for (final colName in targetCollections) {
      final summary = await _processCollection(
        collectionName: colName,
        nameToOrgs: nameToOrgs,
        dryRun: dryRun,
      );
      collectionSummaries[colName] = summary;
    }

    return MigrationReport(
      isDryRun: dryRun,
      totalOrganizationsFound: organizations.length,
      organizations: organizations,
      collectionSummaries: collectionSummaries,
      timestamp: DateTime.now(),
    );
  }

  Future<CollectionMigrationSummary> _processCollection({
    required String collectionName,
    required Map<String, List<Organization>> nameToOrgs,
    required bool dryRun,
  }) async {
    final colRef = _firestore.collection(collectionName);
    final snapshot = await colRef.get();

    int alreadyMigrated = 0;
    int matched = 0;
    int unmatched = 0;
    int ambiguous = 0;

    final unmatchedDetails = <String>[];
    final ambiguousDetails = <String>[];
    final matchedDetails = <String>[];

    final pendingUpdates = <DocumentReference, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingOrgId = (data['organization_id'] ?? data['organizationId'] ?? data['org_id'])?.toString().trim();
      final rawOrgName = (data['organization_name'] ?? data['organizationName'])?.toString().trim() ?? '';

      // If document already has a valid non-empty organization_id and it's not a placeholder
      if (existingOrgId != null && existingOrgId.isNotEmpty && existingOrgId != '0') {
        alreadyMigrated++;
        continue;
      }

      if (rawOrgName.isEmpty) {
        unmatched++;
        unmatchedDetails.add('Doc ID "${doc.id}": missing organization_name field');
        continue;
      }

      final norm = _normalize(rawOrgName);
      final matches = nameToOrgs[norm] ?? [];

      if (matches.isEmpty) {
        unmatched++;
        unmatchedDetails.add('Doc ID "${doc.id}": name "$rawOrgName" does not match any organization');
      } else if (matches.length > 1) {
        ambiguous++;
        ambiguousDetails.add(
          'Doc ID "${doc.id}": name "$rawOrgName" matches ${matches.length} organizations (${matches.map((m) => m.canonicalId).join(", ")})',
        );
      } else {
        matched++;
        final targetOrg = matches.first;
        matchedDetails.add('Doc ID "${doc.id}": linked to [${targetOrg.canonicalId}] "${targetOrg.name}"');
        pendingUpdates[doc.reference] = {
          'organization_id': targetOrg.canonicalId,
          'organization_name': targetOrg.name,
        };
      }
    }

    // Apply updates if NOT dry run
    if (!dryRun && pendingUpdates.isNotEmpty) {
      final chunks = <Map<DocumentReference, Map<String, dynamic>>>[];
      var currentChunk = <DocumentReference, Map<String, dynamic>>{};
      for (final entry in pendingUpdates.entries) {
        currentChunk[entry.key] = entry.value;
        if (currentChunk.length >= 400) {
          chunks.add(currentChunk);
          currentChunk = {};
        }
      }
      if (currentChunk.isNotEmpty) {
        chunks.add(currentChunk);
      }

      for (final chunk in chunks) {
        final batch = _firestore.batch();
        for (final item in chunk.entries) {
          batch.set(item.key, item.value, SetOptions(merge: true));
        }
        await batch.commit();
      }
      debugPrint('[OrganizationMigrationService] Applied ${pendingUpdates.length} updates to collection "$collectionName".');
    }

    return CollectionMigrationSummary(
      collectionName: collectionName,
      totalScanned: snapshot.docs.length,
      alreadyMigrated: alreadyMigrated,
      matched: matched,
      unmatched: unmatched,
      ambiguous: ambiguous,
      unmatchedDetails: unmatchedDetails,
      ambiguousDetails: ambiguousDetails,
      matchedDetails: matchedDetails,
    );
  }

  String _normalize(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
