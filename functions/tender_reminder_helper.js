const TENDER_REMINDER_WINDOW_DAYS = 5;
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

function parseDateValue(raw) {
  if (!raw) return null;
  if (typeof raw.toDate === 'function') {
    const d = raw.toDate();
    return Number.isNaN(d.getTime()) ? null : d;
  }
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? null : d;
}

function getIstDayStartUtcMs(date) {
  const ist = new Date(date.getTime() + IST_OFFSET_MS);
  return Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate());
}

function formatIstDateKey(date) {
  const ist = new Date(date.getTime() + IST_OFFSET_MS);
  const y = ist.getUTCFullYear();
  const m = String(ist.getUTCMonth() + 1).padStart(2, '0');
  const d = String(ist.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function formatIstReadableDate(date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const ist = new Date(date.getTime() + IST_OFFSET_MS);
  const day = String(ist.getUTCDate()).padStart(2, '0');
  return `${day} ${months[ist.getUTCMonth()]} ${ist.getUTCFullYear()}`;
}

function evaluateTenderClosingReminder(tenderData, now = new Date()) {
  if (!tenderData || typeof tenderData !== 'object') return null;

  const status = String(tenderData.status || '').trim().toLowerCase();
  if (status === 'won' || status === 'rejected' || status === 'lost') {
    return null;
  }

  const closingDate = parseDateValue(tenderData.closing_date);
  if (!closingDate) return null;

  if (closingDate.getTime() < now.getTime()) return null;

  const todayStart = getIstDayStartUtcMs(now);
  const closeStart = getIstDayStartUtcMs(closingDate);
  const daysLeft = Math.round((closeStart - todayStart) / (24 * 60 * 60 * 1000));

  if (daysLeft < 0 || daysLeft > TENDER_REMINDER_WINDOW_DAYS) {
    return null;
  }

  // Count pending BQR checklist items
  const bqrReqs = Array.isArray(tenderData.bqr_requirements) ? tenderData.bqr_requirements : [];
  let pendingBqrCount = 0;
  for (const item of bqrReqs) {
    if (!item || typeof item !== 'object') continue;
    const itemStatus = String(item.status || '').trim().toLowerCase();
    const docs = Array.isArray(item.documents) ? item.documents : [];
    const isUploaded = itemStatus === 'uploaded' || docs.length > 0;
    if (!isUploaded) {
      pendingBqrCount += 1;
    }
  }

  // Count missing core submission documents (Financial Bid & EMD / EMD Exemption)
  const missingCoreDocs = [];
  const financialBidDocs = Array.isArray(tenderData.financial_bid_documents)
    ? tenderData.financial_bid_documents
    : [];
  if (financialBidDocs.length === 0) {
    missingCoreDocs.push('Financial Bid');
  }

  const isEmdExempted = String(tenderData.is_emd_exempted || 'No').trim().toLowerCase() === 'yes';
  const emdAmount = Number(tenderData.emd_amount || 0);
  if (isEmdExempted) {
    const emdExemptionDocs = Array.isArray(tenderData.emd_exemption_documents)
      ? tenderData.emd_exemption_documents
      : [];
    if (emdExemptionDocs.length === 0) {
      missingCoreDocs.push('EMD Exemption');
    }
  } else if (emdAmount > 0) {
    const emdDocs = Array.isArray(tenderData.emd_documents) ? tenderData.emd_documents : [];
    if (emdDocs.length === 0) {
      missingCoreDocs.push('EMD');
    }
  }

  const pendingDocumentCount = pendingBqrCount + missingCoreDocs.length;
  const tenderId = String(tenderData.tender_id || '').trim() || 'Tender';
  const tenderTitle = String(tenderData.title || '').trim();
  const displayName = tenderTitle ? `${tenderId} - ${tenderTitle}` : tenderId;
  const readableCloseDate = formatIstReadableDate(closingDate);

  const parts = [];
  if (pendingBqrCount > 0) parts.push(`${pendingBqrCount} BQR`);
  parts.push(...missingCoreDocs);
  const breakdown = parts.length > 0 ? ` (${parts.join(', ')})` : '';

  const timingText =
    daysLeft === 0
      ? `Closes TODAY (${readableCloseDate})`
      : `Closes in ${daysLeft} day(s) (${readableCloseDate})`;
  const pendingText =
    pendingDocumentCount > 0
      ? `${pendingDocumentCount} pending document(s)${breakdown}.`
      : '0 pending documents — ready for submission.';

  return {
    tenderId,
    displayName,
    readableCloseDate,
    daysLeft,
    pendingBqrCount,
    missingCoreDocs,
    pendingDocumentCount,
    title:
      daysLeft === 0
        ? `Tender Closing TODAY: ${displayName}`
        : `Tender Closing Soon: ${displayName}`,
    message: `${timingText} • ${pendingText}`,
  };
}

module.exports = {
  TENDER_REMINDER_WINDOW_DAYS,
  formatIstDateKey,
  evaluateTenderClosingReminder,
};
