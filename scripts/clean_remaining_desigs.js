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
            reject(new Error(`Patch Doc HTTP ${res.statusCode}: ${JSON.stringify(parsed)}`));
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
          else reject(new Error(`Delete Doc HTTP ${res.statusCode}: ${respData}`));
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function cleanRemaining() {
  const desigsRes = await get('designations');
  const allDesigs = (desigsRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  // Handle leftover designations in obsolete departments
  for (const d of allDesigs) {
    const dept = (d.department_name || d.departmentName || '').trim();
    const desigName = (d.designation_name || d.designationName || '').trim();
    const org = (d.organization_name || d.organizationName || '').trim();

    if (org === 'IGREEN TECHNOLOGIES') {
      if (dept === 'Office') {
        if (desigName === 'Vice President') {
          await patchSpecificFields('designations', d.docId, {
            department_name: 'Management',
            hierarchy_level: 'Head'
          });
          console.log(`Updated Vice President to Management`);
        } else if (desigName === 'Executive') {
          await patchSpecificFields('designations', d.docId, {
            department_name: 'Administration',
            hierarchy_level: 'Employee'
          });
          console.log(`Updated Executive to Administration`);
        } else {
          // It's a duplicate of one that already exists in Finance / Execution / Business Development
          await deleteDocument('designations', d.docId);
          console.log(`Deleted duplicate Office designation: ${desigName} [${d.docId}]`);
        }
      } else if (['execution', 'Solar Energy & Automation', 'IT', 'Project', 'Executiion'].includes(dept)) {
        await deleteDocument('designations', d.docId);
        console.log(`Deleted obsolete designation in ${dept}: ${desigName} [${d.docId}]`);
      }
    }
  }

  console.log('Done cleaning leftover designations!');
}

cleanRemaining().catch(console.error);
