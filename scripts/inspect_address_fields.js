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

async function inspectEmployeeAddressFields() {
  const empRes = await get('employees');
  const emps = (empRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  const sample = emps.find(e => e.docId === 'IGT-0001') || emps[0];
  console.log('Sample keys in employee document:');
  const addressKeys = Object.keys(sample).filter(k => 
    k.includes('address') || k.includes('city') || k.includes('state') || k.includes('pin') || k.includes('country') || k.includes('postal') || k.includes('location')
  );
  console.log(addressKeys);

  console.log('\nAddress fields on IGT-0001:');
  addressKeys.forEach(k => console.log(`  ${k}: "${sample[k]}"`));
}

inspectEmployeeAddressFields().catch(console.error);
