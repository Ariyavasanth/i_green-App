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

async function run() {
  console.log('🚀 [Database Cleanup] Normalizing Organizations & Designations...\n');

  // 1. Fetch Master Organizations
  const orgsRes = await get('organizations');
  const orgDocs = orgsRes.documents || [];
  const orgMap = {}; // name.toLowerCase() -> { id, name }
  for (const od of orgDocs) {
    const f = parseFields(od.fields);
    const id = od.name.split('/').pop();
    const name = f.name || f.organization_name || '';
    if (name) {
      orgMap[name.toLowerCase()] = { id, name };
    }
  }
  console.log(`1️⃣ Master Organizations (${Object.keys(orgMap).length}):`);
  for (const o of Object.values(orgMap)) {
    console.log(`   - [${o.id}] ${o.name}`);
  }

  // 2. Fetch and clean departments
  console.log('\n2️⃣ Fetching departments...');
  const deptRes = await get('departments');
  const deptDocs = deptRes.documents || [];
  console.log(`   Found ${deptDocs.length} departments.`);

  const obsoleteDeptIds = ['dept_1788224055143', 'dept_1788425192190'];
  for (const badId of obsoleteDeptIds) {
    const exists = deptDocs.some(d => d.name.endsWith(badId));
    if (exists) {
      await deleteDocument('departments', badId);
      console.log(`   🗑️ Deleted obsolete department: ${badId}`);
    }
  }

  // Build department -> organization map from the remaining valid departments
  const deptToOrg = {};
  for (const d of deptDocs) {
    const docId = d.name.split('/').pop();
    if (obsoleteDeptIds.includes(docId)) continue;
    const f = parseFields(d.fields);
    const dName = (f.department_name || f.departmentName || '').trim();
    let oName = (f.organization_name || f.organizationName || '').trim();
    let oId = (f.organization_id || f.organizationId || '').trim();

    // Normalize organization name
    if (oName.toLowerCase().includes('engineering') || oName.toLowerCase().includes('igreentec')) {
      oName = 'IGREENTEC ENGINEERING INDIA P LTD';
      oId = orgMap['igreentec engineering india p ltd']?.id || 'org_1788223961608';
    } else {
      oName = 'IGREEN TECHNOLOGIES';
      oId = orgMap['igreen technologies']?.id || 'org_1788425141018';
    }

    if (dName) {
      deptToOrg[dName.toLowerCase()] = { orgName: oName, orgId: oId };
    }
  }

  console.log(`\n   ✅ Active legitimate departments: ${Object.keys(deptToOrg).length}`);

  // 3. Fetch and normalize designations
  console.log('\n3️⃣ Normalizing 101 designations in Firestore...');
  const desigRes = await get('designations');
  const desigDocs = desigRes.documents || [];
  console.log(`   Found ${desigDocs.length} designations.`);

  let patchedCount = 0;
  for (const dd of desigDocs) {
    const docId = dd.name.split('/').pop();
    const f = parseFields(dd.fields);
    const desigName = (f.designation_name || f.designationName || '').trim();
    const deptName = (f.department_name || f.departmentName || '').trim();
    let currentOrg = (f.organization_name || f.organizationName || '').trim();

    // Determine correct organization
    let targetOrg = '';
    let targetOrgId = '';

    const deptMatch = deptToOrg[deptName.toLowerCase()];
    if (deptMatch) {
      targetOrg = deptMatch.orgName;
      targetOrgId = deptMatch.orgId;
    } else if (currentOrg.toLowerCase().includes('engineering') || currentOrg.toLowerCase().includes('igreentec')) {
      targetOrg = 'IGREENTEC ENGINEERING INDIA P LTD';
      targetOrgId = orgMap['igreentec engineering india p ltd']?.id || 'org_1788223961608';
    } else {
      targetOrg = 'IGREEN TECHNOLOGIES';
      targetOrgId = orgMap['igreen technologies']?.id || 'org_1788425141018';
    }

    if (currentOrg !== targetOrg || !f.organization_id) {
      await patchSpecificFields('designations', docId, {
        organization_name: targetOrg,
        organizationName: targetOrg,
        organization_id: targetOrgId,
        organizationId: targetOrgId
      });
      patchedCount++;
    }
  }

  console.log(`   ✅ Successfully normalized ${patchedCount} designations with correct organization names!`);

  // 4. Final verification
  console.log('\n4️⃣ Final Verification...');
  const finalDepts = await get('departments');
  console.log(`   - Remaining departments count: ${(finalDepts.documents || []).length}`);
  const finalDesigs = await get('designations');
  const finalDesigDocs = finalDesigs.documents || [];
  const orgCounts = {};
  for (const d of finalDesigDocs) {
    const f = parseFields(d.fields);
    const org = f.organization_name || 'NONE';
    orgCounts[org] = (orgCounts[org] || 0) + 1;
  }
  console.log('   - Designations breakdown by Organization:');
  console.table(orgCounts);

  console.log('\n🎉 Database cleanup complete!');
}

run().catch(console.error);
