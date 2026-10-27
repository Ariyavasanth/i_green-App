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
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(data);
        }
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

function patchSpecificFields(collection, docId, data) {
  return new Promise((resolve, reject) => {
    const fields = {};
    const fieldPaths = [];
    for (const [k, v] of Object.entries(data)) {
      fields[k] = toFirestoreValue(v);
      fieldPaths.push(`updateMask.fieldPaths=${encodeURIComponent(k)}`);
    }
    const body = JSON.stringify({ fields });
    const maskQuery = fieldPaths.join('&');

    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${encodeURIComponent(docId)}?${maskQuery}&key=${API_KEY}`,
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
        } catch (e) {
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

async function runStep1() {
  console.log('====================================================');
  console.log('   STEP 1: FIRESTORE DATABASE SYNCHRONIZATION');
  console.log('====================================================\n');

  // ----------------------------------------------------
  // SUB-STEP 1: INSPECTION
  // ----------------------------------------------------
  console.log('🔍 [Sub-Step 1] Reading current Firestore employees collection...');
  const res = await get('employees');
  const allDocs = res.documents || [];
  console.log(`Total employee documents found: ${allDocs.length}\n`);

  const igtDocs = [];
  const empDocs = [];
  const otherDocs = [];

  for (const doc of allDocs) {
    const docId = doc.name.split('/').pop();
    const data = parseFields(doc.fields);
    if (docId.startsWith('IGT-')) {
      igtDocs.push({ docId, data });
    } else if (docId.startsWith('EMP-')) {
      empDocs.push({ docId, data });
    } else {
      otherDocs.push({ docId, data });
    }
  }

  console.log(`- Genuine IGT- documents: ${igtDocs.length}`);
  console.log(`- Stale EMP- documents:    ${empDocs.length}`);
  if (otherDocs.length > 0) {
    console.log(`- Other documents:         ${otherDocs.map(d => d.docId).join(', ')}`);
  }
  console.log('');

  // ----------------------------------------------------
  // SUB-STEP 2: UPDATE 26 GENUINE IGT-XXXX DOCUMENTS
  // ----------------------------------------------------
  console.log('📝 [Sub-Step 2] Updating employee_id and reporting_manager_id in IGT- documents...');
  igtDocs.sort((a, b) => a.docId.localeCompare(b.docId));

  let updatedCount = 0;
  for (const item of igtDocs) {
    const docId = item.docId;
    const data = item.data;
    const name = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    
    // employee_id must equal the docId (e.g. IGT-0007)
    // reporting_manager_id:
    // If docId is IGT-0001 (G S Saravanan, Top Head), reporting_manager_id is empty.
    // For everyone else, reporting_manager_id is "IGT-0001".
    const targetEmpId = docId;
    const targetManagerId = (docId === 'IGT-0001') ? '' : 'IGT-0001';

    const updates = {};
    if (data.employee_id !== targetEmpId) {
      updates.employee_id = targetEmpId;
    }
    if ((data.reporting_manager_id || '') !== targetManagerId) {
      updates.reporting_manager_id = targetManagerId;
    }
    if (!data.organization_name || data.organization_name !== 'IGREEN TECHNOLOGIES') {
      updates.organization_name = 'IGREEN TECHNOLOGIES';
    }

    if (Object.keys(updates).length > 0) {
      await patchSpecificFields('employees', docId, updates);
      console.log(`  ✓ Updated [${docId}] (${name}): ${JSON.stringify(updates)}`);
      updatedCount++;
    } else {
      console.log(`  ✓ [${docId}] (${name}): Already up-to-date.`);
    }
  }
  console.log(`\nSub-Step 2 complete: ${updatedCount} IGT document(s) updated.\n`);

  // ----------------------------------------------------
  // SUB-STEP 3: DELETE 5 STALE DUPLICATE EMP- DOCUMENTS
  // ----------------------------------------------------
  console.log('🗑️ [Sub-Step 3] Removing stale duplicate EMP- documents...');
  let deletedCount = 0;
  for (const item of empDocs) {
    const docId = item.docId;
    const data = item.data;
    const name = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    console.log(`  🗑️ Deleting duplicate doc: [${docId}] (${name})...`);
    await deleteDocument('employees', docId);
    deletedCount++;
  }
  console.log(`Sub-Step 3 complete: ${deletedCount} duplicate document(s) deleted.\n`);

  // ----------------------------------------------------
  // SUB-STEP 4: NORMALIZE ATTENDANCE RECORDS
  // ----------------------------------------------------
  console.log('⏱️ [Sub-Step 4] Normalizing attendance_records collection codes...');
  try {
    const attRes = await get('attendance_records');
    const attDocs = attRes.documents || [];
    console.log(`Total attendance records found: ${attDocs.length}`);
    let attUpdatedCount = 0;

    for (const doc of attDocs) {
      const docId = doc.name.split('/').pop();
      const data = parseFields(doc.fields);
      const empCode = data.emp_code || data.employee_code || '';
      
      let normalizedCode = empCode;
      if (empCode.startsWith('EMP-')) {
        // e.g. EMP-0121 -> IGT-0121
        normalizedCode = 'IGT-' + empCode.substring(4);
      } else if (empCode.startsWith('IGT-') && empCode.length < 8) {
        // e.g. IGT-217 -> IGT-0217
        const num = empCode.replace('IGT-', '').trim();
        normalizedCode = 'IGT-' + num.padStart(4, '0');
      }

      if (normalizedCode !== empCode && normalizedCode.startsWith('IGT-')) {
        await patchSpecificFields('attendance_records', docId, {
          emp_code: normalizedCode,
          employee_code: normalizedCode,
        });
        console.log(`  ✓ Updated attendance [${docId}]: ${empCode} -> ${normalizedCode}`);
        attUpdatedCount++;
      }
    }
    console.log(`Sub-Step 4 complete: ${attUpdatedCount} attendance record(s) normalized.\n`);
  } catch (attErr) {
    console.log(`Notice in Sub-Step 4: ${attErr.message}`);
  }

  // ----------------------------------------------------
  // SUB-STEP 5: VERIFICATION SUMMARY
  // ----------------------------------------------------
  console.log('📊 [Sub-Step 5] Final Verification: Querying Firestore employees...');
  const finalRes = await get('employees');
  const finalDocs = (finalRes.documents || []).map(d => {
    return {
      docId: d.name.split('/').pop(),
      data: parseFields(d.fields)
    };
  });
  finalDocs.sort((a, b) => a.docId.localeCompare(b.docId));

  console.log('\n================ FINAL EMPLOYEES IN FIRESTORE ================');
  console.log('| Doc ID   | employee_id | Manager ID | Name                | Organization       |');
  console.log('|----------|-------------|------------|---------------------|--------------------|');
  for (const emp of finalDocs) {
    const name = `${emp.data.first_name || ''} ${emp.data.last_name || ''}`.trim().padEnd(19).slice(0, 19);
    const docId = emp.docId.padEnd(8);
    const empId = (emp.data.employee_id || '').padEnd(11);
    const mgrId = (emp.data.reporting_manager_id || '-').padEnd(10);
    const org = (emp.data.organization_name || '').padEnd(18).slice(0, 18);
    console.log(`| ${docId} | ${empId} | ${mgrId} | ${name} | ${org} |`);
  }
  console.log('==============================================================');
  console.log(`Total Final Employees: ${finalDocs.length}`);
  const hasStaleEmp = finalDocs.some(e => e.docId.startsWith('EMP-') || (e.data.employee_id || '').startsWith('EMP-'));
  if (!hasStaleEmp && finalDocs.length === 26) {
    console.log('\n✅ SUCCESS: All 26 employees are synchronized with IGT- prefix, zero duplicate EMP- documents remain.');
  } else {
    console.log(`\n⚠️ Notice: Verified ${finalDocs.length} employees (hasStaleEmp: ${hasStaleEmp}).`);
  }
}

runStep1().catch(err => {
  console.error('❌ Error executing Step 1:', err);
  process.exit(1);
});
