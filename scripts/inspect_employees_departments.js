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
    else if (v.mapValue !== undefined) res[k] = parseFields(v.mapValue.fields);
    else res[k] = v;
  }
  return res;
}

async function inspectEmployees() {
  const empRes = await get('employees');
  const docs = empRes.documents || [];
  console.log(`Total employees: ${docs.length}`);
  const list = docs.map(d => {
    const id = d.name.split('/').pop();
    const f = parseFields(d.fields);
    return {
      docId: id,
      empId: f.employee_id || f.employeeId || id,
      name: f.name || f.full_name || '',
      org: f.organization_name || f.organizationName || '',
      dept: f.department || f.department_name || '',
      desig: f.designation || f.designation_name || ''
    };
  });

  list.sort((a,b) => (a.empId || '').localeCompare(b.empId || ''));
  console.table(list);
}

inspectEmployees().catch(console.error);
