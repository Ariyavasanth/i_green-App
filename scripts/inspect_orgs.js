const https = require('https');

const API_KEY = 'AIzaSyDWFHhjAb_uH-5XMnkF__N29WSkYc71-3M';

function get(path) {
  return new Promise((resolve, reject) => {
    const sep = path.includes('?') ? '&' : '?';
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/i-green-tech/databases/(default)/documents/${path}${sep}key=${API_KEY}&pageSize=100`,
      method: 'GET',
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch(e) {
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
    }
    else if (v.mapValue !== undefined) res[k] = parseFields(v.mapValue.fields);
    else res[k] = v;
  }
  return res;
}

async function run() {
  console.log('=== ORGANIZATIONS ===');
  const orgs = await get('organizations');
  if (orgs.documents) {
    orgs.documents.forEach(d => {
      const f = parseFields(d.fields);
      console.log('ID:', d.name.split('/').pop(), '| Name:', f.name || f.organization_name);
    });
  }
}

module.exports = { get, parseFields };

if (require.main === module) {
  run();
}


