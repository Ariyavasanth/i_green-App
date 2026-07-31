import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firebase_face_registration_repository.dart';
import '../domain/face_registration_repository.dart';

/// Primary Face Registration Repository Provider (configured to Firebase Firestore per user requirement)
final faceRegistrationRepositoryProvider = Provider<FaceRegistrationRepository>((ref) {
  // To switch to SQLite local storage, simply replace with:
  // return SqliteFaceRegistrationRepository();
  return FirebaseFaceRegistrationRepository();
});

final isFaceRegisteredProvider = FutureProvider.family<bool, int>((ref, employeeId) async {
  final repo = ref.watch(faceRegistrationRepositoryProvider);
  return await repo.isFaceRegistered(employeeId);
});

final faceMismatchAttemptsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(faceRegistrationRepositoryProvider);
  return await repo.getMismatchAttempts();
});
