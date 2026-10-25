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

function safeJsonList(str) {
  try {
    const parsed = JSON.parse(str);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

async function restore() {
  console.log('🔄 Fetching candidate responses and existing employees...');
  
  // 1. Fetch candidate responses for Deepak, Shajan, Gokul Raj
  const can18Doc = await get('candidate_responses/CAN-0018'); // Shajan B
  const can19Doc = await get('candidate_responses/CAN-0019'); // Deepak R
  const can21Doc = await get('candidate_responses/CAN-0021'); // Gokul Raj G

  const shajanCandData = JSON.parse(parseFields(can18Doc.fields).employee_data_json || '{}');
  const deepakCandData = JSON.parse(parseFields(can19Doc.fields).employee_data_json || '{}');
  const gokulCandData = JSON.parse(parseFields(can21Doc.fields).employee_data_json || '{}');

  console.log('✅ Found candidate responses:');
  console.log('  - Shajan image bytes:', (shajanCandData.profile_image_url || '').length);
  console.log('  - Deepak image bytes:', (deepakCandData.profile_image_url || '').length);
  console.log('  - Gokul Raj image bytes:', (gokulCandData.profile_image_url || '').length);

  // 2. Fetch current employees to swap
  const saravananDoc = await get('employees/EMP-0002');
  const ganeshDoc = await get('employees/EMP-0003');
  const kaliyarajDoc = await get('employees/EMP-0008');

  const saravananData = parseFields(saravananDoc.fields);
  const ganeshData = parseFields(ganeshDoc.fields);
  const kaliyarajData = parseFields(kaliyarajDoc.fields);

  // 3. Move Saravanan, Ganesh, Kaliyaraj to EMP-0012, EMP-0022, EMP-0027
  console.log('\n📦 Reassigning Excel dump employees to their new sequence positions:');
  const newSaravanan = {
    ...saravananData,
    id: 12,
    employee_id: 'EMP-0012'
  };
  await saveDocument('employees', 'EMP-0012', newSaravanan);
  console.log('  ✅ G S Saravanan -> EMP-0012 (id: 12)');

  const newGanesh = {
    ...ganeshData,
    id: 22,
    employee_id: 'EMP-0022'
  };
  await saveDocument('employees', 'EMP-0022', newGanesh);
  console.log('  ✅ Ganesh Chandra Das -> EMP-0022 (id: 22)');

  const newKaliyaraj = {
    ...kaliyarajData,
    id: 27,
    employee_id: 'EMP-0027'
  };
  await saveDocument('employees', 'EMP-0027', newKaliyaraj);
  console.log('  ✅ Sri Kaliyaraj B -> EMP-0027 (id: 27)');

  // 4. Restore Deepak R to EMP-0002
  console.log('\n👤 Restoring Deepak R at EMP-0002 with full profile and uploaded image...');
  const deepakDoc = {
    ...deepakCandData,
    id: 2,
    employee_id: 'EMP-0002',
    first_name: 'Deepak',
    last_name: 'R',
    user_name: 'DEEPAK',
    email_address: deepakCandData.email_address || 'rm@igreentec.in',
    phone_number: deepakCandData.phone_number || '+91 7505054321',
    personal_mobile: deepakCandData.phone_number || '+91 7505054321',
    status: 'Active',
    role: 'EMPLOYEE',
    user_type: 'EMPLOYEE',
    organization_name: 'IGREEN TECHNOLOGIES',
    organization_id: 'org_1790493894148',
    department: 'Office',
    work_location: 'Office',
    designation: 'Relationship Manager',
    reporting_manager_id: 'EMP-0001',
    reporting_manager: 'Super Admin',
    reporting_manager_title: 'Super Administrator',
    education_items: safeJsonList(deepakCandData.education_list_json),
    experience_items: safeJsonList(deepakCandData.experience_list_json),
    document_items: safeJsonList(deepakCandData.document_list_json),
    joining_date: deepakCandData.joining_date || '2026-10-20'
  };
  await saveDocument('employees', 'EMP-0002', deepakDoc);
  console.log('  ✅ Saved Deepak R to EMP-0002');

  // 5. Restore Shajan B to EMP-0003
  console.log('\n👤 Restoring Shajan B at EMP-0003 with full profile and uploaded image...');
  const shajanDoc = {
    ...shajanCandData,
    id: 3,
    employee_id: 'EMP-0003',
    first_name: 'Shajan',
    last_name: 'B',
    user_name: 'SHAJAN',
    email_address: shajanCandData.email_address || 'shajan.igreen@gmail.com',
    phone_number: shajanCandData.phone_number || '+91 8148262183',
    personal_mobile: shajanCandData.phone_number || '+91 8148262183',
    status: 'Active',
    role: 'EMPLOYEE',
    user_type: 'EMPLOYEE',
    organization_name: 'IGREEN TECHNOLOGIES',
    organization_id: 'org_1790493894148',
    department: 'Office',
    work_location: 'Office',
    designation: 'Accounts Assistant',
    reporting_manager_id: 'EMP-0001',
    reporting_manager: 'Super Admin',
    reporting_manager_title: 'Super Administrator',
    education_items: safeJsonList(shajanCandData.education_list_json),
    experience_items: safeJsonList(shajanCandData.experience_list_json),
    document_items: safeJsonList(shajanCandData.document_list_json),
    joining_date: shajanCandData.joining_date || '2022-01-01'
  };
  await saveDocument('employees', 'EMP-0003', shajanDoc);
  console.log('  ✅ Saved Shajan B to EMP-0003');

  // 6. Restore Gokul Raj G to EMP-0008
  console.log('\n👤 Restoring Gokul Raj G at EMP-0008 with full profile and uploaded image...');
  const gokulDoc = {
    ...gokulCandData,
    id: 8,
    employee_id: 'EMP-0008',
    first_name: 'Gokul',
    last_name: 'Raj G',
    user_name: 'GOKUL',
    email_address: gokulCandData.email_address || 'gpgokulraj@gmail.com',
    phone_number: gokulCandData.phone_number || '+91 9003718640',
    personal_mobile: gokulCandData.phone_number || '+91 9003718640',
    status: 'Active',
    role: 'EMPLOYEE',
    user_type: 'EMPLOYEE',
    organization_name: 'IGREEN TECHNOLOGIES',
    organization_id: 'org_1790493894148',
    department: 'Office',
    work_location: 'Office',
    designation: 'Supervisor',
    reporting_manager_id: 'EMP-0001',
    reporting_manager: 'Super Admin',
    reporting_manager_title: 'Super Administrator',
    education_items: safeJsonList(gokulCandData.education_list_json),
    experience_items: safeJsonList(gokulCandData.experience_list_json),
    document_items: safeJsonList(gokulCandData.document_list_json),
    joining_date: gokulCandData.joining_date || '2026-10-21'
  };
  await saveDocument('employees', 'EMP-0008', gokulDoc);
  console.log('  ✅ Saved Gokul Raj G to EMP-0008');

  // 7. Verify Attendance Records & create alias records for EMP-0012, EMP-0022, EMP-0027
  console.log('\n📅 Ensuring attendance records are linked across both primary and sequence keys...');
  const att = await get('attendance_records');
  const docs = att.documents || [];
  
  for (const d of docs) {
    const f = parseFields(d.fields);
    const docKey = d.name.split('/').pop();

    // Deepak (id: 2, code: EMP-0002) -> mirror to EMP-0012
    if (f.employee_id === 2 || f.employee_code === 'EMP-0002') {
      const aliasKey = docKey.replace('2_', '12_').replace('EMP-0002_', 'EMP-0012_');
      if (aliasKey !== docKey) {
        await saveDocument('attendance_records', aliasKey, {
          ...f,
          employee_id: 12,
          employee_code: 'EMP-0012'
        });
      }
    }

    // Shajan (id: 3, code: EMP-0003) -> mirror to EMP-0022
    if (f.employee_id === 3 || f.employee_code === 'EMP-0003') {
      const aliasKey = docKey.replace('3_', '22_').replace('EMP-0003_', 'EMP-0022_');
      if (aliasKey !== docKey) {
        await saveDocument('attendance_records', aliasKey, {
          ...f,
          employee_id: 22,
          employee_code: 'EMP-0022'
        });
      }
    }

    // Gokul Raj (id: 8, code: EMP-0008) -> mirror to EMP-0027
    if (f.employee_id === 8 || f.employee_code === 'EMP-0008') {
      const aliasKey = docKey.replace('8_', '27_').replace('EMP-0008_', 'EMP-0027_');
      if (aliasKey !== docKey) {
        await saveDocument('attendance_records', aliasKey, {
          ...f,
          employee_id: 27,
          employee_code: 'EMP-0027'
        });
      }
    }
  }

  console.log('✅ Attendance mirroring completed successfully!');
  console.log('\n🎉 Finished restoring Deepak, Shajan, and Gokul Raj!');
}

restore().catch(err => {
  console.error('❌ Error restoring employees:', err);
  process.exit(1);
});
