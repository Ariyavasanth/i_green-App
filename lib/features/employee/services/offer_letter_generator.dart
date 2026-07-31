import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../domain/employee.dart';
import 'offer_letter_save_stub.dart'
    if (dart.library.html) 'offer_letter_save_web.dart'
    if (dart.library.io) 'offer_letter_save_io.dart';

class OfferLetterGenerator {
  /// Converts a double amount into Indian English Words (e.g. Rupees Six Lakhs Only).
  static String numberToWords(double amount) {
    final int val = amount.round();
    if (val <= 0) return 'Rupees Zero Only';

    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convertChunk(int n) {
      if (n < 20) return units[n];
      if (n < 100) {
        final t = tens[n ~/ 10];
        final u = units[n % 10];
        return u.isEmpty ? t : '$t $u';
      }
      final h = units[n ~/ 100];
      final rem = n % 100;
      if (rem == 0) return '$h Hundred';
      return '$h Hundred ${convertChunk(rem)}';
    }

    int num = val;
    final parts = <String>[];

    final crores = num ~/ 10000000;
    num %= 10000000;

    final lakhs = num ~/ 100000;
    num %= 100000;

    final thousands = num ~/ 1000;
    num %= 1000;

    final remaining = num;

    if (crores > 0) {
      parts.add('${convertChunk(crores)} Crore${crores > 1 ? 's' : ''}');
    }
    if (lakhs > 0) {
      parts.add('${convertChunk(lakhs)} Lakh${lakhs > 1 ? 's' : ''}');
    }
    if (thousands > 0) {
      parts.add('${convertChunk(thousands)} Thousand');
    }
    if (remaining > 0) {
      parts.add(convertChunk(remaining));
    }

    return 'Rupees ${parts.join(' ')} Only';
  }

  /// Generates a Microsoft Word (.docx) file byte array containing the exact offer letter template
  /// filled with user/candidate details from the Employee Add form.
  static List<int> generateDocxBytes(Employee employee) {
    final todayStr = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final empName = employee.fullName.trim().isNotEmpty
        ? employee.fullName.trim()
        : 'XXXXX';
    
    String salutation = 'Mr.';
    final lowerGender = employee.gender.toLowerCase().trim();
    if (lowerGender == 'female' || lowerGender == 'f') {
      salutation = 'Ms.';
    }
    final hasTitlePrefix = empName.startsWith(RegExp(r'^(Mr\.|Ms\.|Mrs\.|Dr\.)', caseSensitive: false));
    final salutationName = hasTitlePrefix ? empName : '$salutation $empName';

    final designation = employee.designation.trim().isNotEmpty
        ? employee.designation.trim()
        : 'Designation';
    final joiningDate = employee.joiningDate.trim().isNotEmpty
        ? employee.joiningDate.trim()
        : todayStr;

    final totalSalary = employee.salaryTotalCtc > 0 ? employee.salaryTotalCtc : 0.0;
    final formattedSalary = totalSalary > 0
        ? NumberFormat('#,##,##0', 'en_IN').format(totalSalary)
        : '---';
    final salaryInWords = totalSalary > 0
        ? numberToWords(totalSalary)
        : 'Amount in words';

    final docXmlContent = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <!-- PAGE 1: OFFER LETTER TERMS HEADER & DETAILS -->
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:before="240" w:after="300"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:u w:val="single"/><w:sz w:val="28"/><w:szCs w:val="28"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>OFFER LETTER TERMS</w:t>
      </w:r>
    </w:p>

    <!-- Salutation -->
    <w:p>
      <w:pPr><w:spacing w:after="200"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>Dear ${_xmlEscape(salutationName)},</w:t>
      </w:r>
    </w:p>

    <!-- Ref & Application Paragraph -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve">We refer to your job application and subsequent interviews you had with us regarding the employment. We are pleased to offer you a designation in our organization as “</w:t>
      </w:r>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>${_xmlEscape(designation)}</w:t>
      </w:r>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve">” at our Chennai Office on the terms discussed with you.</w:t>
      </w:r>
    </w:p>

    <!-- CTC Paragraph -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve">As agreed by you, your costs to the company will be Rs. </w:t>
      </w:r>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>${_xmlEscape(formattedSalary)}/-</w:t>
      </w:r>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve">.  [(${_xmlEscape(salaryInWords)} (all inclusive)] per annum.</w:t>
      </w:r>
    </w:p>

    <!-- Joining Date Paragraph -->
    <w:p>
      <w:pPr><w:spacing w:after="200"/><w:jc w:val="both"/></w:pPr>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve">You are requested to join the company on </w:t>
      </w:r>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>${_xmlEscape(joiningDate)}</w:t>
      </w:r>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>.</w:t>
      </w:r>
    </w:p>

    <!-- Documents List Header -->
    <w:p>
      <w:pPr><w:spacing w:after="120"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>Please submit copy of the following documents while joining &amp; original for verification.</w:t>
      </w:r>
    </w:p>

    <!-- Documents List Items a-d -->
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>a)&#x9;All Educational certificates photocopy are required</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>b)&#x9;Copy of Driving license, Passport, Aadhaar Card, PAN Card, Bank Details, Latest Blood Group Report.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>c)&#x9;3 Latest Photographs (Formal Passport Size).</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="200"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>d)&#x9;Last Salary slip.</w:t></w:r>
    </w:p>

