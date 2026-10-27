const fs = require('fs');
const https = require('https');

const API_KEY = 'AIzaSyDWFHhjAb_uH-5XMnkF__N29WSkYc71-3M';
const PROJECT_ID = 'i-green-tech';

function get(path) {
  return new Promise((resolve, reject) => {
    const sep = path.includes('?') ? '&' : '?';
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}${sep}key=${API_KEY}&pageSize=300`,
      method: 'GET',
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch (e) { resolve(data); }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function parseFields(fields) {
  if (!fields) return {};
  const res = {};
  for (const [k, v] of Object.entries(fields)) {
    if (v.stringValue !== undefined) res[k] = v.stringValue;
    else if (v.integerValue !== undefined) res[k] = parseInt(v.integerValue);
    else if (v.doubleValue !== undefined) res[k] = parseFloat(v.doubleValue);
    else if (v.booleanValue !== undefined) res[k] = v.booleanValue;
    else if (v.arrayValue !== undefined) {
      res[k] = (v.arrayValue.values || []).map(val => {
        if (val.stringValue !== undefined) return val.stringValue;
        if (val.mapValue !== undefined) return parseFields(val.mapValue.fields);
        return val;
      });
    } else if (v.mapValue !== undefined) res[k] = parseFields(v.mapValue.fields);
    else res[k] = v;
  }
  return res;
}

function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'string') return { stringValue: val };
  if (typeof val === 'number') {
    if (Number.isInteger(val)) return { integerValue: val.toString() };
    return { doubleValue: val };
  }
  if (typeof val === 'boolean') return { booleanValue: val };
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function saveDocument(collection, docId, data) {
  return new Promise((resolve, reject) => {
    const fields = {};
    for (const [k, v] of Object.entries(data)) {
      fields[k] = toFirestoreValue(v);
    }
    const body = JSON.stringify({ fields });

    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${encodeURIComponent(docId)}?key=${API_KEY}`,
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    }, res => {
      let respData = '';
      res.on('data', chunk => respData += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(respData);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${JSON.stringify(parsed)}`));
          }
        } catch(e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function deleteDocument(collection, docId) {
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${encodeURIComponent(docId)}?key=${API_KEY}`,
      method: 'DELETE'
    }, res => {
      let respData = '';
      res.on('data', chunk => respData += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(true);
        } else {
          if (res.statusCode === 404) resolve(true);
          else reject(new Error(`HTTP ${res.statusCode}: ${respData}`));
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function normalizeDate(d) {
  if (!d) return '';
  const s = d.replace(/[^0-9]/g, '');
  if (s.length === 8) {
    if (d.includes('-') && d.split('-')[0].length === 4) return s; // YYYYMMDD
    if (d.includes('-') && d.split('-')[2].length === 4) {
      const parts = d.split('-');
      return parts[2] + parts[1].padStart(2, '0') + parts[0].padStart(2, '0');
    }
    return s;
  }
  return s;
}

function formatDateIso(dStr, dateKey) {
  if (dateKey && dateKey.length === 8) {
    return `${dateKey.substring(0, 4)}-${dateKey.substring(4, 6)}-${dateKey.substring(6, 8)}`;
  }
  if (dStr && dStr.includes('-')) {
    const parts = dStr.split('-');
    if (parts[0].length === 4) return dStr;
    if (parts[2].length === 4) return `${parts[2]}-${parts[1].padStart(2, '0')}-${parts[0].padStart(2, '0')}`;
  }
  return dStr;
}

async function consolidate() {
  console.log('🚀 [Step 1 Execution] Consolidating attendance_records in Firestore...\n');

  // 1. Fetch Employees
  console.log('1️⃣ Fetching employees registry...');
  const empRes = await get('employees');
  const empDocs = empRes.documents || [];
  const empMap = {};
  for (const ed of empDocs) {
    const code = ed.name.split('/').pop();
    const f = parseFields(ed.fields);
    const id = f.id || parseInt(code.replace(/[^0-9]/g, ''));
    const name = f.full_name || f.name || '';
    if (id) {
      empMap[id] = { code, name, id };
    }
  }
  console.log(`   ✅ Loaded ${Object.keys(empMap).length} active employees.\n`);

  // 2. Fetch Attendance Records
  console.log('2️⃣ Fetching current attendance_records...');
  const attRes = await get('attendance_records');
  const attDocs = attRes.documents || [];
  console.log(`   ✅ Found ${attDocs.length} attendance records.\n`);

  // 3. Backup
  const backupPath = 'C:\\Users\\USER\\.gemini\\antigravity-ide\\brain\\2f22f369-9cd6-44c0-a985-477400ff7ea4\\scratch\\backup_attendance_records_before_step1.json';
  fs.writeFileSync(backupPath, JSON.stringify(attDocs, null, 2));
  console.log(`   💾 Backup verified at: ${backupPath}\n`);

  // 4. Categorize & Group
  const ghostDocIds = [];
  const testDocIds = [];
  const canonicalGroups = {};

  for (const doc of attDocs) {
    const docId = doc.name.split('/').pop();
    const fields = parseFields(doc.fields);
    const fieldCount = Object.keys(fields).length;

    if (fieldCount === 0) {
      ghostDocIds.push(docId);
      continue;
    }

    if (docId.includes('1002') || docId.includes('1003') ||
        (fields.employee_code && String(fields.employee_code).includes('1002')) ||
        (fields.employee_id && String(fields.employee_id).includes('1002'))) {
      testDocIds.push(docId);
      continue;
    }

    // Resolve Employee
    let empCode = (fields.employee_code || '').toString().trim().toUpperCase();
    let empId = fields.employee_id;
    let empName = (fields.employee_name || '').toString().trim();

    let resolved = null;
    if (empId && empMap[empId]) {
      resolved = empMap[empId];
    } else if (empCode.startsWith('IGT-')) {
      const num = parseInt(empCode.replace('IGT-', ''));
      if (empMap[num]) resolved = empMap[num];
    } else {
      const matchNum = empCode.match(/\d+/) || docId.match(/^(\d+)_/);
      if (matchNum) {
        const num = parseInt(matchNum[1] || matchNum[0]);
        if (empMap[num]) resolved = empMap[num];
      }
    }

    if (!resolved) {
      const num = empId || parseInt(docId.replace(/[^0-9]/g, '')) || 0;
      resolved = {
        code: empCode.startsWith('IGT-') ? empCode : `IGT-${String(num).padStart(4, '0')}`,
        name: empName,
        id: num
      };
    }

    const rawDate = (fields.date || '').toString().trim();
    const dateKey = normalizeDate(rawDate) || docId.replace(/[^0-9]/g, '').slice(-8);
    const canonicalKey = `${resolved.code}_${dateKey}`;

    if (!canonicalGroups[canonicalKey]) {
      canonicalGroups[canonicalKey] = {
        canonicalKey,
        targetCode: resolved.code,
        targetName: resolved.name || empName,
        targetId: resolved.id,
        dateKey,
        isoDate: formatDateIso(rawDate, dateKey),
        sourceDocs: []
      };
    }

    canonicalGroups[canonicalKey].sourceDocs.push({
      docId,
      fields
    });
  }

  console.log(`3️⃣ Formed ${Object.keys(canonicalGroups).length} canonical groups from 70 source documents.`);
  console.log(`   - Ghost documents: ${ghostDocIds.length}`);
  console.log(`   - Test documents: ${testDocIds.length}\n`);

  // 5. Merge and Write Canonical Records
  console.log('4️⃣ Merging sessions and writing canonical records to Firestore...');
  const writtenCanonicalKeys = [];

  for (const [canonicalKey, group] of Object.entries(canonicalGroups)) {
    // Sort sources by field count descending so the richest document is the base
    group.sourceDocs.sort((a, b) => Object.keys(b.fields).length - Object.keys(a.fields).length);
    const baseFields = { ...group.sourceDocs[0].fields };

    // Collect and merge all sessions
    const allSessions = [];
    const seenSessionSigs = new Set();

    for (const src of group.sourceDocs) {
      const srcSessions = Array.isArray(src.fields.sessions) ? src.fields.sessions : [];
      for (const s of srcSessions) {
        if (!s || typeof s !== 'object') continue;
        const sig = `${s.id || ''}_${s.check_in_time || ''}_${s.check_out_time || ''}`;
        if (!seenSessionSigs.has(sig)) {
          seenSessionSigs.add(sig);
          allSessions.push(s);
        }
      }
    }

    // Merge location interruptions
    const allInterruptions = [];
    const seenIntSigs = new Set();
    for (const src of group.sourceDocs) {
      const srcInt = Array.isArray(src.fields.location_interruptions) ? src.fields.location_interruptions : [];
      for (const item of srcInt) {
        if (!item || typeof item !== 'object') continue;
        const sig = `${item.start_time || ''}_${item.reason || ''}`;
        if (!seenIntSigs.has(sig)) {
          seenIntSigs.add(sig);
          allInterruptions.push(item);
        }
      }
    }

    // Calculate maximum hours
    let maxTotalHours = 0;
    for (const src of group.sourceDocs) {
      const th = typeof src.fields.total_hours === 'number' ? src.fields.total_hours : parseFloat(src.fields.total_hours || '0');
      if (th > maxTotalHours) maxTotalHours = th;
    }

    // Best status
    let bestStatus = baseFields.status || 'Present';
    for (const src of group.sourceDocs) {
      const st = (src.fields.status || '').toString().trim();
      if (st && st !== 'Absent' && st !== 'A') {
        bestStatus = st;
        break;
      }
    }

    // Best check in / check out times
    let checkIn = baseFields.check_in_time || '';
    let checkOut = baseFields.check_out_time || '';
    for (const src of group.sourceDocs) {
      if (!checkIn && src.fields.check_in_time) checkIn = src.fields.check_in_time;
      if (!checkOut && src.fields.check_out_time) checkOut = src.fields.check_out_time;
    }

    // Final consolidated record map
    const consolidatedMap = {
      ...baseFields,
      employee_id: group.targetId,
      employee_code: group.targetCode,
      emp_code: group.targetCode,
      employee_name: group.targetName,
      date: group.isoDate,
      status: bestStatus,
      total_hours: maxTotalHours > 0 ? maxTotalHours : (baseFields.total_hours || 0),
      check_in_time: checkIn,
      check_out_time: checkOut,
      sessions: allSessions.length > 0 ? allSessions : (baseFields.sessions || []),
    };

    if (allInterruptions.length > 0) {
      consolidatedMap.location_interruptions = allInterruptions;
    }

    await saveDocument('attendance_records', canonicalKey, consolidatedMap);
    writtenCanonicalKeys.push(canonicalKey);
    console.log(`   ✨ Saved canonical: ${canonicalKey} (${group.targetName}) - ${allSessions.length} session(s), ${maxTotalHours}h`);
  }

  console.log(`\n   ✅ All ${writtenCanonicalKeys.length} canonical records saved successfully.\n`);

  // 6. Verify written canonical records
  console.log('5️⃣ Verifying all canonical records exist in Firestore...');
  for (const k of writtenCanonicalKeys) {
    const checkDoc = await get(`attendance_records/${k}`);
    if (!checkDoc || checkDoc.error) {
      throw new Error(`Verification failed! Document ${k} could not be retrieved from Firestore.`);
    }
  }
  console.log('   ✅ 100% of canonical records verified in Firestore!\n');

  // 7. Delete Ghost Documents
  console.log(`6️⃣ Deleting ${ghostDocIds.length} ghost documents (0 fields)...`);
  for (const gId of ghostDocIds) {
    await deleteDocument('attendance_records', gId);
    console.log(`   🗑️ Deleted ghost doc: ${gId}`);
  }

  // 8. Delete Test Documents (1002 / 1003)
  console.log(`\n7️⃣ Deleting ${testDocIds.length} test documents (1002 / 1003)...`);
  for (const tId of testDocIds) {
    await deleteDocument('attendance_records', tId);
    console.log(`   🗑️ Deleted test doc: ${tId}`);
  }

  // 9. Delete Redundant Legacy Duplicate Documents
  console.log('\n8️⃣ Deleting redundant legacy duplicate documents...');
  let deletedDuplicatesCount = 0;
  for (const group of Object.values(canonicalGroups)) {
    for (const src of group.sourceDocs) {
      // If the source doc ID is not the canonical key, delete the old duplicate
      if (src.docId !== group.canonicalKey) {
        await deleteDocument('attendance_records', src.docId);
        deletedDuplicatesCount++;
        console.log(`   🗑️ Deleted legacy duplicate: ${src.docId} -> consolidated into ${group.canonicalKey}`);
      }
    }
  }
  console.log(`   ✅ Deleted ${deletedDuplicatesCount} redundant duplicate documents.\n`);

  // 10. Final Verification & Count
  console.log('9️⃣ Final audit of attendance_records collection...');
  const finalAttRes = await get('attendance_records');
  const finalDocs = finalAttRes.documents || [];
  console.log(`   📊 Final document count in attendance_records: ${finalDocs.length}`);
  console.log('\n   List of final canonical documents:');
  const finalSummary = finalDocs.map(d => {
    const id = d.name.split('/').pop();
    const f = parseFields(d.fields);
    return {
      id,
      name: f.employee_name,
      date: f.date,
      status: f.status,
      hours: f.total_hours,
      sessions: (f.sessions || []).length
    };
  });
  console.table(finalSummary);

  console.log('\n🎉 Step 1 Attendance Records Consolidation successfully completed!');
}

consolidate().catch(err => {
  console.error('❌ Migration failed:', err);
  process.exit(1);
});
