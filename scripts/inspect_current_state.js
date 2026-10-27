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

async function inspect() {
  const orgsRes = await get('organizations');
  console.log('--- ORGANIZATIONS ---');
  for (const doc of orgsRes.documents || []) {
    const id = doc.name.split('/').pop();
    const f = parseFields(doc.fields);
    console.log(`[${id}] name: "${f.name || f.organization_name}" code: "${f.code || f.organization_code}"`);
  }

  const deptRes = await get('departments');
  console.log('\n--- DEPARTMENTS ---');
  for (const doc of deptRes.documents || []) {
    const id = doc.name.split('/').pop();
    const f = parseFields(doc.fields);
    console.log(`[${id}] name: "${f.department_name}" org: "${f.organization_name}" orgId: "${f.organization_id}"`);
  }

  const desigRes = await get('designations');
  console.log(`\n--- DESIGNATIONS (Total: ${(desigRes.documents || []).length}) ---`);
  const byDept = {};
  for (const doc of desigRes.documents || []) {
    const id = doc.name.split('/').pop();
    const f = parseFields(doc.fields);
    const key = `${f.organization_name || 'NO_ORG'} -> ${f.department_name || 'NO_DEPT'}`;
    if (!byDept[key]) byDept[key] = [];
    byDept[key].push(f.designation_name);
  }
  for (const [key, desigs] of Object.entries(byDept)) {
    console.log(`${key} (${desigs.length}): ${desigs.join(', ')}`);
  }
}

inspect().catch(console.error);
