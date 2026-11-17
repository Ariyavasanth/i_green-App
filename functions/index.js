const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

const ANDROID_CHANNEL_ID = 'igreen_high_importance_channel';

function normalizeClean(value) {
  return String(value || '')
    .replace(/\n/g, ' ')
    .trim()
    .toLowerCase()
    .replace(/[\s\-_&]+/g, '');
}

function isSuperAdminUser(userType, isSuperAdminFlag, role) {
  if (isSuperAdminFlag === true) return true;
  const t = String(userType || '').trim().toUpperCase();
  const r = String(role || '').trim().toUpperCase();
  return (
    t === 'SUPER_ADMIN' ||
    t === 'SUPER ADMIN' ||
    r === 'SUPER_ADMIN' ||
    r === 'SUPER ADMIN'
  );
}

function parsePermissions(raw) {
  if (Array.isArray(raw)) {
    return raw.map((p) => String(p));
  }
  if (typeof raw === 'string' && raw.trim().length > 0) {
    return raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return [];
}

function hasPermission({ isSuperAdmin, accessPermissions }, requiredPermission) {
  if (isSuperAdmin) return true;
  const req = String(requiredPermission || '').trim();
  if (!req) return true;

  const normClean = normalizeClean(req);
  const aliasGroups = [
    ['myonduty', 'onduty'],
    ['ondutymanagement', 'myondutymanagement'],
    ['leave', 'leaves', 'leavemanagement'],
    ['permission', 'permissions', 'mypermission'],
    ['permissionmanagement', 'permissionmgmt'],
    ['tasksandclockingmanagement', 'tasksclockingmanagement', 'tasksandtimesheets'],
    ['mytasks', 'tasks'],
    ['timeclocking', 'clocking'],
    ['sitevisitattendancemgmt', 'sitevisitattendancemanagement'],
  ];

  return accessPermissions.some((p) => {
    const pClean = normalizeClean(p);
    if (pClean === normClean) return true;
    return aliasGroups.some((group) => group.includes(normClean) && group.includes(pClean));
  });
}

function isSenderMatch(tokenData, senderId) {
  const s = String(senderId || '').trim().toLowerCase();
  if (!s || s === 'system') return false;
  const empId = String(tokenData.employee_id ?? '').trim().toLowerCase();
  const empCode = String(tokenData.employee_code ?? '').trim().toLowerCase();
  const email = String(tokenData.email ?? '').trim().toLowerCase();
  return (empId && empId === s) || (empCode && empCode === s) || (email && email === s);
}

/**
 * Automatically sends FCM push notifications (Android + Web) whenever a new
 * document is created in the Firestore `notifications` collection.
 */
exports.sendPushOnNotificationCreated = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notif = snap.data() || {};
    const notificationId = event.params.notificationId;
    const title = String(notif.title || 'Igreen Notification').trim();
    const message = String(notif.message || '').trim();
    const type = String(notif.type || 'general').trim();
    const requiredPermission = String(notif.required_permission || '').trim();
    const senderId = notif.sender_id != null ? String(notif.sender_id) : '';
    const route = String(notif.route || '/').trim() || '/';

    // Optional explicit recipient targeting via metadata.target_employee_ids
    const metadata = notif.metadata && typeof notif.metadata === 'object' ? notif.metadata : {};
    const targetEmployeeIds = Array.isArray(metadata.target_employee_ids)
      ? metadata.target_employee_ids.map((id) => String(id).trim().toLowerCase()).filter(Boolean)
      : [];

    const [tokensSnap, employeesSnap] = await Promise.all([
      db.collection('fcm_tokens').get(),
      db.collection('employees').get(),
    ]);

    if (tokensSnap.empty) {
      logger.info('No registered FCM tokens found; skipping push.', { notificationId });
      return;
    }

    // Build lookup maps from live `employees` collection so permission changes apply immediately
    const empByNumericId = new Map();
    const empByCode = new Map();
    const empByEmail = new Map();

    for (const doc of employeesSnap.docs) {
      const data = doc.data() || {};
      const record = {
        isSuperAdmin: isSuperAdminUser(
          data.user_type || data.userType,
          data.is_super_admin,
          data.role
        ),
        accessPermissions: parsePermissions(data.access_permissions || data.accessPermissions),
        status: String(data.status || 'Active').trim().toLowerCase(),
      };
      if (data.id !== undefined && data.id !== null) {
        empByNumericId.set(String(data.id).trim(), record);
      }
      if (data.employee_id) {
        empByCode.set(String(data.employee_id).trim().toLowerCase(), record);
      }
      if (data.email_address) {
        empByEmail.set(String(data.email_address).trim().toLowerCase(), record);
      }
    }

    const tokenEntries = [];
    const seenTokens = new Set();

    for (const doc of tokensSnap.docs) {
      const data = doc.data() || {};
      const token = String(data.token || '').trim();
      if (!token || seenTokens.has(token)) continue;

      // Avoid pushing back to the user who triggered the request
      if (isSenderMatch(data, senderId)) continue;

      // If specific target employees are listed, restrict to them
      if (targetEmployeeIds.length > 0) {
        const empIdStr = String(data.employee_id ?? '').trim().toLowerCase();
        const empCodeStr = String(data.employee_code ?? '').trim().toLowerCase();
        const emailStr = String(data.email ?? '').trim().toLowerCase();
        const matchedTarget =
          (empIdStr && targetEmployeeIds.includes(empIdStr)) ||
          (empCodeStr && targetEmployeeIds.includes(empCodeStr)) ||
          (emailStr && targetEmployeeIds.includes(emailStr));
        if (!matchedTarget) continue;
      }

      // Resolve live employee permissions if available, else fall back to token metadata
      const liveEmployee =
        empByNumericId.get(String(data.employee_id ?? '').trim()) ||
        empByCode.get(String(data.employee_code ?? '').trim().toLowerCase()) ||
        empByEmail.get(String(data.email ?? '').trim().toLowerCase());

      if (liveEmployee && liveEmployee.status === 'inactive') {
        continue;
      }

      const authContext = liveEmployee || {
        isSuperAdmin: isSuperAdminUser(data.user_type, data.is_super_admin, data.role),
        accessPermissions: parsePermissions(data.access_permissions),
      };

      if (!hasPermission(authContext, requiredPermission)) {
        continue;
      }

      seenTokens.add(token);
      tokenEntries.push({ docRef: doc.ref, token });
    }

    if (tokenEntries.length === 0) {
      logger.info('No eligible FCM recipients for notification.', {
        notificationId,
        type,
        requiredPermission,
      });
      return;
    }

    // Send in FCM multicast batches of up to 500 tokens
    const BATCH_SIZE = 500;
    let successCount = 0;
    let failureCount = 0;
    const staleDocRefs = [];

    for (let i = 0; i < tokenEntries.length; i += BATCH_SIZE) {
      const batch = tokenEntries.slice(i, i + BATCH_SIZE);
      const response = await messaging.sendEachForMulticast({
        tokens: batch.map((item) => item.token),
        notification: {
          title,
          body: message,
        },
        data: {
          notification_id: notificationId,
          type,
          route,
          title,
          message,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: ANDROID_CHANNEL_ID,
            icon: 'ic_notification',
            color: '#9CC70A',
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        webpush: {
          headers: {
            Urgency: 'high',
          },
          notification: {
            title,
            body: message,
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
          },
          fcmOptions: {
            link: route.startsWith('/') ? route : `/${route}`,
          },
        },
      });

      successCount += response.successCount;
      failureCount += response.failureCount;

      response.responses.forEach((res, idx) => {
        if (!res.success) {
          const code = res.error?.code || '';
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            staleDocRefs.push(batch[idx].docRef);
          } else {
            logger.warn('FCM send failed for token', { code, message: res.error?.message });
          }
        }
      });
    }

    // Clean up expired / unregistered tokens
    if (staleDocRefs.length > 0) {
      const deleteBatch = db.batch();
      staleDocRefs.forEach((ref) => deleteBatch.delete(ref));
      await deleteBatch.commit();
      logger.info(`Removed ${staleDocRefs.length} stale FCM token(s).`);
    }

    logger.info('FCM push dispatch completed.', {
      notificationId,
      type,
      targeted: tokenEntries.length,
      successCount,
      failureCount,
    });
  }
);

