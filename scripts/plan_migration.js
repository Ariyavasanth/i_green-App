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

const targetHierarchy = {
  'Management': {
    head: 'Management',
    designations: [
      { name: 'Company Director', level: 'Head' },
      { name: 'Manager', level: 'Manager' },
      { name: 'Assistant Manager', level: 'Manager' }
    ]
  },
  'Finance': {
    head: 'Finance',
    designations: [
      { name: 'Finance Head', level: 'Head' },
      { name: 'Sr. Accountant', level: 'Senior' },
      { name: 'Junior Accountant', level: 'Employee' },
      { name: 'Accounts Assistant', level: 'Employee' }
    ]
  },
  'Administration': {
    head: 'Administration',
    designations: [
      { name: 'Sr. Admin Executive', level: 'Senior' },
      { name: 'Admin Assistant', level: 'Employee' },
      { name: 'Back office - Executive Associate', level: 'Employee' },
      { name: 'Co-Ordinator', level: 'Lead' }
    ]
  },
  'Admin Support': {
    head: 'Administration',
    designations: [
      { name: 'Office Assistant', level: 'Employee' },
      { name: 'Driver', level: 'Employee' },
      { name: 'Cook', level: 'Employee' }
    ]
  },
  'Business Development': {
    head: 'Business Development',
    designations: [
      { name: 'Business Development Executive', level: 'Employee' },
      { name: 'Sales Executive', level: 'Employee' },
      { name: 'Relationship Manager', level: 'Manager' }
    ]
  },
  'Projects': {
    head: 'Projects',
    designations: [
      { name: 'Project Lead', level: 'Lead' },
      { name: 'Sr. Project Coordinator', level: 'Senior' },
      { name: 'Project Assistant', level: 'Employee' },
      { name: 'Sr. Consultant', level: 'Senior' }
    ]
  },
  'Execution': {
    head: 'Execution',
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
    head: 'Production',
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
    head: 'Production',
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
    head: 'Production',
    designations: [
      { name: 'Sr. Labour', level: 'Senior' },
      { name: 'Trainee', level: 'Trainee' },
      { name: 'Helper', level: 'Employee' }
    ]
  }
};

async function planMigration() {
  const orgsRes = await get('organizations');
  const orgMap = {};
  for (const doc of orgsRes.documents || []) {
    const id = doc.name.split('/').pop();
    const f = parseFields(doc.fields);
    const name = f.name || f.organization_name;
    if (name) orgMap[name.trim().toLowerCase()] = { id, name: name.trim() };
  }

  const deptsRes = await get('departments');
  const allDepts = (deptsRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  const desigsRes = await get('designations');
  const allDesigs = (desigsRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  const empRes = await get('employees');
  const allEmployees = (empRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  console.log('=== PLAN ANALYSIS ===');
  console.log(`Orgs found: ${Object.keys(orgMap).length}`);
  console.log(`Depts found: ${allDepts.length}`);
  console.log(`Designations found: ${allDesigs.length}`);
  console.log(`Employees found: ${allEmployees.length}`);

  const orgsToProcess = [
    orgMap['igreen technologies'],
    orgMap['igreentec engineering india p ltd']
  ];

  for (const org of orgsToProcess) {
    console.log(`\n========================================`);
    console.log(`🏢 Organization: ${org.name} (${org.id})`);
    console.log(`========================================`);

    const orgDepts = allDepts.filter(d => 
      (d.organization_name || '').trim().toLowerCase() === org.name.toLowerCase() ||
      (d.organization_id || '') === org.id
    );

    const orgDesigs = allDesigs.filter(d =>
      (d.organization_name || '').trim().toLowerCase() === org.name.toLowerCase() ||
      (d.organization_id || '') === org.id
    );

    for (const [deptName, deptInfo] of Object.entries(targetHierarchy)) {
      // Find matching existing department (case-insensitive)
      const existingDept = orgDepts.find(d => 
        (d.department_name || '').trim().toLowerCase() === deptName.toLowerCase()
      );

      const deptStatus = existingDept ? `EXISTS [${existingDept.docId}] (name: "${existingDept.department_name}")` : `WILL CREATE`;
      console.log(`\n📁 Department: ${deptName} -> ${deptStatus}`);

      const desigsInDept = orgDesigs.filter(d =>
        (d.department_name || '').trim().toLowerCase() === deptName.toLowerCase() ||
        (existingDept && (d.department_name || '').trim().toLowerCase() === (existingDept.department_name || '').trim().toLowerCase())
      );

      for (const desig of deptInfo.designations) {
        const existingDesig = desigsInDept.find(d =>
          (d.designation_name || '').trim().toLowerCase() === desig.name.toLowerCase()
        );
        if (existingDesig) {
          console.log(`   - "${desig.name}": ALREADY EXISTS [${existingDesig.docId}] (will keep)`);
        } else {
          console.log(`   + "${desig.name}": WILL ADD (Level: ${desig.level})`);
        }
      }
    }
  }

  // Check dummy designations to delete
  const dummyNames = ['cvh', 'fhh', 'vice presidet'];
  const dummies = allDesigs.filter(d => 
    dummyNames.includes((d.designation_name || '').trim().toLowerCase())
  );
  console.log(`\n🗑️ Dummy designations to delete: ${dummies.length}`);
  dummies.forEach(d => console.log(`   - [${d.docId}] "${d.designation_name}" in dept "${d.department_name}" org "${d.organization_name}"`));
}

planMigration().catch(console.error);
