import 'package:file_picker/file_picker.dart';
import '../models/tender_ai_extracted_data.dart';

abstract class TenderAiService {
  Future<TenderAiExtractedData> extractTenderData(PlatformFile file);
}

