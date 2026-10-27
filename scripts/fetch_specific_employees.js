const https = require('https');

const API_KEY = 'AIzaSyDWFHhjAb_uH-5XMnkF__N29WSkYc71-3M';
const PROJECT_ID = 'i-green-tech';

function get(path) {
  return new Promise((resolve, reject) => {
    const sep = path.includes('?') ? '&' : '?';
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}${sep}key=${API_KEY}&pageSize=500`,
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
    else if (v.mapValue !== undefined) res[k] = parseFields(v.mapValue.fields);
    else res[k] = v;
  }
  return res;
}

async function fetchEmployees() {
  const targetIds = [
    'IGT-0001', 'IGT-0109', 'IGT-0120', 'IGT-0133', 'IGT-0158',
    'IGT-0159', 'IGT-0172', 'IGT-0174', 'IGT-0175', 'IGT-0183', 'IGT-0192'
  ];

  const empRes = await get('employees');
  const allEmps = (empRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  const matched = allEmps.filter(e => {
    const id = (e.employee_id || e.employeeId || e.docId || '').trim().replace(/\s+/g, '');
    return targetIds.some(t => t.replace(/\s+/g, '') === id || e.docId === t);
  });

  console.log(JSON.stringify(matched, null, 2));
}

fetchEmployees().catch(console.error);
