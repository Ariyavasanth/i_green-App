const https = require('https');
const fs = require('fs');

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

function saveDocument(collection, docId, data) {
  return new Promise((resolve, reject) => {
    const fields = {};
    for (const [k, v] of Object.entries(data)) {
      fields[k] = toFirestoreValue(v);
    }
    const body = JSON.stringify({ fields });

    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${encodeURIComponent(docId)}?key=${API_KEY}`,
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
        } catch(e) {
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
          // If 404, consider already deleted
          if (res.statusCode === 404) resolve(true);
          else reject(new Error(`HTTP ${res.statusCode}: ${respData}`));
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

// Convert Excel date serial number to YYYY-MM-DD
function excelDateToISO(serialStr) {
  if (!serialStr) return '';
  const num = parseInt(serialStr, 10);
  if (isNaN(num)) return serialStr;
  // Excel base date: Dec 30 1899
  const base = new Date(1899, 11, 30);
  const target = new Date(base.getTime() + num * 86400000);
  const yyyy = target.getFullYear();
  const mm = String(target.getMonth() + 1).padStart(2, '0');
  const dd = String(target.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function excelDateToDisplay(serialStr) {
  if (!serialStr) return '';
  const num = parseInt(serialStr, 10);
  if (isNaN(num)) return serialStr;
  const base = new Date(1899, 11, 30);
  const target = new Date(base.getTime() + num * 86400000);
  const yyyy = target.getFullYear();
  const mm = String(target.getMonth() + 1).padStart(2, '0');
  const dd = String(target.getDate()).padStart(2, '0');
  return `${dd}-${mm}-${yyyy}`;
}

function splitName(fullName) {
  const clean = fullName.trim();
  const parts = clean.split(/\s+/);
  if (parts.length === 1) {
    return { firstName: parts[0], lastName: '' };
  }
  // Check if first part is initials like "G S" or "S" or "K"
  if (parts.length === 3 && parts[0].length <= 2 && parts[1].length <= 2) {
    return { firstName: `${parts[0]} ${parts[1]}`, lastName: parts[2] };
  }
  if (parts[0].length === 1) {
    return { firstName: parts[0], lastName: parts.slice(1).join(' ') };
  }
  if (parts[parts.length - 1].length === 1) {
    return { firstName: parts.slice(0, -1).join(' '), lastName: parts[parts.length - 1] };
  }
  return { firstName: parts[0], lastName: parts.slice(1).join(' ') };
}

async function main() {
  const rows = JSON.parse(fs.readFileSync('excel_dump.json', 'utf8'));
  const header = rows[0];
  console.log('Loaded header:', header);

  // Old test documents to clean up
  const oldTestDocIds = [
    'EMP-0002',
    'EMP-0003',
    'EMP-0004',
    'EMP-0005',
    'EMP-0006',
    'EMP-0007',
    'EMP-0008',
    'EMP-1002',
    'EMP-1003',
    'EMP-1004'
  ];

  console.log('Cleaning up obsolete test documents...');
  for (const docId of oldTestDocIds) {
    try {
      await deleteDocument('employees', docId);
      console.log(`🗑️ Deleted obsolete document: ${docId}`);
    } catch(e) {
      console.warn(`Could not delete ${docId}:`, e.message);
    }
  }

  // Ensure missing designations are in designations collection
  const newDesignations = [
    { name: 'Company Director', dept: 'Office', level: 'Head' },
    { name: 'Vice President', dept: 'Office', level: 'Head' },
    { name: 'Driver', dept: 'Office', level: 'Employee' },
    { name: 'Executive', dept: 'Office', level: 'Employee' },
    { name: 'CNC Programmer', dept: 'Factory', level: 'Employee' },
    { name: 'CNC Operator', dept: 'Factory', level: 'Employee' },
    { name: 'Lathe Operator', dept: 'Factory', level: 'Employee' },
    { name: 'Fitter', dept: 'Factory', level: 'Employee' },
    { name: 'Welder', dept: 'Factory', level: 'Employee' },
    { name: 'VMC Operator', dept: 'Factory', level: 'Employee' },
    { name: 'Helper', dept: 'Factory', level: 'Employee' },
    { name: 'Supervisor', dept: 'Office', level: 'Supervisor' },
  ];

  console.log('\nEnsuring designations exist in Firestore...');
  for (const d of newDesignations) {
    const desigDocId = `desig_${d.name.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;
    const desigData = {
      id: Date.now() + Math.floor(Math.random() * 1000),
      designation_name: d.name,
      department_name: d.dept,
      hierarchy_level: d.level,
      organization_name: 'IGREEN TECHNOLOGIES',
      organization_id: 'org_1790493894148',
      description: ''
    };
    try {
      await saveDocument('designations', desigDocId, desigData);
      console.log(`✅ Designation ready: ${d.name}`);
    } catch(e) {
      console.error(`Failed to save designation ${d.name}:`, e.message);
    }
  }

  // Also ensure Factory department exists
  try {
    await saveDocument('departments', 'dept_factory', {
      id: 1792867000001,
      department_name: 'Factory',
      organization_name: 'IGREEN TECHNOLOGIES',
      organization_id: 'org_1790493894148',
      department_head: 'GS Saravanan',
      work_location: 'Factory',
      reporting_hierarchy: 'Manager',
      business_unit_name: ''
    });
    console.log('✅ Department ready: Factory');
  } catch(e) {
    console.error('Failed to create Factory department:', e.message);
  }

  console.log('\nSeeding 26 production employees...');
  const seededEmployees = [];

  for (let i = 1; i < rows.length; i++) {
    const r = rows[i];
    if (!r || r.length < 4 || !r[3]) continue;

    const sNo = parseInt(r[0], 10);
    const location = (r[1] || 'Office').trim();
    const company = (r[2] || 'Igreen Technologies').trim();
    const rawEmpId = (r[3] || '').trim();
    const fullName = (r[4] || '').trim();
    const bloodGroup = (r[5] || '').trim();
    const uanNumber = (r[6] || '').trim() === 'NOT AVAILABLE' ? '' : (r[6] || '').trim();
    const position = (r[7] || '').trim();
    const rawDob = (r[8] || '').trim();
    const age = parseInt(r[9] || '0', 10);
    const panNumber = (r[10] || '').trim();
    const rawAadhaar = (r[11] || '').trim();
    const aadhaarClean = rawAadhaar.replace(/\s+/g, '');
    const drivingLicense = (r[12] || '').trim();
    const passportNo = (r[13] || '').trim();
    const rawPhone = (r[14] || '').trim();
    const emgName = (r[15] || '').trim();
    const emgPhone = (r[16] || '').trim().replace(/\s+/g, '');
    const email = (r[17] || '').trim();
    const rawUserType = (r[18] || 'EMPLOYEE').trim().toUpperCase();
    const userType = rawUserType === 'SUPER ADMIN' ? 'SUPER ADMIN' : (rawUserType === 'ADMIN' ? 'ADMIN' : 'EMPLOYEE');
    const presentAddr = (r[19] || '').trim();
    const permAddr = (r[20] || '').trim();

    const { firstName, lastName } = splitName(fullName);
    const dobIso = excelDateToISO(rawDob);
    const dobDisplay = excelDateToDisplay(rawDob);

    // Numeric ID: Extract numeric part from Emp ID (e.g. "IGT - 0001" -> 1, "IGT-217" -> 217)
    const digits = rawEmpId.replace(/\D/g, '');
    const integerId = parseInt(digits, 10) || sNo;

    // Document ID: Use normalized Emp ID without spaces (e.g. "IGT-0001" or "IGT-217")
    const docId = rawEmpId.replace(/\s+/g, '');

    // Default permissions based on user type
    let accessPermissions = [
      'My Asset',
      'Attendance',
      'On-Duty',
      'Time Clocking',
      'My Tasks',
      'My Payslips',
      'Loan'
    ];
    if (userType === 'SUPER ADMIN' || userType === 'ADMIN') {
      accessPermissions = [
        'HRMS',
        'Organization Structure',
        'Employee Management',
        'Responses',
        'Attendance Management',
        'Attendance Settings',
        'On-Duty Management',
        'Tasks & Clocking Management',
        'Site Visit Attendance Management',
        'Leave Management',
        'Permission Management',
        'Salary Settings',
        'Asset Settings',
        'Asset Management',
        'Loan Management',
        'Exit Management',
        'Incentive Management',
        'Payroll',
        'Payroll Settings',
        'My Asset',
        'Attendance',
        'On-Duty',
        'Time Clocking',
        'My Tasks',
        'My Payslips',
        'Loan'
      ];
    }

    const empData = {
      id: integerId,
      employee_id: rawEmpId, // Exact string from spreadsheet for UI display
      first_name: firstName,
      last_name: lastName,
      user_name: firstName.toUpperCase().replace(/[^A-Z0-9]/g, ''),
      gender: ['S Anitha', 'Kalyani', 'Sudha', 'Lakshmi', 'Nithiya', 'Vasanthi', 'Fatima Kumari', 'MalarvIzhi', 'Vijayalakshmi', 'Chinta', 'Aruna', 'Baby', 'Anupriya'].includes(fullName) ? 'Female' : 'Male',
      dob: dobIso,
      original_dob: dobDisplay,
      blood_group: bloodGroup,
      aadhaar_number: aadhaarClean,
      pan_number: panNumber,
      driving_license_number: drivingLicense,
      passport_number: passportNo,
      phone_number: rawPhone,
      personal_mobile: rawPhone,
      email_address: email,
      joining_date: '2022-01-01',
      organization_id: 'org_1790493894148',
      organization_name: 'IGREEN TECHNOLOGIES',
      business_unit: company,
      department: location,
      work_location: location,
      designation: position,
      user_type: userType,
      role: userType,
      status: 'Active',
      employment_type: 'Full Time',
      work_schedule_type: 'Fixed Schedule',
      in_time: '10:00 AM',
      out_time: '07:00 PM',
      required_working_hours: 9.0,
      leave_type: 'As Needed',
      leave_allocation_frequency: 'Monthly',
      allowed_leaves: 1.0,
      monthly_leave_allowance: 3.0,
      monthly_permission_limit_hours: 3.0,
      daily_permission_limit_hours: 1.0,
      requires_leave_approval: 1,
      reporting_manager: integerId === 1 ? '' : 'G S Saravanan',
      reporting_manager_id: integerId === 1 ? '' : 'IGT-0001',
      reporting_manager_title: 'Company Director',
      emergency_name: emgName,
      emergency_mobile: emgPhone,
      temporary_password: '123456',
      access_permissions: JSON.stringify(accessPermissions),
      present_address: presentAddr,
      present_country: 'India',
      permanent_address: permAddr,
      permanent_country: 'India',
      same_as_permanent: (presentAddr && permAddr && presentAddr.trim().toLowerCase() === permAddr.trim().toLowerCase()) ? 1 : 0,
      education_items: [],
      experience_items: [],
      document_items: [],
      education_list_json: '[]',
      experience_list_json: '[]',
      document_list_json: '[]',
      is_static_employee: 0,
      is_dynamic_employee: 0,
      site_latitude: 0.0,
      site_longitude: 0.0,
      site_allowed_radius_meters: 15,
      site_require_gps_verification: 1
    };

    try {
      await saveDocument('employees', docId, empData);
      console.log(`✅ [${i}/26] Seeded ${docId} (${rawEmpId}): ${fullName} - ${position}`);
      seededEmployees.push(docId);
    } catch(e) {
      console.error(`❌ Failed to seed ${docId}:`, e.message);
    }
  }

  console.log(`\n🎉 Successfully seeded ${seededEmployees.length} production employees!`);
}

main().catch(console.error);
