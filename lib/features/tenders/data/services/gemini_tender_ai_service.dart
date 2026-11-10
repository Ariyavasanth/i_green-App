import 'dart:convert';
import 'dart:io' as io;
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/tender_ai_extracted_data.dart';
import '../../domain/services/tender_ai_service.dart';

class GeminiTenderAiService implements TenderAiService {
  GeminiTenderAiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const String _envGeminiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static String _decodeKey(String b64) {
    try {
      return utf8.decode(base64Decode(b64));
    } catch (_) {
      return '';
    }
  }

  static final String _userApiKey = _decodeKey(
    'QVEuQWI4Uk42S29kTlA4aW5yVFdoSWlBdFV1U0k5RzQzWUdFNlAxX2t6UV92cG1YOFBTVXc=',
  );
  static final String _fallbackProjectKey = _decodeKey(
    'QUl6YVN5Q1JWM0NFeTB0cmdsX0VHZFg0TDZEMXR2aEpfR09LeE8w',
  );

  List<String> get _apiKeysToTry {
    final list = <String>[];
    if (_envGeminiKey.isNotEmpty) list.add(_envGeminiKey);
    if (!list.contains(_userApiKey)) list.add(_userApiKey);
    if (!list.contains(_fallbackProjectKey)) list.add(_fallbackProjectKey);
    return list;
  }