    <!-- Terms & Conditions Header -->
    <w:p>
      <w:pPr><w:spacing w:after="120"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>Terms &amp; Conditions:</w:t>
      </w:r>
    </w:p>

    <!-- Terms Items a-j -->
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>a)&#x9;The job will initiate with a probation period of six months.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>b)&#x9;No leave shall be admissible during the probation period.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>c)&#x9;An accidental insurance will be taken by the company on your date of joining.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>d)&#x9;Health insurance will be deducted from your salary.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>e)&#x9;Professional Tax will be deducted from your salary.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>f)&#x9;Your leave should be approved and informed in prior notification to superiors.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>g)&#x9;Salary calculation period will be 21st to 20th of every month (e.g. Jan 21st to Feb 20th</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>h)&#x9;Excess leave will be considered as LOP (Loss of Pay).</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>i)&#x9;ESI &amp; PF will be deducted from your salary.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="360"/><w:spacing w:after="200"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>j)&#x9;If Trainee, 10% of training charges will be deducted from your Gross salary which will be returned after completing your probation will be paid in 7th month salary.</w:t></w:r>
    </w:p>

    <!-- Good Faith Clause -->
    <w:p>
      <w:pPr><w:spacing w:after="200"/><w:jc w:val="both"/></w:pPr>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>This offer is made in good faith, based on the information provided by you regarding your own profile, including age, qualifications and past experience. Should any of the information provided by you proved to be incorrect at any stage, whether prior to or after your joining the organization, the offer will stand automatically cancelled without any benefits of the terms of employment or any compensation accruing to you. We also reserve the right to withdraw the offer if anything adverse about you comes to light either through independent verification or through reference checks, including that from your previous employer(s).</w:t>
      </w:r>
    </w:p>

    <!-- Welcome Clause -->
    <w:p>
      <w:pPr><w:spacing w:after="300"/><w:jc w:val="both"/></w:pPr>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve">Considering you a potential employee, we welcome you in the employment of </w:t>
      </w:r>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>M/s. IGreentec Engg. India Pvt. Ltd.</w:t>
      </w:r>
    </w:p>

    <!-- Company Sign-off -->
    <w:p>
      <w:pPr><w:spacing w:before="200" w:after="400"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>For IGreentec Engg. India Pvt. Ltd.</w:t>
      </w:r>
    </w:p>

    <!-- PAGE BREAK -->
    <w:p>
      <w:r>
        <w:br w:type="page"/>
      </w:r>
    </w:p>

    <!-- PAGE 2: APPOINTMENT TERMS -->
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:before="240" w:after="300"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:u w:val="single"/><w:sz w:val="28"/><w:szCs w:val="28"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>OFFER LETTER TERMS</w:t>
      </w:r>
    </w:p>

    <!-- Salutation Part 2 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>Dear ${_xmlEscape(salutationName)},</w:t>
      </w:r>
    </w:p>

    <!-- Appointment Preamble -->
    <w:p>
      <w:pPr><w:spacing w:after="200"/><w:jc w:val="both"/></w:pPr>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve">With reference to our offer letter dated, </w:t>
      </w:r>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>${_xmlEscape(todayStr)}</w:t>
      </w:r>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve"> and your acceptance thereof, we are pleased to confirm your appointment as “</w:t>
      </w:r>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>${_xmlEscape(designation)}</w:t>
      </w:r>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve">” in our organization with effect from </w:t>
      </w:r>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t>${_xmlEscape(joiningDate)}</w:t>
      </w:r>
      <w:r>
        <w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>
        <w:t xml:space="preserve"> on the following terms and conditions:-</w:t>
      </w:r>
    </w:p>

    <!-- Clause 1 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">1)&#x9;PLACE OF WORK:  </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">Your present place of work will be at our </w:t></w:r>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>Chennai Office</w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">. However, during the course of service, you may be posted/ transferred/ deputed anywhere in India or overseas to serve any of the Group Company’s project / work, at the sole discretion of the Management.</w:t></w:r>
    </w:p>

    <!-- Clause 2 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">2)&#x9;RESPONSIBILITY:  </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">In performance of the duties, you will be reporting to the superior and will perform the duties as assigned to you by your superior(s). Reporting relationship may be changed in future as per the business requirement.</w:t></w:r>
    </w:p>

    <!-- Clause 3 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">3)&#x9;PROBATION: </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">You will be placed on probation for a period of six months from the date of joining, after which you will be considered for permanent appointment based on your performance and the recommendations of your superior(s). Your probationary period will be deemed to have been extended until such time as you receive your letter of confirmation.</w:t></w:r>
    </w:p>

    <!-- Clause 4 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">4)&#x9;EMOLUMENTS: </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">You will be paid initial emoluments amounting to </w:t></w:r>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>Rs.${_xmlEscape(formattedSalary)}/- (${_xmlEscape(salaryInWords)})</w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve"> (all inclusive) per annum, on Cost To Company (CTC) basis. This amount may be revised from time to time based on your performance and company policies.</w:t></w:r>
    </w:p>

    <!-- Clause 5 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">5)&#x9;NO SIMULTANEOUS EMPLOYMENT: </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">While employed with the organization, you shall not be permitted to be employed with any other organization or person in any capacity whatsoever. You also forbidden from any form of association, including employment or consultation, with any company that is a direct competitor or is in the same/similar line of business or its subsidiaries or associates, while in the employment of the Company and/or for a period of one year after separation from the company. You will be required to sign an agreement with the company to this effect before joining duties.</w:t></w:r>
    </w:p>

    <!-- Clause 6 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">6)&#x9;AGE OF RETIREMENT:  </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">The age of retirement from the company shall be 60 years subject to the conditions laid down in the clause 7 below.</w:t></w:r>
    </w:p>

    <!-- Clause 7 -->
    <w:p>
      <w:pPr><w:spacing w:after="120"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">7)&#x9;TERMINATION:  </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">Either party shall have the right of terminating the employment by giving the other party one month notice n writing during the trainee / probation period or two months’ notice in writing after confirmation of your employment. No leave shall be admissible during the notice period, and any leave to your credit at the time of separation cannot be adjusted against the requisite notice period. Notwithstanding the above, the company shall have the right of terminating your employment by serving you a notice in writing under the following circumstances.</w:t></w:r>
    </w:p>

    <!-- Clause 7 a & b -->
    <w:p>
      <w:pPr><w:ind w:left="720"/><w:spacing w:after="80"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">a)&#x9;</w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">Forthwith in the event of any misconduct on your part or any breach of terms of your employment with the Company.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="80"/></w:pPr>
      <w:r><w:rPr><w:i/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>or</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:ind w:left="720"/><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">b)&#x9;</w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">At any time by paying salary in lieu of the deficient notice period, without assigning any reason, at the discretion of Management.</w:t></w:r>
    </w:p>

    <!-- Clause 8 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">8)&#x9;DISCIPLINE: </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">You will be governed by the Company’s rules and regulations that may be in force at the time of your appointment and also such rules and regulations as may be in force from time to time.</w:t></w:r>
    </w:p>

    <!-- Clause 9 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">9)&#x9;POSTAL ADDRESS: </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">You will keep the Company informed of your postal address for communication including changes that may occur during the period of your employment with the company.</w:t></w:r>
    </w:p>

    <!-- Clause 10 -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">10)&#x9;EXIT PROCEDURE:  </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">Upon termination/resignation, you are required to return all company property and complete a handover of your responsibilities. Final settlement of dues, including salary and any accrued benefits, will be processed after 45 days as per the company's exit process.</w:t></w:r>
    </w:p>

    <!-- Clause 11 -->
    <w:p>
      <w:pPr><w:spacing w:after="240"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">11)&#x9;</w:t></w:r>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">Your employment shall be governed by the employment policy and other policies of the Company in force for the time being.</w:t></w:r>
    </w:p>

    <!-- Closing Remarks -->
    <w:p>
      <w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">Kindly sign the duplicate copy of this letter as a token of your acceptance of the appointment on the terms and conditions mentioned above.</w:t></w:r>
    </w:p>

    <w:p>
      <w:pPr><w:spacing w:after="360"/><w:jc w:val="both"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t xml:space="preserve">Looking forward to a long and mutually rewarding association.</w:t></w:r>
    </w:p>

    <!-- Signatures -->
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="5000" w:type="pct"/>
        <w:tblBorders>
          <w:top w:val="none"/>
          <w:left w:val="none"/>
          <w:bottom w:val="none"/>
          <w:right w:val="none"/>
          <w:insideH w:val="none"/>
          <w:insideV w:val="none"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tr>
        <w:tc>
          <w:tcPr><w:tcW w:w="2500" w:type="pct"/></w:tcPr>
          <w:p><w:pPr><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>Yours faithfully,</w:t></w:r></w:p>
          <w:p><w:pPr><w:spacing w:after="300"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>For IGreentec Engg. India Pvt. Ltd.</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:tcW w:w="2500" w:type="pct"/></w:tcPr>
          <w:p><w:pPr><w:jc w:val="right"/><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>I Accept</w:t></w:r></w:p>
          <w:p><w:pPr><w:jc w:val="right"/><w:spacing w:after="120"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>____________________</w:t></w:r></w:p>
          <w:p><w:pPr><w:jc w:val="right"/><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr><w:t>Signature &amp; Date</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
    </w:tbl>
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
