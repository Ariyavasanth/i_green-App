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

function createDocument(collection, docId, data) {
  return new Promise((resolve, reject) => {
    const fields = {};
    for (const [k, v] of Object.entries(data)) {
      fields[k] = toFirestoreValue(v);
    }
    const body = JSON.stringify({ fields });

    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}?documentId=${encodeURIComponent(docId)}&key=${API_KEY}`,
      method: 'POST',
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
            reject(new Error(`Create Doc HTTP ${res.statusCode}: ${JSON.stringify(parsed)}`));
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

const targetHierarchy = {
  'Management': {
    designations: [
      { name: 'Company Director', level: 'Head' },
      { name: 'Manager', level: 'Manager' },
      { name: 'Assistant Manager', level: 'Manager' }
    ]
  },
  'Finance': {
    designations: [
      { name: 'Finance Head', level: 'Head' },
      { name: 'Sr. Accountant', level: 'Senior' },
      { name: 'Junior Accountant', level: 'Employee' },
      { name: 'Accounts Assistant', level: 'Employee' }
    ]
  },
  'Administration': {
    designations: [
      { name: 'Sr. Admin Executive', level: 'Senior' },
      { name: 'Admin Assistant', level: 'Employee' },
      { name: 'Back office - Executive Associate', level: 'Employee' },
      { name: 'Co-Ordinator', level: 'Lead' }
    ]
  },
  'Admin Support': {
    designations: [
      { name: 'Office Assistant', level: 'Employee' },
      { name: 'Driver', level: 'Employee' },
      { name: 'Cook', level: 'Employee' }
    ]
  },
  'Business Development': {
    designations: [
      { name: 'Business Development Executive', level: 'Employee' },
      { name: 'Sales Executive', level: 'Employee' },
      { name: 'Relationship Manager', level: 'Manager' }
    ]
  },
  'Projects': {
    designations: [
      { name: 'Project Lead', level: 'Lead' },
      { name: 'Sr. Project Coordinator', level: 'Senior' },
      { name: 'Project Assistant', level: 'Employee' },
      { name: 'Sr. Consultant', level: 'Senior' }
    ]
  },
  'Execution': {
    designations: [
      { name: 'Site Coordinator', level: 'Lead' },
      { name: 'Sr. Site Coordinator', level: 'Senior' },
      { name: 'Site Coordinator - Trainee', level: 'Trainee' },
      { name: 'Bore Path Specialist', level: 'Senior' },
      { name: 'Rig Operator', level: 'Employee' },
      { name: 'Tracker', level: 'Employee' }
    ]
  },
  'Production Unit': {
    designations: [
      { name: 'Factory Manager', level: 'Manager' },
      { name: 'Factory Coordinator', level: 'Lead' },
      { name: 'Technical Head', level: 'Head' },
      { name: 'Supervisor', level: 'Supervisor' },
      { name: 'CNC Programmer', level: 'Senior' },
      { name: 'VMC Programmer', level: 'Senior' },
      { name: 'CNC Operator', level: 'Employee' },
      { name: 'VMC Operator', level: 'Employee' },
      { name: 'Lathe Operator', level: 'Employee' },
      { name: 'Milling Operator', level: 'Employee' },
      { name: 'Milling and Lathe Operator', level: 'Employee' },
      { name: 'Operator', level: 'Employee' }
    ]
  },
  'Production Support': {
    designations: [
      { name: 'Store Incharge', level: 'Lead' },
      { name: 'Purchase Executive', level: 'Employee' },
      { name: 'CAD Designer', level: 'Employee' },
      { name: 'Automation Lead Executive', level: 'Lead' },
      { name: 'Fitter', level: 'Employee' },
      { name: 'Welder', level: 'Employee' },
      { name: 'Rigger', level: 'Employee' },
      { name: 'Grinder', level: 'Employee' }
    ]
  },
  'Labor': {
    designations: [
      { name: 'Sr. Labour', level: 'Senior' },
      { name: 'Trainee', level: 'Trainee' },
      { name: 'Helper', level: 'Employee' }
    ]
  }
};

// Map designations to department for employee updates
const desigToDeptMap = {};
for (const [dept, dInfo] of Object.entries(targetHierarchy)) {
  for (const desig of dInfo.designations) {
    desigToDeptMap[desig.name.toLowerCase()] = dept;
  }
}
// Additional roles
desigToDeptMap['vice president'] = 'Management';
desigToDeptMap['executive'] = 'Administration';

async function seed() {
  console.log('🚀 Starting Seeding of Departments and Designations...\n');

  // 1. Fetch current data
  const orgsRes = await get('organizations');
  const orgMap = {};
  for (const doc of orgsRes.documents || []) {
    const id = doc.name.split('/').pop();
    const f = parseFields(doc.fields);
    const name = (f.name || f.organization_name || '').trim();
    if (name) orgMap[name.toLowerCase()] = { id, name };
  }

  const orgs = [
    orgMap['igreen technologies'],
    orgMap['igreentec engineering india p ltd']
  ].filter(Boolean);

  console.log(`Found ${orgs.length} target organizations:`);
  orgs.forEach(o => console.log(` - [${o.id}] ${o.name}`));

  // 2. Clean dummy designations
  console.log('\n🧹 Cleaning dummy designations...');
  const desigsRes = await get('designations');
  const allDesigs = (desigsRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  const dummyNames = ['cvh', 'fhh', 'vice presidet'];
  for (const d of allDesigs) {
    const name = (d.designation_name || d.designationName || '').trim().toLowerCase();
    if (dummyNames.includes(name)) {
      await deleteDocument('designations', d.docId);
      console.log(`   🗑️ Deleted dummy designation: [${d.docId}] "${d.designation_name}"`);
    }
  }

  // 3. Process departments and designations for each org
  let nextDeptId = Date.now();
  let nextDesigId = Date.now() + 50000;

  for (const org of orgs) {
    console.log(`\n==================================================`);
    console.log(`🏢 Processing: ${org.name} (${org.id})`);
    console.log(`==================================================`);

    // Refresh depts & desigs
    const currentDeptsRes = await get('departments');
    const orgDepts = (currentDeptsRes.documents || []).map(d => ({
      docId: d.name.split('/').pop(),
      ...parseFields(d.fields)
    })).filter(d =>
      (d.organization_name || '').trim().toLowerCase() === org.name.toLowerCase() ||
      (d.organization_id || '') === org.id
    );

    const currentDesigsRes = await get('designations');
    const orgDesigs = (currentDesigsRes.documents || []).map(d => ({
      docId: d.name.split('/').pop(),
      ...parseFields(d.fields)
    })).filter(d =>
      (d.organization_name || '').trim().toLowerCase() === org.name.toLowerCase() ||
      (d.organization_id || '') === org.id
    );

    for (const [deptName, deptInfo] of Object.entries(targetHierarchy)) {
      let deptDoc = orgDepts.find(d =>
        (d.department_name || '').trim().toLowerCase() === deptName.toLowerCase()
      );

      if (deptDoc) {
        if (deptDoc.department_name !== deptName) {
          // Normalize casing (e.g. "finance" -> "Finance")
          await patchSpecificFields('departments', deptDoc.docId, {
            department_name: deptName,
            organization_name: org.name,
            organization_id: org.id
          });
          console.log(`   ✏️ Normalized department name: "${deptDoc.department_name}" -> "${deptName}"`);
          deptDoc.department_name = deptName;
        } else {
          console.log(`   ✅ Department exists: "${deptName}" [${deptDoc.docId}]`);
        }
      } else {
        // Create department
        nextDeptId++;
        const newDeptDocId = `dept_${nextDeptId}`;
        const newDeptData = {
          id: nextDeptId,
          department_name: deptName,
          organization_name: org.name,
          organization_id: org.id,
          department_head: '',
          reporting_hierarchy: 'None',
          work_location: 'Headquarters',
          business_unit_name: ''
        };
        await createDocument('departments', newDeptDocId, newDeptData);
        deptDoc = { docId: newDeptDocId, ...newDeptData };
        console.log(`   ➕ Created department: "${deptName}" [${newDeptDocId}]`);
      }

      // Check / Seed Designations under this Department
      const desigsInThisDept = orgDesigs.filter(d =>
        (d.department_name || '').trim().toLowerCase() === deptName.toLowerCase()
      );

      for (const desigItem of deptInfo.designations) {
        const existingDesig = desigsInThisDept.find(d =>
          (d.designation_name || '').trim().toLowerCase() === desigItem.name.toLowerCase()
        );

        if (existingDesig) {
          // Ensure casing and org are standard
          await patchSpecificFields('designations', existingDesig.docId, {
            designation_name: desigItem.name,
            department_name: deptName,
            organization_name: org.name,
            organization_id: org.id,
            organizationName: org.name,
            organizationId: org.id
          });
          console.log(`      ✓ Designation exists: "${desigItem.name}" [${existingDesig.docId}]`);
        } else {
          // Check if exists in old department (e.g. Office / Factory)
          const oldDesig = orgDesigs.find(d =>
            (d.designation_name || '').trim().toLowerCase() === desigItem.name.toLowerCase() &&
            (d.department_name || '').trim().toLowerCase() !== deptName.toLowerCase()
          );

          if (oldDesig) {
            // Remap to target department
            await patchSpecificFields('designations', oldDesig.docId, {
              designation_name: desigItem.name,
              department_name: deptName,
              organization_name: org.name,
              organization_id: org.id,
              organizationName: org.name,
              organizationId: org.id,
              hierarchy_level: desigItem.level
            });
            console.log(`      🔄 Remapped designation: "${desigItem.name}" from "${oldDesig.department_name}" to "${deptName}" [${oldDesig.docId}]`);
          } else {
            // Create new designation
            nextDesigId++;
            const newDesigDocId = `desig_${nextDesigId}`;
            const newDesigData = {
              id: nextDesigId,
              designation_name: desigItem.name,
              department_name: deptName,
              organization_name: org.name,
              organization_id: org.id,
              organizationName: org.name,
              organizationId: org.id,
              hierarchy_level: desigItem.level,
              description: ''
            };
            await createDocument('designations', newDesigDocId, newDesigData);
            console.log(`      ➕ Added designation: "${desigItem.name}" under "${deptName}" [${newDesigDocId}]`);
          }
        }
      }
    }
  }

  // 4. Safely Update Employee Profiles to their correct departments
  console.log(`\n==================================================`);
  console.log(`👥 Updating 26 Employee Profiles with Target Departments...`);
  console.log(`==================================================`);

  const empRes = await get('employees');
  const allEmployees = (empRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  let updatedEmpCount = 0;
  for (const emp of allEmployees) {
    const currentDesig = (emp.designation || emp.designation_name || '').trim().toLowerCase();
    const targetDept = desigToDeptMap[currentDesig];

    if (targetDept) {
      if ((emp.department || '').trim() !== targetDept) {
        await patchSpecificFields('employees', emp.docId, {
          department: targetDept,
          department_name: targetDept
        });
        console.log(`   👤 [${emp.docId}] "${emp.name || emp.employee_id}" (${emp.designation}): "${emp.department}" -> "${targetDept}"`);
        updatedEmpCount++;
      } else {
        console.log(`   ✓ [${emp.docId}] "${emp.name || emp.employee_id}" already in "${targetDept}"`);
      }
    } else {
      console.log(`   ⚠️ [${emp.docId}] "${emp.name || emp.employee_id}" has unknown designation: "${emp.designation}"`);
    }
  }
  console.log(`\n✅ Updated ${updatedEmpCount} employee departments!`);

  // 5. Clean up old empty departments in IGREEN TECHNOLOGIES
  console.log(`\n==================================================`);
  console.log(`🧹 Cleaning Up Obsolete Empty Departments in IGREEN TECHNOLOGIES...`);
  console.log(`==================================================`);
  const obsoleteDeptIds = [
    'dept_1792519266831', // Office
    'dept_factory',        // Factory
    'dept_1791795677684', // IT
    'dept_1792519105611', // Project
    'dept_1792519415159'  // Executiion
  ];

  for (const deptId of obsoleteDeptIds) {
    await deleteDocument('departments', deptId);
    console.log(`   🗑️ Deleted obsolete department: [${deptId}]`);
  }

  console.log(`\n🎉 SEEDING & MIGRATION COMPLETE!`);
}

seed().catch(console.error);
