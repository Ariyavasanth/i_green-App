import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/authentication_repository.dart';

class FirebaseAuthenticationRepository implements AuthenticationRepository {
  final FirebaseFirestore _firestore;

  FirebaseAuthenticationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> requestOtp(String email) async {
    // Immediate return without artificial delay
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getDocFast(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final cacheSnap = await ref
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(milliseconds: 300));
      if (cacheSnap.exists && cacheSnap.data() != null) return cacheSnap;
    } catch (_) {}

    try {
      return await ref.get().timeout(const Duration(seconds: 4));
    } catch (_) {
      try {
        return await ref.get(const GetOptions(source: Source.cache));
      } catch (_) {
        return null;
      }
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _getQueryFast(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      final cacheSnap = await query
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(milliseconds: 300));
      if (cacheSnap.docs.isNotEmpty) return cacheSnap;
    } catch (_) {}

    try {
      return await query.get().timeout(const Duration(seconds: 4));
    } catch (_) {
      try {
        return await query.get(const GetOptions(source: Source.cache));
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<bool> verifyOtp({required String email, required String otp}) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    if (cleanEmail.isEmpty || cleanOtp.isEmpty) {
      return false;
    }

    final isAdminAlias = cleanEmail == 'admin' ||
        cleanEmail == 'super admin' ||
        cleanEmail == 'superadmin';

    // Quick pass for bootstrap super admin password
    if (isAdminAlias && (cleanOtp == 'admin123' || cleanOtp == 'Admin@123')) {
      return true;
    }

    try {
      final candidates = <Map<String, dynamic>>[];

      // 1. Direct super admin lookup
      if (isAdminAlias) {
        final q = await _getQueryFast(
          _firestore
              .collection('employees')
              .where('is_super_admin', isEqualTo: true)
              .limit(1),
        );
        if (q != null && q.docs.isNotEmpty) {
          candidates.add(q.docs.first.data());
        } else {
          final q2 = await _getQueryFast(
            _firestore
                .collection('employees')
                .where('user_type', isEqualTo: 'SUPER ADMIN')
                .limit(1),
          );
          if (q2 != null && q2.docs.isNotEmpty) {
            candidates.add(q2.docs.first.data());
          }
        }
      }

      // 2. Direct document ID lookup (e.g. EMP-0001, doc id)
      if (candidates.isEmpty) {
        final docSnap = await _getDocFast(
          _firestore.collection('employees').doc(cleanEmail.toUpperCase()),
        );
        if (docSnap != null && docSnap.exists && docSnap.data() != null) {
          candidates.add(docSnap.data()!);
        }
      }

      // 3. Email query
      if (candidates.isEmpty && cleanEmail.contains('@')) {
        final emailSnap = await _getQueryFast(
          _firestore
              .collection('employees')
              .where('email_address', isEqualTo: cleanEmail)
              .limit(1),
        );
        if (emailSnap != null && emailSnap.docs.isNotEmpty) {
          candidates.add(emailSnap.docs.first.data());
        }
      }

      // 4. Employee ID query
      if (candidates.isEmpty) {
        final empIdSnap = await _getQueryFast(
          _firestore
              .collection('employees')
              .where('employee_id', isEqualTo: cleanEmail.toUpperCase())
              .limit(1),
        );
        if (empIdSnap != null && empIdSnap.docs.isNotEmpty) {
          candidates.add(empIdSnap.docs.first.data());
        }
      }

      // 5. Fallback scan with safe timeout if not found via targeted indexes
      if (candidates.isEmpty) {
        final allSnap = await _getQueryFast(
          _firestore.collection('employees'),
        );
        if (allSnap != null) {
          for (final doc in allSnap.docs) {
            final data = doc.data();
            final dbEmail =
                (data['email_address'] as String?)?.trim().toLowerCase() ?? '';
            final dbEmpId =
                (data['employee_id'] as String?)?.trim().toLowerCase() ?? '';
            final docId = doc.id.trim().toLowerCase();
            final dbUserName =
                (data['user_name'] as String?)?.trim().toLowerCase() ?? '';
            final dbFirstName =
                (data['first_name'] as String?)?.trim().toLowerCase() ?? '';
            final isSuperMatch = isAdminAlias &&
                (dbEmpId == 'emp-001' ||
                    (data['user_type'] as String?)?.trim().toUpperCase() ==
                        'SUPER ADMIN');

            if (dbEmail == cleanEmail ||
                dbEmpId == cleanEmail ||
                docId == cleanEmail ||
                dbUserName == cleanEmail ||
                dbFirstName == cleanEmail ||
                isSuperMatch) {
              candidates.add(data);
              break;
            }
          }
        }
      }

      // Verify credentials against matched employee records
      for (final data in candidates) {
        final savedPassword =
            (data['temporary_password'] as String?)?.trim() ?? '';
        final userType =
            (data['user_type'] as String?)?.trim().toUpperCase() ?? '';

        if (savedPassword.isNotEmpty && savedPassword == cleanOtp) {
          return true;
        }

        if (userType == 'SUPER ADMIN' || userType == 'SUPER_ADMIN') {
          if (cleanOtp == 'admin123' || cleanOtp == 'Admin@123') {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  @override
  Future<bool> signInWithGoogle() async {
    return true;
  }

  @override
  Future<void> signOut() async {}
}
