const https = require('https');
const fs = require('fs');

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

async function addTestingEmployee() {
  console.log('📖 Reading previous testing employee data from can23.json...');
  const cand = JSON.parse(fs.readFileSync('can23.json', 'utf8'));
  const empData = JSON.parse(cand.employee_data_json);

  const docId = 'EMP-1002';
  const integerId = 1002;

  // Safe parsing helper for json array strings
  function safeJsonList(str) {
    try {
      const parsed = JSON.parse(str);
      return Array.isArray(parsed) ? parsed : [];
    } catch (_) {
      return [];
    }
  }

  const educationItems = safeJsonList(empData.education_list_json);
  const experienceItems = safeJsonList(empData.experience_list_json);
  const documentItems = safeJsonList(empData.document_list_json);

  const testingEmployeeDoc = {
    ...empData,
    id: integerId,
    employee_id: docId,
    status: 'Active',
    role: empData.user_type || 'EMPLOYEE',
    user_type: empData.user_type || 'EMPLOYEE',
    user_name: `${empData.first_name || 'Test'} ${empData.last_name || 'one'}`.trim(),
    organization_name: empData.organization_name || 'IGREEN TECHNOLOGIES',
    organization_id: 'org_1790493894148',
    reporting_manager_id: 'EMP-0001',
    reporting_manager: 'Super Admin',
    reporting_manager_title: 'Super Administrator',
    education_items: educationItems,
    experience_items: experienceItems,
    document_items: documentItems,
    joining_date: empData.joining_date || '2026-10-22'
  };

  console.log(`💾 Saving testing employee to Firestore collection "employees/${docId}"...`);
  await saveDocument('employees', docId, testingEmployeeDoc);
  console.log(`✅ Successfully added testing employee: [${docId}] (id: ${integerId}) - ${testingEmployeeDoc.first_name} ${testingEmployeeDoc.last_name}`);

  // Also ensure registration_links/draft_test and CAN-0023 are marked active/converted
  try {
    await saveDocument('registration_links', 'draft_test', {
      link_id: 'draft_test',
      candidate_id: 'CAN-0023',
      candidate_name: 'Test one',
      employee_id: docId,
      employee_name: 'Test one',
      link_status: 'Converted',
      status: 'Converted'
    });
    console.log('✅ Updated registration link draft_test status to Converted');
  } catch (e) {
    console.log('⚠️ Notice on draft_test:', e.message);
  }
}

addTestingEmployee().catch(err => {
  console.error('❌ Error adding testing employee:', err);
  process.exit(1);
});
