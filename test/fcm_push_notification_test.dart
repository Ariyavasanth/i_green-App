import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/notifications/domain/app_notification.dart';
import 'package:flutter_application_1/features/notifications/domain/notification_repository.dart';
import 'package:flutter_application_1/features/notifications/services/fcm_push_service.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_document.dart';
import 'package:flutter_application_1/features/tenders/domain/models/bqr_requirement_item.dart';
import 'package:flutter_application_1/features/tenders/domain/models/tender.dart';

class _FakeNotificationRepository implements NotificationRepository {
  final Map<String, Map<String, dynamic>> savedTokens = {};
  final List<String> removedTokens = [];

  @override
  Future<void> deleteNotification(String notificationId) async {}

  @override
  Future<void> markAllAsRead({
    required String employeeId,
    required List<String> notificationIds,
  }) async {}

  @override
  Future<void> markAsRead({
    required String notificationId,
    required String employeeId,
  }) async {}

  @override
  Future<void> dismissNotification({
    required String notificationId,
    required String employeeId,
  }) async {}

  @override
  Future<void> clearNotifications({
    required String employeeId,
    required List<String> notificationIds,
  }) async {}

  @override
  Future<void> sendNotification(AppNotification notification) async {}

  @override
  Stream<List<AppNotification>> watchNotificationsForUser({
    required Employee currentEmployee,
  }) =>
      Stream.value(const []);

  @override
  Future<void> saveFcmToken({
    required Employee employee,
    required String token,
    required String platform,
  }) async {
    savedTokens[token] = {
      'employee_id': employee.id,
      'employee_code': employee.employeeId,
      'platform': platform,
    };
  }

  @override
  Future<void> removeFcmToken({required String token}) async {
    savedTokens.remove(token);
    removedTokens.add(token);
  }
}

void main() {
  test('FcmPushService safely skips unsupported desktop test platform without throwing', () async {
    final repo = _FakeNotificationRepository();
    final service = FcmPushService(notificationRepository: repo);

    const employee = Employee(
      id: 42,
      employeeId: 'EMP-0042',
      firstName: 'Test',
      lastName: 'User',
      emailAddress: 'test@igreen.com',
      phoneNumber: '9999999999',
      gender: 'Male',
      dob: '1995-01-01',
      organizationName: 'Igreen',
      department: 'Engineering',
      designation: 'Engineer',
      employmentType: 'Full-Time',
      joiningDate: '2024-01-01',
      status: 'Active',
      accessPermissions: ['Leave Management'],
    );

    await service.syncForEmployee(employee);
    await service.syncForEmployee(null);
    service.dispose();

    expect(kFcmAndroidChannelId, 'igreen_high_importance_channel');
  });

  test('Tender closing soon & pending document count calculations are accurate', () {
    final now = DateTime.now();
    final closingInThreeDays = now.add(const Duration(days: 3));

    final tender = Tender(
      id: 't1',
      tenderId: 'TE-2026-0001',
      title: 'Solar Pump Installation',
      closingDate: closingInThreeDays,
      emdAmount: 50000,
      isEmdExempted: 'No',
      bqrRequirements: const [
        BqrRequirementItem(id: '1', title: 'GST Certificate', status: 'uploaded'),
        BqrRequirementItem(id: '2', title: 'Turnover CA Cert', status: 'pending'),
        BqrRequirementItem(id: '3', title: 'Work Experience', status: 'pending'),
      ],
      createdAt: now,
      updatedAt: now,
    );

    expect(tender.isClosingSoon, isTrue);
    expect(tender.daysUntilClosing, 3);
    expect(tender.pendingBqrCount, 2);
    expect(tender.missingCoreDocumentLabels, ['Financial Bid', 'EMD']);
    expect(tender.pendingDocumentCount, 4);

    // Finalized tenders should not trigger closing reminders
    final wonTender = tender.copyWith(status: 'Won');
    expect(wonTender.isClosingSoon, isFalse);

    // Uploaded docs reduce pending count to 0
    final readyTender = tender.copyWith(
      bqrRequirements: const [
        BqrRequirementItem(id: '1', title: 'GST Certificate', status: 'uploaded'),
      ],
      financialBidDocuments: [
        ProjectDocument(
          name: 'bid.pdf',
          size: 1024,
          downloadUrl: 'https://example.com/bid.pdf',
          uploadedAt: now,
        ),
      ],
      emdDocuments: [
        ProjectDocument(
          name: 'emd.pdf',
          size: 1024,
          downloadUrl: 'https://example.com/emd.pdf',
          uploadedAt: now,
        ),
      ],
    );
    expect(readyTender.pendingDocumentCount, 0);
  });

  test('AppNotification tracks per-user read and dismissed state accurately', () {
    final now = DateTime.now();
    final original = AppNotification(
      id: 'notif-1',
      title: 'New Leave Request',
      message: 'Submitted leave request',
      type: 'leave_request',
      requiredPermission: 'Leave Management',
      route: '/leave-management',
      createdAt: now,
      readByEmployeeIds: const ['101'],
      dismissedByEmployeeIds: const ['101'],
    );

    final serialized = original.toMap();
    final parsed = AppNotification.fromMap(serialized, 'notif-1');

    expect(parsed.isReadBy('101'), isTrue);
    expect(parsed.isDismissedBy('101'), isTrue);
    expect(parsed.isReadBy('202'), isFalse);
    expect(parsed.isDismissedBy('202'), isFalse);
  });
}
