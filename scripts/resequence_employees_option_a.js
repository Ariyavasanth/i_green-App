const https = require('https');
const { get, parseFields } = require('./inspect_orgs.js');

const API_KEY = 'AIzaSyDWFHhjAb_uH-5XMnkF__N29WSkYc71-3M';
const PROJECT_ID = 'i-green-tech';

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

async function resequence() {
  console.log('🔄 Fetching all employee documents from Firestore...');
  const res = await get('employees');
  const docs = res.documents || [];
  console.log(`Found ${docs.length} employee documents.`);

  // 1. Separate Super Admin, Dummy employees, and Real Employees
  let superAdminDoc = null;
  const realEmployees = [];

  for (const doc of docs) {
    const docKey = doc.name.split('/').pop();
    const data = parseFields(doc.fields);

    const email = (data.email_address || '').toLowerCase();
    const empId = (data.employee_id || '').toUpperCase();

    // Check if this is the Rahul Sharma dummy employee
    if (email === 'rahul.sharma@igreen.com' || docKey === 'EMP-1001' || empId === 'EMP-1001') {
      console.log(`🗑️ Deleting dummy employee [${docKey}] (${data.first_name} ${data.last_name})...`);
      await deleteDocument('employees', docKey);
      continue;
    }

    // Check if this is Super Admin
    if (data.is_super_admin === true || (data.user_type || '').toUpperCase() === 'SUPER ADMIN' && (email === 'admin@company.com' || docKey === 'EMP-001' || docKey === 'EMP-0001')) {
      superAdminDoc = { docKey, data };
      continue;
    }

    // Real production employee
    realEmployees.push({ docKey, data });
  }

  // 2. Sort real employees by their existing ID/number order
  realEmployees.sort((a, b) => {
    const numA = a.data.id || parseInt(String(a.data.employee_id || '').replace(/\D/g, ''), 10) || 0;
    const numB = b.data.id || parseInt(String(b.data.employee_id || '').replace(/\D/g, ''), 10) || 0;
    return numA - numB;
  });

  console.log(`\n📋 Resequencing Super Admin and ${realEmployees.length} production employees to Option A (EMP-0001, EMP-0002, ...)...`);

  // 3. Save Super Admin as EMP-0001
  if (superAdminDoc) {
    const newDocId = 'EMP-0001';
    const updatedData = {
      ...superAdminDoc.data,
      id: 1,
      employee_id: newDocId
    };
    await saveDocument('employees', newDocId, updatedData);
    console.log(`✅ Super Admin updated -> ${newDocId} (id: 1)`);
    if (superAdminDoc.docKey !== newDocId) {
      await deleteDocument('employees', superAdminDoc.docKey);
      console.log(`🗑️ Deleted old Super Admin key: ${superAdminDoc.docKey}`);
    }
  }

  // 4. Resequence all real employees starting from EMP-0002
  let seq = 2;
  for (const item of realEmployees) {
    const newDocId = `EMP-${String(seq).padStart(4, '0')}`;
    const oldDocKey = item.docKey;
    const updatedData = {
      ...item.data,
      id: seq,
      employee_id: newDocId,
      reporting_manager_id: item.data.reporting_manager_id === 'EMP-001' ? 'EMP-0001' : (item.data.reporting_manager_id || 'EMP-0001')
    };

    await saveDocument('employees', newDocId, updatedData);
    console.log(`✅ [${String(seq - 1).padStart(2, ' ')}/${realEmployees.length}] ${item.data.first_name} ${item.data.last_name || ''}: ${item.data.employee_id || oldDocKey} -> ${newDocId} (id: ${seq})`);

    // Delete old document if different
    if (oldDocKey !== newDocId) {
      await deleteDocument('employees', oldDocKey);
    }

    seq++;
  }

  console.log('\n🎉 Finished resequencing all production employees in Firestore database!');
}

resequence().catch(err => {
  console.error('❌ Resequencing error:', err);
  process.exit(1);
});
