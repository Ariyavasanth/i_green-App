import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';

void main() {
  group('Candidate Documents Centralization Tests', () {
    test('DocumentItem serialization and deserialization in employee documentListJson', () {
      final doc1 = DocumentItem(
        id: '1',
        documentType: 'Aadhaar Card',
        documentNumber: '123456789012',
        fileName: 'aadhaar_front_back.pdf',
        uploadedDate: '2026-10-16',
      );
      final doc2 = DocumentItem(
        id: '2',
        documentType: 'Blood Group Certificate',
        documentNumber: 'B+',
        fileName: 'blood_test_report.pdf',
        uploadedDate: '2026-10-16',
      );
      final doc3 = DocumentItem(
        id: '3',
        documentType: '10th Marksheet',
        documentNumber: 'Govt High School (2018)',
        fileName: '10th_marksheet.pdf',
        uploadedDate: '2026-10-16',
      );

      final list = [doc1, doc2, doc3];
      final jsonStr = jsonEncode(list.map((e) => e.toMap()).toList());

      final emp = Employee(
        id: 1,
        employeeId: 'CAN-100',
        firstName: 'John',
        lastName: 'Doe',
        emailAddress: 'john.doe@example.com',
        phoneNumber: '+919876543210',
        gender: 'Male',
        dob: '1995-05-15',
        organizationName: 'iGreen Tech',
        department: 'Operations',
        designation: 'Field Engineer',
        employmentType: 'Full-Time',
        joiningDate: '2026-11-01',
        status: 'Draft',
        bloodGroup: 'B+',
        bloodGroupReport: 'blood_test_report.pdf',
        documentListJson: jsonStr,
      );

      expect(emp.documentItems.length, 3);
      expect(emp.documentItems[0].documentType, 'Aadhaar Card');
      expect(emp.documentItems[0].documentNumber, '123456789012');
      expect(emp.documentItems[1].documentType, 'Blood Group Certificate');
      expect(emp.documentItems[1].fileName, 'blood_test_report.pdf');
      expect(emp.documentItems[2].documentType, '10th Marksheet');
    });

    test('Blood Group Report resolution from documentListJson for backward compatibility', () {
      final docs = [
        DocumentItem(
          id: '1',
          documentType: 'Blood Group Certificate',
          documentNumber: 'O+',
          fileName: 'lab_blood_group.pdf',
          uploadedDate: '2026-10-16',
        ),
      ];

      final bloodDoc = docs.firstWhere(
        (d) => d.documentType.toLowerCase().contains('blood'),
        orElse: () => const DocumentItem(
          id: '',
          documentType: '',
          documentNumber: '',
          fileName: '',
          uploadedDate: '',
        ),
      );

      expect(bloodDoc.fileName, 'lab_blood_group.pdf');
      expect(bloodDoc.documentNumber, 'O+');
    });

    test('Dynamic document types logic generates types based only on entered details', () {
      List<String> getDynamicTypes({
        required String aadhaar,
        required String bloodGroup,
        required List<EducationItem> educationList,
        required String activeEduDegree,
        required List<ExperienceItem> experienceList,
        required String activeExpCompany,
        required String pan,
        required String drivingLicense,
        required String passport,
        required String bankAccount,
        required String bankName,
        required String pfNumber,
        required String esiNumber,
        required List<DocumentItem> documentList,
      }) {
        final types = <String>{};

        if (aadhaar.trim().isNotEmpty) {
          types.add('Aadhaar Card');
        }
        if (bloodGroup.isNotEmpty && bloodGroup != "Other / Don't Know") {
          types.add('Blood Group Certificate');
        }

        for (final edu in educationList) {
          final deg = edu.degreeName.trim();
          if (deg.isEmpty) continue;
          final lower = deg.toLowerCase();
          if (lower.contains('10th') ||
              lower.contains('sslc') ||
              lower.contains('matric') ||
              lower.contains('class 10') ||
              lower.contains('tenth')) {
            types.add('10th Marksheet');
          } else if (lower.contains('12th') ||
              lower.contains('hsc') ||
              lower.contains('inter') ||
              lower.contains('class 12') ||
              lower.contains('twelfth')) {
            types.add('12th Marksheet');
          } else {
            if (lower.contains('certificate') ||
                lower.contains('marksheet') ||
                lower.contains('degree')) {
              types.add(deg);
            } else {
              types.add('$deg Certificate');
            }
          }
        }

        final activeEdu = activeEduDegree.trim();
        if (activeEdu.isNotEmpty) {
          final lower = activeEdu.toLowerCase();
          if (lower.contains('10th') ||
              lower.contains('sslc') ||
              lower.contains('matric') ||
              lower.contains('class 10') ||
              lower.contains('tenth')) {
            types.add('10th Marksheet');
          } else if (lower.contains('12th') ||
              lower.contains('hsc') ||
              lower.contains('inter') ||
              lower.contains('class 12') ||
              lower.contains('twelfth')) {
            types.add('12th Marksheet');
          } else {
            if (lower.contains('certificate') ||
                lower.contains('marksheet') ||
                lower.contains('degree')) {
              types.add(activeEdu);
            } else {
              types.add('$activeEdu Certificate');
            }
          }
        }

        if (experienceList.isNotEmpty || activeExpCompany.trim().isNotEmpty) {
          types.add('Relieving Letter');
          types.add('Experience Certificate');
        }

        if (pan.trim().isNotEmpty) {
          types.add('PAN Card');
        }
        if (drivingLicense.trim().isNotEmpty) {
          types.add('Driving Licence');
        }
        if (passport.trim().isNotEmpty) {
          types.add('Passport');
        }
        types.add('Passbook Image');
        types.add('Check Leaf Image');
        if (pfNumber.trim().isNotEmpty) {
          types.add('PF / UAN Document');
        }
        if (esiNumber.trim().isNotEmpty) {
          types.add('ESI Document');
        }
        for (final doc in documentList) {
          if (doc.documentType.trim().isNotEmpty) {
            types.add(doc.documentType.trim());
          }
        }
        types.add('Other Supporting Document');
        return types.toList();
      }

      // 1. Initial state: Passbook Image, Check Leaf Image, and Other Supporting Document available
      final emptyTypes = getDynamicTypes(
        aadhaar: '',
        bloodGroup: "Other / Don't Know",
        educationList: [],
        activeEduDegree: '',
        experienceList: [],
        activeExpCompany: '',
        pan: '',
        drivingLicense: '',
        passport: '',
        bankAccount: '',
        bankName: '',
        pfNumber: '',
        esiNumber: '',
        documentList: [],
      );
      expect(emptyTypes.contains('Passbook Image'), true);
      expect(emptyTypes.contains('Check Leaf Image'), true);
      expect(emptyTypes.contains('Other Supporting Document'), true);

      // 2. User enters PAN and Driving License in History
      final withPanAndDl = getDynamicTypes(
        aadhaar: '',
        bloodGroup: "Other / Don't Know",
        educationList: [],
        activeEduDegree: '',
        experienceList: [],
        activeExpCompany: '',
        pan: 'ABCDE1234F',
        drivingLicense: 'TN0120200001234',
        passport: '',
        bankAccount: '',
        bankName: '',
        pfNumber: '',
        esiNumber: '',
        documentList: [],
      );
      expect(withPanAndDl.contains('PAN Card'), true);
      expect(withPanAndDl.contains('Driving Licence'), true);
      expect(withPanAndDl.contains('Passport'), false);
      expect(withPanAndDl.contains('10th Marksheet'), false);

      // 3. User provides 10th standard in Education tab
      final with10th = getDynamicTypes(
        aadhaar: '',
        bloodGroup: "Other / Don't Know",
        educationList: [
          const EducationItem(
            id: '1',
            degreeName: '10th Standard / SSLC',
            instituteName: 'St. Xavier School',
            result: '88%',
            passingYear: '2016',
          ),
        ],
        activeEduDegree: '',
        experienceList: [],
        activeExpCompany: '',
        pan: '',
        drivingLicense: '',
        passport: '',
        bankAccount: '',
        bankName: '',
        pfNumber: '',
        esiNumber: '',
        documentList: [],
      );
      expect(with10th.contains('10th Marksheet'), true);
      expect(with10th.contains('12th Marksheet'), false);

      // 4. User provides Blood Group in Personal Info
      final withBlood = getDynamicTypes(
        aadhaar: '123456789012',
        bloodGroup: 'A1B+',
        educationList: [],
        activeEduDegree: '',
        experienceList: [],
        activeExpCompany: '',
        pan: '',
        drivingLicense: '',
        passport: '',
        bankAccount: '',
        bankName: '',
        pfNumber: '',
        esiNumber: '',
        documentList: [],
      );
      expect(withBlood.contains('Aadhaar Card'), true);
      expect(withBlood.contains('Blood Group Certificate'), true);
      expect(withBlood.contains('PAN Card'), false);
    });
  });
}
