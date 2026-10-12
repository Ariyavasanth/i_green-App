import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/organization/domain/organization.dart';

void main() {
  group('OrganizationBankDetail Model Tests', () {
    test('creates and serializes OrganizationBankDetail to and from map', () {
      final chequeDoc = OrgDocument(
        title: 'Cancelled Cheque - 501002345678',
        fileName: 'cheque_leaf.pdf',
        fileUrl: 'https://firebasestorage.googleapis.com/v0/b/app/cheque.pdf',
        uploadedAt: '2026-10-12T10:00:00.000Z',
      );

      final bank = OrganizationBankDetail(
        id: 'bank_123',
        bankName: 'HDFC Bank',
        accountNumber: '501002345678',
        ifscCode: 'HDFC0001234',
        cifCode: 'CIF98765',
        branch: 'Ambattur Industrial Estate',
        cancelledChequeDoc: chequeDoc,
      );

      final map = bank.toMap();
      expect(map['id'], 'bank_123');
      expect(map['bank_name'], 'HDFC Bank');
      expect(map['account_number'], '501002345678');
      expect(map['ifsc_code'], 'HDFC0001234');
      expect(map['cif_code'], 'CIF98765');
      expect(map['branch'], 'Ambattur Industrial Estate');
      expect(map['cancelled_cheque_doc'], isA<Map<String, dynamic>>());
      expect(map['cancelled_cheque_doc']['file_name'], 'cheque_leaf.pdf');

      final deserialized = OrganizationBankDetail.fromMap(map);
      expect(deserialized.id, 'bank_123');
      expect(deserialized.bankName, 'HDFC Bank');
      expect(deserialized.accountNumber, '501002345678');
      expect(deserialized.ifscCode, 'HDFC0001234');
      expect(deserialized.cifCode, 'CIF98765');
      expect(deserialized.branch, 'Ambattur Industrial Estate');
      expect(deserialized.cancelledChequeDoc, isNotNull);
      expect(deserialized.cancelledChequeDoc!.fileName, 'cheque_leaf.pdf');
      expect(deserialized.cancelledChequeDoc!.fileUrl, chequeDoc.fileUrl);
    });

    test('supports copyWith on OrganizationBankDetail', () {
      const bank = OrganizationBankDetail(
        id: 'b1',
        bankName: 'SBI',
        accountNumber: '111122223333',
        ifscCode: 'SBIN0001234',
      );

      final updated = bank.copyWith(
        bankName: 'State Bank of India',
        branch: 'Main Branch',
      );

      expect(updated.id, 'b1');
      expect(updated.bankName, 'State Bank of India');
      expect(updated.accountNumber, '111122223333');
      expect(updated.ifscCode, 'SBIN0001234');
      expect(updated.branch, 'Main Branch');
    });
  });

  group('Organization with Bank Details & Statutory Documents Tests', () {
    test(
      'serializes Organization with multiple bank details, GSTIN and PAN certificates',
      () {
        final gstinDoc = OrgDocument(
          title: 'GSTIN Certificate',
          fileName: 'gst_certificate.pdf',
          fileUrl: 'https://storage/gst.pdf',
        );
        final panDoc = OrgDocument(
          title: 'PAN Certificate',
          fileName: 'pan_certificate.pdf',
          fileUrl: 'https://storage/pan.pdf',
        );

        final bank1 = const OrganizationBankDetail(
          id: 'bank_1',
          bankName: 'HDFC Bank',
          accountNumber: '1234567890',
          ifscCode: 'HDFC0000001',
          branch: 'Branch A',
        );
        final bank2 = const OrganizationBankDetail(
          id: 'bank_2',
          bankName: 'ICICI Bank',
          accountNumber: '9876543210',
          ifscCode: 'ICIC0000002',
          branch: 'Branch B',
        );

        final org = Organization(
          id: 101,
          docId: 'org_101',
          name: 'IGreentec Engg India Pvt Ltd',
          businessType: 'Private Limited Company',
          industryType: 'Engineering',
          businessUnits: 'HDD, Drilling',
          locations: 'Chennai, Ambattur',
          address: '557 Mangaldeep',
          phoneNumber: '9876543210',
          emailAddress: 'info@igreentec.example',
          website: 'https://igreentec.example',
          taxId: '33ABCDE1234F1Z5',
          gstNumber: '33ABCDE1234F1Z5',
          panNumber: 'ABCDE1234F',
          documents: [gstinDoc, panDoc],
          bankDetails: [bank1, bank2],
        );

        final map = org.toMap();
        expect(map['documents'], hasLength(2));
        expect(map['bank_details'], hasLength(2));

        final deserialized = Organization.fromMap(map, 'org_101');
        expect(deserialized.name, 'IGreentec Engg India Pvt Ltd');
        expect(deserialized.documents, hasLength(2));
        expect(
          deserialized.documents.any((d) => d.title == 'GSTIN Certificate'),
          isTrue,
        );
        expect(
          deserialized.documents.any((d) => d.title == 'PAN Certificate'),
          isTrue,
        );
        expect(deserialized.bankDetails, hasLength(2));
        expect(deserialized.bankDetails[0].bankName, 'HDFC Bank');
        expect(deserialized.bankDetails[1].bankName, 'ICICI Bank');
      },
    );

    test(
      'safely handles legacy Organization record with missing bank_details',
      () {
        final legacyMap = <String, dynamic>{
          'id': 202,
          'doc_id': 'org_202',
          'name': 'Legacy Org Without Banks',
          'business_type': 'Proprietorship',
          'industry_type': 'Trading',
          'phone_number': '9998887776',
          'email_address': 'legacy@example.com',
          'directors': [
            {'name': 'Director 1', 'din': '12345678'},
          ],
          'documents': [
            {
              'title': 'Certificate of Incorporation',
              'file_name': 'inc.pdf',
              'file_url': 'https://storage/inc.pdf',
            },
          ],
        };

        final org = Organization.fromMap(legacyMap);
        expect(org.id, 202);
        expect(org.name, 'Legacy Org Without Banks');
        expect(org.bankDetails, isEmpty);
        expect(org.directors, hasLength(1));
        expect(org.documents, hasLength(1));
      },
    );

    test('removing one bank entry does not affect other bank entries', () {
      final bank1 = const OrganizationBankDetail(
        id: 'bank_1',
        bankName: 'Axis Bank',
        accountNumber: '1111111111',
        ifscCode: 'UTIB0000001',
      );
      final bank2 = const OrganizationBankDetail(
        id: 'bank_2',
        bankName: 'Kotak Bank',
        accountNumber: '2222222222',
        ifscCode: 'KKBK0000002',
      );

      final org = Organization(
        id: 303,
        name: 'Multi Bank Org',
        businessType: 'Pvt Ltd',
        industryType: 'Services',
        businessUnits: '',
        locations: '',
        address: '',
        phoneNumber: '',
        emailAddress: '',
        website: '',
        taxId: '',
        bankDetails: [bank1, bank2],
      );

      // Remove bank1
      final updatedBanks = List<OrganizationBankDetail>.from(org.bankDetails)
        ..removeWhere((b) => b.id == 'bank_1');

      final updatedOrg = org.copyWith(bankDetails: updatedBanks);
      expect(updatedOrg.bankDetails, hasLength(1));
      expect(updatedOrg.bankDetails.first.id, 'bank_2');
      expect(updatedOrg.bankDetails.first.bankName, 'Kotak Bank');
    });

    test('validates standard Indian IFSC format', () {
      final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

      expect(ifscRegex.hasMatch('HDFC0001234'), isTrue);
      expect(ifscRegex.hasMatch('SBIN0000456'), isTrue);
      expect(ifscRegex.hasMatch('ICIC0007890'), isTrue);

      // Invalid cases
      expect(
        ifscRegex.hasMatch('HDFC1001234'),
        isFalse,
        reason: '5th character must be 0',
      );
      expect(
        ifscRegex.hasMatch('HDF0001234'),
        isFalse,
        reason: 'Must be 11 characters',
      );
      expect(
        ifscRegex.hasMatch('hdfc0001234'),
        isFalse,
        reason: 'Must be uppercase',
      );
      expect(ifscRegex.hasMatch('HDFC00012345'), isFalse, reason: 'Too long');
    });
  });
}
