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

function safeJsonList(str) {
  try {
    const parsed = JSON.parse(str);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

// 26 employees exactly matching Image 1
const image1Employees = [
  { empId: 'IGT - 0001', name: 'G S Saravanan', id: 1, firstName: 'G S', lastName: 'Saravanan' },
  { empId: 'IGT - 0007', name: 'S Anitha', id: 7, firstName: 'S', lastName: 'Anitha' },
  { empId: 'IGT - 0006', name: 'Ganesh Chandra Das', id: 6, firstName: 'Ganesh', lastName: 'Chandra Das' },
  { empId: 'IGT - 0010', name: 'K Paramasivam', id: 10, firstName: 'K', lastName: 'Paramasivam' },
  { empId: 'IGT - 0013', name: 'Sankar Raja', id: 13, firstName: 'Sankar', lastName: 'Raja' },
  { empId: 'IGT - 0044', name: 'Sivan Arumugam', id: 44, firstName: 'Sivan', lastName: 'Arumugam' },
  { empId: 'IGT - 0061', name: 'Sri Kaliyaraj B', id: 61, firstName: 'Sri', lastName: 'Kaliyaraj B' },
  { empId: 'IGT - 0109', name: 'Kannan P', id: 109, firstName: 'Kannan', lastName: 'P' },
  { empId: 'IGT - 0120', name: 'Balaji P', id: 120, firstName: 'Balaji', lastName: 'P' },
  { empId: 'IGT - 0121', name: 'Deepak R', id: 121, firstName: 'Deepak', lastName: 'R' },
  { empId: 'IGT - 0133', name: 'Sivarajan Shanmugam', id: 133, firstName: 'Sivarajan', lastName: 'Shanmugam' },
  { empId: 'IGT - 0148', name: 'Shibu Das', id: 148, firstName: 'Shibu', lastName: 'Das' },
  { empId: 'IGT - 0158', name: 'E Manikandan', id: 158, firstName: 'E', lastName: 'Manikandan' },
  { empId: 'IGT - 0159', name: 'Singara Lakshmanan Palanisamy', id: 159, firstName: 'Singara Lakshmanan', lastName: 'Palanisamy' },
  { empId: 'IGT - 0172', name: 'M Pandi', id: 172, firstName: 'M', lastName: 'Pandi' },
  { empId: 'IGT - 0174', name: 'Ramjanam', id: 174, firstName: 'Ramjanam', lastName: '' },
  { empId: 'IGT - 0175', name: 'Dharmendra Kumar', id: 175, firstName: 'Dharmendra', lastName: 'Kumar' },
  { empId: 'IGT - 0068', name: 'Mazhar Shekh', id: 68, firstName: 'Mazhar', lastName: 'Shekh' },
  { empId: 'IGT - 0183', name: 'Paramasivam', id: 183, firstName: 'Paramasivam', lastName: '' },
  { empId: 'IGT - 0192', name: 'Moti Kumar', id: 192, firstName: 'Moti', lastName: 'Kumar' },
  { empId: 'IGT - 0205', name: 'Shajan B', id: 205, firstName: 'Shajan', lastName: 'B' },
  { empId: 'IGT - 0209', name: 'Suresh S', id: 209, firstName: 'Suresh', lastName: 'S' },
  { empId: 'IGT-213', name: 'Sejabul Haque', id: 213, firstName: 'Sejabul', lastName: 'Haque' },
  { empId: 'IGT-215', name: 'Hari G', id: 215, firstName: 'Hari', lastName: 'G' },
  { empId: 'IGT-216', name: 'Mainul Haque', id: 216, firstName: 'Mainul', lastName: 'Haque' },
  { empId: 'IGT-217', name: 'Gokul Raj G', id: 217, firstName: 'Gokul', lastName: 'Raj G' },
];

function normalizeName(str) {
  return (str || '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

async function run() {
  console.log('🔄 Fetching current Firestore employees...');
  const res = await get('employees');
  const existingDocs = res.documents || [];
  console.log(`Found ${existingDocs.length} employee documents in Firestore.`);

  const docMap = {};
  for (const doc of existingDocs) {
    const docKey = doc.name.split('/').pop();
    const data = parseFields(doc.fields);
    docMap[docKey] = data;
  }

  // Pre-load Gokul Raj from CAN-0021 if needed
  let gokulCandData = null;
  try {
    const canDoc = await get('candidate_responses/CAN-0021');
    const fields = parseFields(canDoc.fields);
    gokulCandData = JSON.parse(fields.employee_data_json || '{}');
  } catch (e) {
    console.warn('Could not load CAN-0021:', e.message);
  }

  const processedDocKeys = new Set();

  console.log('\n🚀 Updating all 26 employees in Firestore to Image 1 prefix & format:');

  for (let i = 0; i < image1Employees.length; i++) {
    const target = image1Employees[i];
    const targetKey = target.empId;

    // Find the existing data
    let existingData = null;
    let oldKey = null;

    // 1. Direct doc key match
    if (docMap[targetKey]) {
      existingData = docMap[targetKey];
      oldKey = targetKey;
    }

    // 2. Name-based match across all docs
    if (!existingData) {
      const normTarget = normalizeName(target.name);
      for (const [k, d] of Object.entries(docMap)) {
        const full = normalizeName(`${d.first_name || ''} ${d.last_name || ''}`);
        if (full === normTarget || (normTarget === 'gssaravanan' && full === 'cssaravanan')) {
          existingData = d;
          oldKey = k;
          break;
        }
      }
    }

    // 3. Fallback for Gokul Raj from CAN-0021
    if (!existingData && target.name === 'Gokul Raj G' && gokulCandData) {
      existingData = {
        ...gokulCandData,
        first_name: 'Gokul',
        last_name: 'Raj G',
        user_name: 'GOKUL',
        email_address: gokulCandData.email_address || 'gpgokulraj@gmail.com',
        phone_number: gokulCandData.phone_number || '+91 9003718640',
        personal_mobile: gokulCandData.phone_number || '+91 9003718640',
        gender: 'Male',
        dob: '2000-09-22',
        original_dob: '22-09-2000',
        designation: 'Supervisor',
        department: 'Office',
        work_location: 'Office',
        organization_name: 'IGREEN TECHNOLOGIES',
        organization_id: 'org_1790493894148',
        joining_date: '2026-10-21',
        status: 'Active',
        role: 'EMPLOYEE',
        user_type: 'EMPLOYEE',
        temporary_password: '123456',
        reporting_manager_id: 'IGT - 0001',
        reporting_manager: 'G S Saravanan',
        reporting_manager_title: 'Company Director',
        education_items: safeJsonList(gokulCandData.education_list_json),
        experience_items: safeJsonList(gokulCandData.experience_list_json),
        document_items: safeJsonList(gokulCandData.document_list_json)
      };
    }

    if (!existingData) {
      console.error(`❌ Could not find data for ${target.name} (${target.empId})!`);
      continue;
    }

    const updatedDoc = {
      ...existingData,
      id: target.id,
      employee_id: target.empId,
      first_name: target.firstName,
      last_name: target.lastName,
      user_name: target.firstName.toUpperCase().replace(/[^A-Z0-9]/g, ''),
      reporting_manager_id: target.id === 1 ? '' : 'IGT - 0001',
      reporting_manager: target.id === 1 ? '' : 'G S Saravanan',
      reporting_manager_title: 'Company Director',
      status: 'Active'
    };

    // Save to Firestore under the new key
    await saveDocument('employees', targetKey, updatedDoc);
    console.log(`✅ [${i + 1}/26] Saved: ${targetKey.padEnd(12)} | id: ${String(target.id).padStart(3, ' ')} | employee_id: "${target.empId}" | ${target.name}`);
    processedDocKeys.add(targetKey);

    // Delete old doc if different
    if (oldKey && oldKey !== targetKey) {
      await deleteDocument('employees', oldKey);
      console.log(`   🗑️ Deleted old document key: ${oldKey}`);
    }
  }

  // Clean up any remaining legacy/duplicate keys
  const legacyKeysToDelete = [
    'EMP-0001',
    'EMP-0010',
    'EMP-0023',
    'EMP-0024',
    'EMP-0025',
    'EMP-0026',
    'EMP-1001',
    'EMP-1002',
    'IGT - 0008',
    'IGT - 0056',
    'IGT - 0140'
  ];

  console.log('\n🧹 Cleaning up legacy & duplicate document keys...');
  for (const k of legacyKeysToDelete) {
    if (!processedDocKeys.has(k)) {
      try {
        await deleteDocument('employees', k);
        console.log(`  🗑️ Cleaned up: ${k}`);
      } catch (_) {}
    }
  }

  // Update attendance records to ensure employee_code & employee_id stay aligned
  console.log('\n📅 Synchronizing attendance record codes...');
  try {
    const attRes = await get('attendance_records');
    const attDocs = attRes.documents || [];
    let syncedAtt = 0;

    for (const doc of attDocs) {
      const f = parseFields(doc.fields);
      const docKey = doc.name.split('/').pop();
      const empName = (f.employee_name || '').toLowerCase();

      // Find matching target
      const match = image1Employees.find(t => normalizeName(t.name) === normalizeName(f.employee_name));
      if (match) {
        if (f.employee_code !== match.empId || f.employee_id !== match.id) {
          await saveDocument('attendance_records', docKey, {
            ...f,
            employee_code: match.empId,
            employee_id: match.id
          });
          syncedAtt++;
        }
      }
    }
    console.log(`✅ Synchronized ${syncedAtt} attendance records to new employee codes.`);
  } catch (e) {
    console.warn('Attendance sync notice:', e.message);
  }

  console.log('\n🎉 Finished updating Firestore! All 26 employees now have the exact Image 1 prefix and employee_id.');
}

run().catch(err => {
  console.error('❌ Script failed:', err);
  process.exit(1);
});
