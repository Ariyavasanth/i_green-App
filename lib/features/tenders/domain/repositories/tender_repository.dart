import 'package:file_picker/file_picker.dart';
import '../models/tender.dart';

abstract class TenderRepository {
  Future<String> createTender(
    Tender tender, {
    Map<String, List<PlatformFile>>? filesByCategory,
  });

  Future<void> updateTender(
    Tender tender, {
    Map<String, List<PlatformFile>>? filesByCategory,
  });

  Future<void> deleteTender(String id);

  Stream<List<Tender>> watchTenders();

  Future<List<Tender>> getTenders();

  Future<Tender?> getTenderById(String id);

  Future<String> generateNextTenderId();
}
