import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../domain/employee.dart';
import 'offer_letter_save_stub.dart'
    if (dart.library.html) 'offer_letter_save_web.dart'
    if (dart.library.io) 'offer_letter_save_io.dart';

class OfferLetterGenerator {
  /// Generates a Microsoft Word (.docx) file byte array containing the full
  /// employment offer letter, employee details, salary structure, and company terms & conditions.
  static List<int> generateDocxBytes(Employee employee) {
    final nowStr = DateFormat('dd MMMM yyyy').format(DateTime.now());
    final empName = employee.fullName.isNotEmpty ? employee.fullName : 'Valued Employee';
    final orgName = employee.organizationName.isNotEmpty ? employee.organizationName : 'iGreen Tech';
    final designation = employee.designation.isNotEmpty ? employee.designation : 'Software Engineer';
    final department = employee.department.isNotEmpty ? employee.department : 'Engineering';
    final joiningDate = employee.joiningDate.isNotEmpty ? employee.joiningDate : nowStr;
    final email = employee.emailAddress.isNotEmpty ? employee.emailAddress : 'N/A';
    final phone = employee.phoneNumber.isNotEmpty ? employee.phoneNumber : 'N/A';

    final salaryType = employee.salaryType.isNotEmpty ? employee.salaryType : 'Monthly';
    final totalSalary = employee.salaryTotalCtc > 0 ? employee.salaryTotalCtc : 85000.0;
    final basicPay = employee.salaryBasic > 0 ? employee.salaryBasic : (totalSalary * 0.50);
    final hra = employee.salaryHra > 0 ? employee.salaryHra : (totalSalary * 0.25);
    final eduAllowance = employee.salaryEducationAllowance > 0 ? employee.salaryEducationAllowance : (totalSalary * 0.25);
    final specialAllowance = employee.salarySpecialAllowance;
    final tax = employee.salaryTax;
    final pf = employee.salaryPf;

    final docXmlContent = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <!-- Header Title -->
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="200"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="36"/><w:color w:val="414A51"/></w:rPr>
        <w:t>${_xmlEscape(orgName.toUpperCase())}</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="400"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="9CC70A"/></w:rPr>
        <w:t>EMPLOYMENT OFFER LETTER &amp; TERMS OF SERVICE</w:t>
      </w:r>
    </w:p>

    <!-- Date & Ref -->
    <w:p>
      <w:pPr><w:spacing w:after="120"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/></w:rPr>
        <w:t>Date: </w:t>
      </w:r>
      <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>${_xmlEscape(nowStr)}</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:spacing w:after="240"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/></w:rPr>
        <w:t>Ref No: </w:t>
      </w:r>
      <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>OFFER/${DateTime.now().year}/${employee.id != 0 ? employee.id : 1001}</w:t></w:r>
    </w:p>

    <!-- Candidate Info -->
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>To,</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>${_xmlEscape(empName)}</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>Email: ${_xmlEscape(email)}</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="240"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>Phone: ${_xmlEscape(phone)}</w:t></w:r></w:p>

    <!-- Greeting & Offer Body -->
    <w:p>
      <w:pPr><w:spacing w:after="200"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>Dear ${_xmlEscape(empName)},</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:spacing w:after="200"/></w:pPr>
      <w:r>
        <w:rPr><w:sz w:val="22"/></w:rPr>
        <w:t>We are pleased to offer you employment at ${_xmlEscape(orgName)} for the position of </w:t>
      </w:r>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>${_xmlEscape(designation)}</w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t> in the </w:t></w:r>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>${_xmlEscape(department)}</w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t> department. Your scheduled Date of Joining is </w:t></w:r>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>${_xmlEscape(joiningDate)}</w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>.</w:t></w:r>
    </w:p>

    <!-- Compensation Section Header -->
    <w:p>
      <w:pPr><w:spacing w:before="200" w:after="120"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="414A51"/></w:rPr><w:t>COMPENSATION &amp; SALARY STRUCTURE</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:spacing w:after="200"/></w:pPr>
      <w:r>
        <w:rPr><w:sz w:val="22"/></w:rPr>
        <w:t>Your total gross salary will be </w:t>
      </w:r>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>₹${totalSalary.toStringAsFixed(2)}</w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t> (${_xmlEscape(salaryType)}). The detailed breakdown of your compensation structure is outlined below:</w:t></w:r>
    </w:p>

    <!-- Salary Breakdown Table -->
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="5000" w:type="pct"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        </w:tblBorders>
      </w:tblPr>
      
      <!-- Table Header -->
      <w:tr>
        <w:tc><w:p><w:pPr><w:jc w:val="left"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="414A51"/></w:rPr><w:t>Salary Component</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="414A51"/></w:rPr><w:t>Amount (₹)</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:pPr><w:jc w:val="left"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="414A51"/></w:rPr><w:t>Calculation Basis</w:t></w:r></w:p></w:tc>
      </w:tr>

      <!-- Row: Basic Pay -->
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>Basic Pay</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>${basicPay.toStringAsFixed(2)}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>50% of Total Salary</w:t></w:r></w:p></w:tc>
      </w:tr>

      <!-- Row: HRA -->
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>House Rent Allowance (HRA)</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>${hra.toStringAsFixed(2)}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>25% of Total Salary</w:t></w:r></w:p></w:tc>
      </w:tr>

      <!-- Row: Education Allowance -->
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>Education Allowance</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>${eduAllowance.toStringAsFixed(2)}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>25% of Total Salary</w:t></w:r></w:p></w:tc>
      </w:tr>

      <!-- Row: Special Allowance -->
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>Special Allowance</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>${specialAllowance.toStringAsFixed(2)}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>As Applicable</w:t></w:r></w:p></w:tc>
      </w:tr>

      <!-- Row: Tax -->
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>Tax Deduction</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>${tax.toStringAsFixed(2)}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>Statutory Deduction</w:t></w:r></w:p></w:tc>
      </w:tr>

      <!-- Row: PF -->
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>Provident Fund (PF)</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>${pf.toStringAsFixed(2)}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>Statutory Contribution</w:t></w:r></w:p></w:tc>
      </w:tr>

      <!-- Total Row -->
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>Total Gross CTC (${_xmlEscape(salaryType)})</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="414A51"/></w:rPr><w:t>₹${totalSalary.toStringAsFixed(2)}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>Total Compensation</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>

    <!-- Company Terms & Conditions Section -->
    <w:p>
      <w:pPr><w:spacing w:before="360" w:after="160"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="414A51"/></w:rPr><w:t>COMPANY TERMS AND CONDITIONS</w:t></w:r>
    </w:p>

    <!-- Term 1 -->
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>1. Probation &amp; Confirmation</w:t></w:r></w:p>
    <w:p>
      <w:pPr><w:spacing w:after="160"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>You will be on probation for a period of six (6) months from your joining date. Upon satisfactory performance, your employment will be confirmed in writing. The company reserves the right to extend the probation period if performance requirements are not met.</w:t></w:r>
    </w:p>

    <!-- Term 2 -->
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>2. Duties &amp; Code of Conduct</w:t></w:r></w:p>
    <w:p>
      <w:pPr><w:spacing w:after="160"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>You agree to perform all duties assigned to you efficiently and faithfully to the best of your ability. You shall strictly follow all organizational rules, workplace safety standards, ethics policies, and lawful directions issued by management.</w:t></w:r>
    </w:p>

    <!-- Term 3 -->
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>3. Confidentiality &amp; Non-Disclosure (NDA)</w:t></w:r></w:p>
    <w:p>
      <w:pPr><w:spacing w:after="160"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>You shall hold in strict confidence all technical, business, financial, client, and proprietary information belonging to ${_xmlEscape(orgName)}. You shall not disclose, publish, or share any confidential material to any third party during or after your tenure of employment.</w:t></w:r>
    </w:p>

    <!-- Term 4 -->
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>4. Intellectual Property Rights</w:t></w:r></w:p>
    <w:p>
      <w:pPr><w:spacing w:after="160"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>All software code, documentation, designs, intellectual property, and creative works produced by you during your employment shall remain the sole and exclusive property of ${_xmlEscape(orgName)}.</w:t></w:r>
    </w:p>

    <!-- Term 5 -->
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>5. Working Hours &amp; Leaves</w:t></w:r></w:p>
    <w:p>
      <w:pPr><w:spacing w:after="160"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>Standard business hours are Monday through Friday, 9:00 AM to 6:00 PM. Leave entitlements will be governed by the company's official Leave Policy.</w:t></w:r>
    </w:p>

    <!-- Term 6 -->
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>6. Notice Period &amp; Termination</w:t></w:r></w:p>
    <w:p>
      <w:pPr><w:spacing w:after="240"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>During probation, either party may terminate employment by giving 15 days' written notice. Following confirmation, either party may terminate employment by giving 60 days' written notice or equivalent base salary in lieu thereof.</w:t></w:r>
    </w:p>

    <!-- Signatures -->
    <w:p><w:pPr><w:spacing w:before="400" w:after="300"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>Sincerely,</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="414A51"/></w:rPr><w:t>For ${_xmlEscape(orgName)}</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="400"/></w:pPr><w:r><w:rPr><w:i/><w:sz w:val="20"/></w:rPr><w:t>Authorized Signatory (HR &amp; Management)</w:t></w:r></w:p>

    <w:p><w:pPr><w:spacing w:before="300" w:after="100"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>ACCEPTANCE OF OFFER</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>I, ${_xmlEscape(empName)}, accept the employment offer and agree to abide by all the terms and conditions outlined above.</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>Candidate Signature: _______________________      Date: _______________</w:t></w:r></w:p>
  </w:body>
</w:document>''';

    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));
    archive.addFile(ArchiveFile('word/document.xml', docXmlContent.length, utf8.encode(docXmlContent)));

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

  /// Triggers immediate download of the offer letter .docx file in browser or device.
  static Future<void> downloadOfferLetter(BuildContext context, Employee employee) async {
    try {
      final docxBytes = generateDocxBytes(employee);
      final rawName = employee.fullName.trim().replaceAll(RegExp(r'[^\w\s\-]'), '');
      final fileName = 'Offer_Letter_${rawName.isEmpty ? "Employee" : rawName.replaceAll(" ", "_")}.docx';

      await saveAndDownloadOfferLetter(
        context: context,
        bytes: docxBytes,
        fileName: fileName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate offer letter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
