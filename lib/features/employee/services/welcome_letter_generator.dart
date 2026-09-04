import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/employee.dart';
import 'offer_letter_save_stub.dart'
    if (dart.library.html) 'offer_letter_save_web.dart'
    if (dart.library.io) 'offer_letter_save_io.dart';

class WelcomeLetterData {
  final String organizationName;
  final String employeeName;
  final String reportingManagerName;
  final String reportingManagerTitle;
  final String adminName;
  final String coordinatorName;
  final String coordinatorPhone;
  final String officeStartTime;
  final String officeEndTime;
  final String weeklyOffDay;

  const WelcomeLetterData({
    this.organizationName = 'IGreen Technologies',
    required this.employeeName,
    required this.reportingManagerName,
    required this.reportingManagerTitle,
    required this.adminName,
    required this.coordinatorName,
    required this.coordinatorPhone,
    required this.officeStartTime,
    required this.officeEndTime,
    required this.weeklyOffDay,
  });

  factory WelcomeLetterData.fromEmployee(Employee emp) {
    return WelcomeLetterData(
      organizationName: emp.organizationName.trim().isNotEmpty
          ? emp.organizationName.trim()
          : 'IGreen Technologies',
      employeeName: emp.fullName.trim().isNotEmpty
          ? emp.fullName.trim()
          : 'Employee',
      reportingManagerName:
          emp.reportingManager.trim().isNotEmpty &&
              emp.reportingManager.trim() != 'None'
          ? emp.reportingManager.trim()
          : '',
      reportingManagerTitle: emp.reportingManagerTitle.trim().isNotEmpty
          ? emp.reportingManagerTitle.trim()
          : 'Reporting Manager',
      adminName: emp.adminName.trim().isNotEmpty
          ? emp.adminName.trim()
          : '',
      coordinatorName: emp.coordinatorName.trim().isNotEmpty
          ? emp.coordinatorName.trim()
          : '',
      coordinatorPhone: emp.coordinatorPhone.trim().isNotEmpty
          ? emp.coordinatorPhone.trim()
          : '',
      officeStartTime: emp.inTime.trim(),
      officeEndTime: emp.outTime.trim(),
      weeklyOffDay: emp.weeklyOffDay.trim(),
    );
  }
}

class WelcomeLetterGenerator {
  static String generateLetterText(WelcomeLetterData data) {
    final offDayText = data.weeklyOffDay.trim().isNotEmpty
        ? ' (${data.weeklyOffDay.trim()} Holiday)'
        : '';
    return '''Dear ${data.employeeName},

Welcome to ${data.organizationName}! We are excited to have you on board and look forward to working with you.

We would like to give you a brief overview of your key responsibilities.

You will be reporting directly to ${data.reportingManagerName}, ${data.reportingManagerTitle}, who will guide you through your initial onboarding and assist you with any concerns regarding your responsibilities.

For knowledge transfer — including employee contact details and role-related information — please reach out to ${data.adminName} (present Admin). You may also coordinate with ${data.coordinatorName} (${data.coordinatorPhone}) for any queries.

Office Timings: ${data.officeStartTime} to ${data.officeEndTime}$offDayText

Once again, welcome aboard!

Sincerely,
${data.organizationName} Team''';
  }

  static List<int> generateDocxBytes(WelcomeLetterData data) {
    final dateStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final orgName = _xmlEscape(
      data.organizationName.trim().isNotEmpty
          ? data.organizationName.trim()
          : 'IGreen Technologies',
    );
    final employeeName = _xmlEscape(data.employeeName);
    final managerName = _xmlEscape(data.reportingManagerName);
    final managerTitle = _xmlEscape(data.reportingManagerTitle);
    final adminName = _xmlEscape(data.adminName);
    final coordName = _xmlEscape(data.coordinatorName);
    final coordPhone = _xmlEscape(data.coordinatorPhone);
    final startTime = _xmlEscape(data.officeStartTime);
    final endTime = _xmlEscape(data.officeEndTime);
    final weeklyOff = _xmlEscape(data.weeklyOffDay);

    final offDayText = weeklyOff.trim().isNotEmpty
        ? ' ($weeklyOff Holiday)'
        : '';

    final docXmlContent =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="32"/><w:color w:val="1F2937"/></w:rPr><w:t>${orgName.toUpperCase()}</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="240"/></w:pPr>
      <w:r><w:rPr><w:i/><w:sz w:val="20"/><w:color w:val="6B7280"/></w:rPr><w:t>Official Welcome Letter</w:t></w:r>
    </w:p>
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>Date: $dateStr</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="24"/></w:rPr><w:t>Dear $employeeName,</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>Welcome to $orgName! We are excited to have you on board and look forward to working with you.</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>We would like to give you a brief overview of your key responsibilities.</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>You will be reporting directly to $managerName, $managerTitle, who will guide you through your initial onboarding and assist you with any concerns regarding your responsibilities.</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>For knowledge transfer — including employee contact details and role-related information — please reach out to $adminName (present Admin). You may also coordinate with $coordName ($coordPhone) for any queries.</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>Office Timings: $startTime to $endTime$offDayText</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="400"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>Once again, welcome aboard!</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="100"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>Sincerely,</w:t></w:r></w:p>
    <w:p><w:r><w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="1F2937"/></w:rPr><w:t>$orgName Team</w:t></w:r></w:p>
  </w:body>
</w:document>''';

    const contentTypesXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final archive = Archive();
    archive.addFile(
      ArchiveFile(
        '[Content_Types].xml',
        contentTypesXml.length,
        utf8.encode(contentTypesXml),
      ),
    );
    archive.addFile(
      ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)),
    );
    archive.addFile(
      ArchiveFile(
        'word/document.xml',
        docXmlContent.length,
        utf8.encode(docXmlContent),
      ),
    );

    return ZipEncoder().encode(archive) ?? [];
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static Future<void> downloadWelcomeLetter(
    BuildContext context,
    WelcomeLetterData data,
  ) async {
    try {
      final docxBytes = generateDocxBytes(data);
      final rawName = data.employeeName.trim().replaceAll(
        RegExp(r'[^\w\s\-]'),
        '',
      );
      final fileName =
          'Welcome_Letter_${rawName.isEmpty ? "Employee" : rawName.replaceAll(" ", "_")}.docx';

      await saveAndDownloadOfferLetter(
        context: context,
        bytes: docxBytes,
        fileName: fileName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export welcome letter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