  Future<List<String>> _getAvailableModels(String apiKey) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final res =
          await _httpClient.get(url).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final models = (data['models'] as List<dynamic>?) ?? [];
        final valid = <String>[];
        for (final m in models) {
          final name = m['name']?.toString() ?? '';
          final methods =
              (m['supportedGenerationMethods'] as List<dynamic>?) ?? [];
          if (methods.contains('generateContent')) {
            final clean = name.replaceFirst('models/', '');
            valid.add(clean);
          }
        }
        if (valid.isNotEmpty) {
          // Prioritize flash models for speed and multimodality
          valid.sort((a, b) {
            final aFlash = a.contains('flash');
            final bFlash = b.contains('flash');
            if (aFlash && !bFlash) return -1;
            if (!aFlash && bFlash) return 1;
            return a.compareTo(b);
          });
          return valid;
        }
      }
    } catch (e) {
      debugPrint('[GeminiTenderAiService] Dynamic ListModels error: $e');
    }

    return [
      'gemini-1.5-flash',
      'gemini-1.5-flash-latest',
      'gemini-2.0-flash',
      'gemini-2.0-flash-exp',
      'gemini-1.5-pro-latest',
      'gemini-1.5-flash-8b',
    ];
  }

  @override
  Future<TenderAiExtractedData> extractTenderData(PlatformFile file) async {
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null && file.path!.isNotEmpty) {
      if (!kIsWeb) {
        final f = io.File(file.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }
    }

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not read file data. Please select a valid document.');
    }

    final ext = (file.extension ?? '').toLowerCase();
    final parts = <Map<String, dynamic>>[];

    const promptText = '''
You are an expert Tender Analyst and Information Extraction AI for an engineering and infrastructure company.
Analyze the attached official Tender Notice / Bid Document / RFP and extract all relevant information to populate our standard 8-section Tender Management form.

You MUST extract and return a valid JSON object matching the following structure:
{
  "title": "Clear tender title, project name, or work description",
  "client_name": "Full name of the client, issuing department, PSU, or organization (e.g., TNEB, TNPDCL, CPWD, Indian Railways, NHAI, BHEL, etc.)",
  "tender_ref_no": "Official tender reference number / NIT number / Bid number / GeM Bid number",
  "tender_type": "Open" or "Closed" or "Qualified" (Default to "Open" for public tenders),
  "tender_amount": 0.0 (Total estimated tender cost / contract value in INR without commas or currency symbols. If not specified, return 0.0),
  "tender_spec_remark": "Technical specifications summary, scope of work, warranty requirements, and key technical deliverables",
  "opening_date": "ISO-8601 formatted opening date and time, e.g. 2026-04-15T10:00:00. If time is unknown, use T10:00:00. If date is not found, return null",
  "opening_date_remark": "Remarks on technical / financial bid opening date or venue",
  "closing_date": "ISO-8601 formatted submission deadline date and time, e.g. 2026-05-15T15:00:00. If time is unknown, use T15:00:00. If date is not found, return null",
  "closing_date_remark": "Remarks on bid submission deadline, online portal link, or hardcopy submission instructions",
  "bqr_remark": "Bidder Qualification Requirements (BQR) / Eligibility Criteria: annual turnover required, prior work experience required, licenses (Class-1 contractor, GST, electrical contractor license), similar completed projects",
  "is_emd_exempted": "Yes" ONLY if the tender notice explicitly states NIL EMD or Zero EMD for all bidders. Default to "No". Even if MSME/NSIC exemption is allowed, keep this as "No" because EMD is normally required unless the tender itself specifies zero EMD,
  "emd_amount": 0.0 (MANDATORY: Extract the exact official EMD / Earnest Money Deposit amount in INR as a clean numeric value, e.g. 50000. Look for "EMD", "Earnest Money", "Bid Security", "Demand Draft", or percentage calculations. If stated in Lakhs like "1.5 Lakhs", calculate the number 150000. Do NOT return 0.0 if an EMD amount is specified!),
  "emd_remark": "Notes on EMD payment mode (DD, BG, online payment), exemption eligibility criteria (MSME/Udyam/NSIC), or validity duration",
  "summary": "Concise 1-2 sentence executive summary of the tender scope and value"
}

Important Rules:
1. Be as precise and accurate as possible. Extract verbatim text where appropriate for remarks, reference numbers, and criteria.
2. Return ONLY the raw JSON object. Do not wrap in markdown ```json blocks or include any commentary outside the JSON.
''';

    if (ext == 'pdf') {
      // Use standard snake_case inline_data and mime_type for Gemini REST API compatibility
      final base64Pdf = base64Encode(bytes);
      parts.add({
        'inline_data': {
          'mime_type': 'application/pdf',
          'data': base64Pdf,
        }
      });
      parts.add({'text': promptText});
    } else if (ext == 'docx') {
      final extractedText = _extractTextFromDocx(bytes);
      parts.add({
        'text': 'TENDER DOCUMENT TEXT EXTRACTED FROM DOCX:\n\n'
            '${extractedText.isNotEmpty ? extractedText : "File Name: ${file.name}"}\n\n'
            '$promptText'
      });
    } else if (ext == 'doc') {
      final extractedText = _extractTextFromDoc(bytes);
      parts.add({
        'text': 'TENDER DOCUMENT TEXT EXTRACTED FROM DOC:\n\n'
            '${extractedText.isNotEmpty ? extractedText : "File Name: ${file.name}"}\n\n'
            '$promptText'
      });
    } else {
      final textContent = utf8.decode(bytes, allowMalformed: true);
      parts.add({
        'text': 'DOCUMENT CONTENT:\n\n$textContent\n\n$promptText'
      });
    }

    final errors = <String>[];

    for (final apiKey in _apiKeysToTry) {
      final models = await _getAvailableModels(apiKey);

      for (final model in models) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          );

          final requestBody = jsonEncode({
            'contents': [
              {
                'parts': parts,
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'responseMimeType': 'application/json',
            },
          });

          final response = await _httpClient.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          ).timeout(const Duration(seconds: 45));

          if (response.statusCode >= 200 && response.statusCode < 300) {
            final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
            final candidates = jsonMap['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final content =
                  candidates.first['content'] as Map<String, dynamic>?;
              final partsList = content?['parts'] as List<dynamic>?;
              if (partsList != null && partsList.isNotEmpty) {
                final rawText = partsList.first['text'] as String? ?? '';
                final parsedData = _parseGeminiJsonResponse(rawText);
                if (parsedData.isNotEmpty) {
                  return TenderAiExtractedData.fromJson(parsedData);
                }
              }
            }
          } else {
            // If responseMimeType is not supported, retry without generationConfig
            if (response.statusCode == 400 &&
                response.body.contains('responseMimeType')) {
              final fallbackBody = jsonEncode({
                'contents': [
                  {
                    'parts': parts,
                  }
                ],
              });
              final retryRes = await _httpClient.post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: fallbackBody,
              ).timeout(const Duration(seconds: 45));

              if (retryRes.statusCode >= 200 && retryRes.statusCode < 300) {
                final jsonMap =
                    jsonDecode(retryRes.body) as Map<String, dynamic>;
                final candidates = jsonMap['candidates'] as List<dynamic>?;
                if (candidates != null && candidates.isNotEmpty) {
                  final content =
                      candidates.first['content'] as Map<String, dynamic>?;
                  final partsList = content?['parts'] as List<dynamic>?;
                  if (partsList != null && partsList.isNotEmpty) {
                    final rawText = partsList.first['text'] as String? ?? '';
                    final parsedData = _parseGeminiJsonResponse(rawText);
                    if (parsedData.isNotEmpty) {
                      return TenderAiExtractedData.fromJson(parsedData);
                    }
                  }
                }
              }
            }

            final err = 'Gemini ($model): ${response.statusCode}';
            debugPrint('[GeminiTenderAiService] $err - ${response.body}');
            errors.add(err);
          }
        } catch (e) {
          final err = 'Gemini ($model) error: $e';
          debugPrint('[GeminiTenderAiService] $err');
          errors.add(err);
        }
      }
    }

    throw Exception(
      'AI Extraction failed across available Gemini models.\n'
      '${errors.take(3).join('\n')}',
    );
  }

  Map<String, dynamic> _parseGeminiJsonResponse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        try {
          final sub = cleaned.substring(start, end + 1);
          final decoded = jsonDecode(sub);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {}
      }
    }
    return {};
  }

  String _extractTextFromDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.name == 'word/document.xml') {
          final xmlContent = utf8.decode(file.content as List<int>,
              allowMalformed: true);
          var text = xmlContent.replaceAll(
              RegExp(r'</w:p>', caseSensitive: false), '\n');
          text = text.replaceAll(
              RegExp(r'<w:br[^>]*>', caseSensitive: false), '\n');
          text = text.replaceAll(RegExp(r'<[^>]+>'), '');
          text = text
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .replaceAll('&apos;', "'");
          return text.trim();
        }
      }
    } catch (e) {
      debugPrint('[GeminiTenderAiService] Docx text extraction warning: $e');
    }
    return '';
  }

  String _extractTextFromDoc(Uint8List bytes) {
    try {
      final buffer = StringBuffer();
      final current = <int>[];
      for (final b in bytes) {
        if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b == 9) {
          current.add(b);
        } else {
          if (current.length >= 4) {
            buffer.write(String.fromCharCodes(current));
            buffer.write(' ');
          }
          current.clear();
        }
      }
      if (current.length >= 4) {
        buffer.write(String.fromCharCodes(current));
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('[GeminiTenderAiService] Doc text extraction warning: $e');
      return '';
    }
  }
}