// ── Tender Closing Date Reminders (with Pending Document Count) ──────────────

const {
  formatIstDateKey,
  evaluateTenderClosingReminder,
} = require('./tender_reminder_helper');

async function createTenderClosingNotificationIfNeeded(tenderDocId, tenderData, now = new Date()) {
  const reminder = evaluateTenderClosingReminder(tenderData, now);
  if (!reminder) return false;

  const dateKey = formatIstDateKey(now);
  const notifDocId = `tender_closing_${tenderDocId}_${dateKey}`;
  const notifRef = db.collection('notifications').doc(notifDocId);

  try {
    // Atomic create() ensures at most one reminder push per tender per day
    await notifRef.create({
      id: notifDocId,
      title: reminder.title,
      message: reminder.message,
      type: 'tender_closing_reminder',
      required_permission: 'Projects',
      sender_id: 'SYSTEM',
      sender_name: 'Tender Reminder',
      route: '/projects/tenders',
      created_at: now.toISOString(),
      server_timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read_by_employee_ids: [],
      metadata: {
        tender_doc_id: tenderDocId,
        tender_id: reminder.tenderId,
        closing_date: reminder.readableCloseDate,
        days_until_closing: reminder.daysLeft,
        pending_bqr_count: reminder.pendingBqrCount,
        missing_core_documents: reminder.missingCoreDocs,
        pending_document_count: reminder.pendingDocumentCount,
      },
    });
    return true;
  } catch (err) {
    // Already exists for today (code 6 = ALREADY_EXISTS)
    if (err && (err.code === 6 || err.code === 'already-exists')) {
      return false;
    }
    throw err;
  }
}

/**
 * Runs every morning at 09:00 AM IST to send FCM push reminders for all active
 * tenders closing within 5 days, including the pending document count.
 */
exports.sendTenderClosingReminders = onSchedule(
  {
    schedule: '0 9 * * *',
    timeZone: 'Asia/Kolkata',
  },
  async () => {
    const now = new Date();
    const tendersSnap = await db.collection('tenders').get();
    let createdCount = 0;

    for (const doc of tendersSnap.docs) {
      const created = await createTenderClosingNotificationIfNeeded(doc.id, doc.data(), now);
      if (created) createdCount += 1;
    }

    logger.info('Daily tender closing reminder check completed.', {
      scannedTenders: tendersSnap.size,
      remindersTriggered: createdCount,
    });
  }
);

/**
 * Immediately triggers today's closing reminder push if a tender is created or
 * updated with a closing date within 5 days (deduped to once per tender per day).
 */
exports.notifyOnTenderClosingSoonWrite = onDocumentWritten(
  'tenders/{tenderDocId}',
  async (event) => {
    const afterSnap = event.data?.after;
    if (!afterSnap || !afterSnap.exists) return;

    const created = await createTenderClosingNotificationIfNeeded(
      event.params.tenderDocId,
      afterSnap.data(),
      new Date()
    );
    if (created) {
      logger.info('Immediate tender closing reminder notification created.', {
        tenderDocId: event.params.tenderDocId,
      });
    }
  }
);
