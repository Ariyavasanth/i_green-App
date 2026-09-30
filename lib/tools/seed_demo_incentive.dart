import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Seeds sample approved incentive data for Priya M
/// - Request on 21 August 2026 (September Payroll Cycle: 21 Aug - 20 Sep 2026)
Future<void> seedDemoIncentives() async {
  try {
    final firestore = FirebaseFirestore.instance;
    final collection = firestore.collection('incentive_requests');

    // Priya M (EMP5409) - Approved on 21 August 2026 (September cycle: 21 Aug - 20 Sep 2026)
    final priyaIncentiveAug21 = <String, dynamic>{
      'id': 540901,
      'request_id': 'INC-540901',
      'employee_id': 5409,
      'employee_name': 'Priya M',
      'designation': 'Operator',
      'site': 'PRJ-SUB-AEP-TA-CHE-001',
      'product_name': 'Submersible Cable',
      'meters': 500.0,
      'rate': 10.0,
      'amount': 5000.0,
      'verified_meters': 500.0,
      'approved_amount': 5000.0,
      'status': 'Approved',
      'remarks': 'Approved on 21 August 2026',
      'created_at': '2026-08-21T10:00:00.000Z',
      'updated_at': FieldValue.serverTimestamp(),
    };

    await collection.doc('demo_priya_m_incentive_aug20').set(
      priyaIncentiveAug21,
      SetOptions(merge: true),
    );

    await collection.doc('demo_priya_m_incentive_sep_cycle').set(
      priyaIncentiveAug21,
      SetOptions(merge: true),
    );

    debugPrint('✅ [Demo Seeder] Successfully seeded approved incentive for Priya M on 21 August 2026.');
  } catch (e) {
    debugPrint('⚠️ [Demo Seeder] Error seeding demo incentives: $e');
  }
}
