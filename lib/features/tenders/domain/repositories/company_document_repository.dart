import 'package:file_picker/file_picker.dart';
import '../models/company_document_item.dart';

abstract class CompanyDocumentRepository {
  Stream<List<CompanyDocumentItem>> watchDocuments();

  Future<List<CompanyDocumentItem>> getDocuments();

  Future<CompanyDocumentItem> addDocument({
    required CompanyDocType docType,
    required String title,
    required PlatformFile file,
    String? financialYear,
    String? monthYear,
    String? projectCode,
    DateTime? startDate,
    DateTime? expiryDate,
    int alertBeforeDays = 30,
  });

  Future<CompanyDocumentItem> updateDocument({
    required CompanyDocumentItem existing,
    required CompanyDocType docType,
    required String title,
    PlatformFile? newFile,
    String? financialYear,
    String? monthYear,
    String? projectCode,
    DateTime? startDate,
    DateTime? expiryDate,
    int alertBeforeDays = 30,
  });

  Future<void> deleteDocument(String id);
}
