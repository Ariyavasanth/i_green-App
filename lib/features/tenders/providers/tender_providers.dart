import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/firebase_tender_repository.dart';
import '../data/services/gemini_tender_ai_service.dart';
import '../domain/models/tender.dart';
import '../domain/repositories/tender_repository.dart';
import '../domain/services/tender_ai_service.dart';

final tenderRepositoryProvider = Provider<TenderRepository>((ref) {
  return FirebaseTenderRepository();
});

final tenderAiServiceProvider = Provider<TenderAiService>((ref) {
  return GeminiTenderAiService();
});

final tendersStreamProvider = StreamProvider<List<Tender>>((ref) {
  final repo = ref.watch(tenderRepositoryProvider);
  return repo.watchTenders();
});

final tenderByIdProvider = FutureProvider.family<Tender?, String>((ref, id) {
  final repo = ref.watch(tenderRepositoryProvider);
  return repo.getTenderById(id);
});
