const https = require('https');

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

function get(path) {
  return new Promise((resolve, reject) => {
    const sep = path.includes('?') ? '&' : '?';
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}${sep}key=${API_KEY}`,
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

const updates = [
  { docId: 'IGT-0013', name: 'Sankar Raja', pan: 'LOEPS5698B' },
  { docId: 'IGT-0044', name: 'Sivan Arumugam', pan: 'HPCPS8371J' },
  { docId: 'IGT-0120', name: 'Balaji P', pan: 'BNEPP6616B' },
  { docId: 'IGT-0133', name: 'Sivarajan Shanmugam', pan: 'ENJPS6289H' },
  { docId: 'IGT-0158', name: 'E Manikandan', pan: 'DBDPM1748C' },
  { docId: 'IGT-0159', name: 'Singara Lakshmanan Palanisamy', pan: 'GYLPP3057B' },
  { docId: 'IGT-0068', name: 'Mazhar Shekh', pan: 'MDEPS0986A' },
  { docId: 'IGT-0183', name: 'Paramasivam', pan: 'FBSPP9301K' },
  { docId: 'IGT-0205', name: 'Shajan B', pan: 'FHEPB9266F' }
];

async function main() {
  console.log(`Starting update for ${updates.length} employee PAN records...`);

  for (const u of updates) {
    console.log(`Updating ${u.docId} (${u.name}) -> pan_number: ${u.pan}`);
    await patchSpecificFields('employees', u.docId, {
      pan_number: u.pan
    });
    console.log(` Successfully updated ${u.docId}`);
  }

  console.log('\n--- VERIFYING UPDATED RECORDS ---');
  for (const u of updates) {
    const doc = await get(`employees/${u.docId}`);
    const parsed = parseFields(doc.fields);
    console.log(`${u.docId} (${u.name}): pan_number in DB = "${parsed.pan_number}" (Matches target: ${parsed.pan_number === u.pan})`);
  }
}

main().catch(console.error);

