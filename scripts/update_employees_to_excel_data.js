const https = require('https');
const { get, parseFields } = require('./inspect_orgs.js');

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
          if (res.statusCode === 404) resolve(true);
          else reject(new Error(`HTTP ${res.statusCode}: ${respData}`));
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

function splitName(fullName) {
  const clean = fullName.trim();
  const parts = clean.split(/\s+/);
  if (parts.length === 1) {
    return { firstName: parts[0], lastName: '' };
  }
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

const excelEmployees = [
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0001',
    fullName: 'C S Saravanan',
    bloodGroup: 'B+',
    uanNumber: '100338738050',
    position: 'Company Director',
    dob: '1982-07-12',
    originalDob: '12-07-1982',
    age: 44,
    panNumber: 'AZWPS3726Q',
    aadhaarNumber: '803750898144',
    drivingLicense: '',
    passportNumber: 'C5151971',
    contactNo: '9790905789',
    emergencyContactName: '',
    emergencyContactNumber: '',
    email: 'Saravanan@igreentec.in',
    userType: 'ADMIN'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0007',
    fullName: 'S Anitha',
    bloodGroup: 'O+',
    uanNumber: '101325736575',
    position: 'Vice President',
    dob: '1991-07-02',
    originalDob: '02-07-1991',
    age: 35,
    panNumber: 'BAYPA0416P',
    aadhaarNumber: '689559760117',
    drivingLicense: 'TN2220090011759',
    passportNumber: 'T5942449',
    contactNo: '8939036333',
    emergencyContactName: '',
    emergencyContactNumber: '',
    email: 'Finance@igreentec.in',
    userType: 'SUPER ADMIN'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0008',
    fullName: 'Ganesh Chandra Das',
    bloodGroup: 'O+',
    uanNumber: '101325736568',
    position: 'Bore Path Specialist',
    dob: '1981-06-15',
    originalDob: '15-06-1981',
    age: 45,
    panNumber: 'ANAPG6040R',
    aadhaarNumber: '315868806215',
    drivingLicense: 'BR39 2020 0002229',
    passportNumber: 'N3157701',
    contactNo: '8340542241',
    emergencyContactName: 'Savita Kumari',
    emergencyContactNumber: '8056338128',
    email: 'ganeshsavita8056338@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0010',
    fullName: 'K Paramasivam',
    bloodGroup: 'A1+',
    uanNumber: '101414130138',
    position: 'Site Coordinator',
    dob: '1995-12-08',
    originalDob: '08-12-1995',
    age: 30,
    panNumber: 'CLHPP5765M',
    aadhaarNumber: '623700113985',
    drivingLicense: 'TN10 2020 0007872',
    passportNumber: 'T8958947',
    contactNo: '9003162453',
    emergencyContactName: 'Kasiammal K',
    emergencyContactNumber: '9514574594',
    email: 'paramacivilengg@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0013',
    fullName: 'Sankar Raja',
    bloodGroup: 'A-',
    uanNumber: '101325736510',
    position: 'Sr. Site Coordinator',
    dob: '1990-11-27',
    originalDob: '27-11-1990',
    age: 35,
    panNumber: 'LOEP35538B',
    aadhaarNumber: '723120160512',
    drivingLicense: 'TN50 Y201 60001433',
    passportNumber: '',
    contactNo: '8939101333',
    emergencyContactName: 'Bro In Law',
    emergencyContactNumber: '9659341375',
    email: 'rsankar.dme@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0044',
    fullName: 'Sivan Arumugam',
    bloodGroup: 'A+',
    uanNumber: '102146355002',
    position: 'Driver',
    dob: '1976-07-18',
    originalDob: '18-07-1976',
    age: 50,
    panNumber: 'HPCPS0371J',
    aadhaarNumber: '337691570854',
    drivingLicense: 'N05 20040009501 - 2054/2004/TN05',
    passportNumber: '',
    contactNo: '9526770765',
    emergencyContactName: 'Lakshmi',
    emergencyContactNumber: '8220822255',
    email: 'dummy-sivan@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0061',
    fullName: 'Sri Kaliyaraj B',
    bloodGroup: 'O+',
    uanNumber: '100712120339',
    position: 'Project Lead',
    dob: '1994-12-01',
    originalDob: '01-12-1994',
    age: 31,
    panNumber: 'CGGPB4129P',
    aadhaarNumber: '713346284914',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '8508414851',
    emergencyContactName: 'Bharathi Mohan',
    emergencyContactNumber: '9486520182',
    email: 'Projects@igreentec.in',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0109',
    fullName: 'Kannan P',
    bloodGroup: 'O+',
    uanNumber: '101492946144',
    position: 'Trainee',
    dob: '1988-12-03',
    originalDob: '03-12-1988',
    age: 37,
    panNumber: '',
    aadhaarNumber: '642057503255',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '9790995531',
    emergencyContactName: 'Nithiya',
    emergencyContactNumber: '7448751247',
    email: 'dummy109@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0120',
    fullName: 'Balaji P',
    bloodGroup: 'O+',
    uanNumber: '101575831232',
    position: 'Executive',
    dob: '1989-03-03',
    originalDob: '03-03-1989',
    age: 37,
    panNumber: 'BNEPP0616B',
    aadhaarNumber: '994224005537',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '8925905499',
    emergencyContactName: 'Padmanaban',
    emergencyContactNumber: '9962844174',
    email: 'support@Igreentec.in',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0121',
    fullName: 'Deepak R',
    bloodGroup: 'A+',
    uanNumber: '100142738875',
    position: 'Relationship Manager',
    dob: '1988-11-19',
    originalDob: '19-11-1988',
    age: 37,
    panNumber: 'ASOPD5395F',
    aadhaarNumber: '802845259900',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '7505054321',
    emergencyContactName: 'Vasanthi',
    emergencyContactNumber: '9176149522',
    email: 'rm@igreentec.in',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0133',
    fullName: 'Sivarajan Shanmugam',
    bloodGroup: 'B+',
    uanNumber: '102058204019',
    position: 'CNC Programmer',
    dob: '1990-08-11',
    originalDob: '11-08-1990',
    age: 35,
    panNumber: 'ENJPS8289H',
    aadhaarNumber: '354925083102',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '9529343212',
    emergencyContactName: 'Sudha',
    emergencyContactNumber: '8939816580',
    email: 'IGT133@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0140',
    fullName: 'Shibu Das',
    bloodGroup: 'A+',
    uanNumber: '',
    position: 'Driver',
    dob: '1987-07-10',
    originalDob: '10-07-1987',
    age: 39,
    panNumber: 'CEJPDE3113A',
    aadhaarNumber: '533702917975',
    drivingLicense: 'BR3920210005067',
    passportNumber: '',
    contactNo: '9953322718',
    emergencyContactName: 'Fatima Kumari',
    emergencyContactNumber: '9155346340',
    email: 'dummy149@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0158',
    fullName: 'E Manikandan',
    bloodGroup: 'B+',
    uanNumber: '102058204025',
    position: 'CNC Operator',
    dob: '1980-07-07',
    originalDob: '07-07-1980',
    age: 45,
    panNumber: 'DBCPM1748C',
    aadhaarNumber: '424668890761',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '8667831057',
    emergencyContactName: 'Kalyani',
    emergencyContactNumber: '7358094223',
    email: 'dummy158@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0159',
    fullName: 'Singara Lakshmanan Palanisamy',
    bloodGroup: 'O+',
    uanNumber: '101792574735',
    position: 'Lathe Operator',
    dob: '1988-04-21',
    originalDob: '21-04-1988',
    age: 38,
    panNumber: 'CYLPP3057B',
    aadhaarNumber: '640721430125',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '9786374079',
    emergencyContactName: 'Malarvizhi',
    emergencyContactNumber: '9787803058',
    email: 'dummy159@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0172',
    fullName: 'M Pandi',
    bloodGroup: 'O+',
    uanNumber: '100265991333',
    position: 'Fitter',
    dob: '1970-04-15',
    originalDob: '15-04-1970',
    age: 55,
    panNumber: '',
    aadhaarNumber: '730328707825',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '8608958064',
    emergencyContactName: 'Vijayalakshmi',
    emergencyContactNumber: '8608723771',
    email: 'dummy172@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0174',
    fullName: 'Ramjanam',
    bloodGroup: 'O+',
    uanNumber: '102058204042',
    position: 'Welder',
    dob: '1977-01-01',
    originalDob: '01-01-1977',
    age: 49,
    panNumber: '',
    aadhaarNumber: '949556936514',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '9577084751',
    emergencyContactName: 'Chinta',
    emergencyContactNumber: '7275954970',
    email: 'dumy174@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0175',
    fullName: 'Dharmendra Kumar',
    bloodGroup: 'B+',
    uanNumber: '101254601981',
    position: 'Welder',
    dob: '1994-01-01',
    originalDob: '01-01-1994',
    age: 32,
    panNumber: '',
    aadhaarNumber: '598011122847',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '9791064198',
    emergencyContactName: 'Harish Chandra',
    emergencyContactNumber: '9791083986',
    email: 'dummy175@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0056',
    fullName: 'Mazhar Shekh',
    bloodGroup: 'O+',
    uanNumber: '101885978498',
    position: 'Rig Operator',
    dob: '1993-09-08',
    originalDob: '08-09-1993',
    age: 33,
    panNumber: 'MDEPS0966A',
    aadhaarNumber: '781777815571',
    drivingLicense: 'JH0920102879448',
    passportNumber: '',
    contactNo: '7903228544',
    emergencyContactName: 'Sheikh Nisar',
    emergencyContactNumber: '6301557825',
    email: 'dummy175@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0183',
    fullName: 'Paramasivam',
    bloodGroup: 'B+',
    uanNumber: '101461914985',
    position: 'VMC Operator',
    dob: '1989-07-14',
    originalDob: '14-07-1989',
    age: 37,
    panNumber: 'FBSPP9301K',
    aadhaarNumber: '812213971532',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '7904325827',
    emergencyContactName: 'Aruna',
    emergencyContactNumber: '8270353775',
    email: 'dummy183@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0192',
    fullName: 'Moti Kumar',
    bloodGroup: 'O+',
    uanNumber: '102265626829',
    position: 'Helper',
    dob: '1975-11-10',
    originalDob: '10-11-1975',
    age: 50,
    panNumber: '',
    aadhaarNumber: '413629357546',
    drivingLicense: '',
    passportNumber: '',
    contactNo: '',
    emergencyContactName: '',
    emergencyContactNumber: '',
    email: 'dummy192@gmail.com',
    userType: 'EMPLOYEE'
  },
  {
    location: 'Office',
    company: 'Igreen Technologies',
    empId: 'IGT - 0205',
    fullName: 'Shajan B',
    bloodGroup: 'O-',
    uanNumber: '101740321622',
    position: 'Accounts Assistant',
    dob: '1999-04-22',
    originalDob: '22-04-1999',
    age: 27,
    panNumber: 'FHEPG9258F',
    aadhaarNumber: '432013498291',
    drivingLicense: 'TN7520210003745',
    passportNumber: '',
    contactNo: '8148282183',
    emergencyContactName: 'Baby',
    emergencyContactNumber: '8903934820',
    email: 'shajan.igreen@gmail.com',
    userType: 'EMPLOYEE'
  }
];

async function updateAllEmployees() {
  console.log('🔄 Fetching current Firestore employees...');
  const res = await get('employees');
  const existingDocs = res.documents || [];
  console.log(`Found ${existingDocs.length} existing documents in Firestore.`);

  const docMapByEmail = {};
  const docMapByName = {};

  for (const doc of existingDocs) {
    const docKey = doc.name.split('/').pop();
    const data = parseFields(doc.fields);
    if (data.email_address) {
      docMapByEmail[data.email_address.toLowerCase().trim()] = { docKey, data };
    }
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim().toLowerCase();
    if (fullName) {
      docMapByName[fullName] = { docKey, data };
    }
  }

  // Pre-seed designations if missing
  const desigDocIds = [];
  for (const item of excelEmployees) {
    const dName = item.position;
    const desigDocId = `desig_${dName.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;
    if (!desigDocIds.includes(desigDocId)) {
      desigDocIds.push(desigDocId);
      await saveDocument('designations', desigDocId, {
        id: Date.now() + Math.floor(Math.random() * 1000),
        designation_name: dName,
        department_name: item.location,
        hierarchy_level: (item.userType === 'ADMIN' || item.userType === 'SUPER ADMIN') ? 'Head' : 'Employee',
        organization_name: 'IGREEN TECHNOLOGIES',
        organization_id: 'org_1790493894148',
        description: ''
      });
    }
  }

  console.log(`\n🚀 Updating ${excelEmployees.length} employees with Excel data...`);

  const updatedIds = [];

  for (let idx = 0; idx < excelEmployees.length; idx++) {
    const emp = excelEmployees[idx];
    const { firstName, lastName } = splitName(emp.fullName);

    // Find existing doc
    let match = docMapByEmail[emp.email.toLowerCase().trim()];
    if (!match) {
      match = docMapByName[emp.fullName.toLowerCase().trim()];
    }
    if (!match && emp.fullName === 'Deepak R') {
      match = docMapByEmail['dpk_crazy@yahoo.in'];
    }
    if (!match && emp.fullName === 'Shajan B') {
      match = docMapByEmail['shajanb1999@gmail.com'];
    }
    if (!match && emp.fullName === 'Mazhar Shekh') {
      match = docMapByName['mazhar shekh'];
    }

    const oldData = match ? match.data : {};
    const oldDocKey = match ? match.docKey : null;

    const digits = emp.empId.replace(/\D/g, '');
    const integerId = parseInt(digits, 10) || (idx + 1);
    const newDocId = emp.empId; // Exact "IGT - 0001", "IGT - 0007", etc.

    const reportingManager = integerId === 1 ? '' : 'G S Saravanan';
    const reportingManagerId = integerId === 1 ? '' : 'IGT - 0001';

    let accessPermissions = oldData.access_permissions || [
      'My Asset',
      'Attendance',
      'On-Duty',
      'Time Clocking',
      'My Tasks',
      'My Payslips',
      'Loan'
    ];
    if (typeof accessPermissions === 'string') {
      try {
        accessPermissions = JSON.parse(accessPermissions);
      } catch (_) {}
    }
    if (emp.userType === 'SUPER ADMIN' || emp.userType === 'ADMIN') {
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

    const updatedDocData = {
      ...oldData,
      id: integerId,
      employee_id: emp.empId,
      first_name: firstName,
      last_name: lastName,
      user_name: firstName.toUpperCase().replace(/[^A-Z0-9]/g, ''),
      gender: ['S Anitha', 'Kalyani', 'Sudha', 'Lakshmi', 'Nithiya', 'Vasanthi', 'Fatima Kumari', 'MalarvIzhi', 'Vijayalakshmi', 'Chinta', 'Aruna', 'Baby', 'Anupriya', 'Kasiammal K', 'Savita Kumari'].includes(emp.fullName) ? 'Female' : 'Male',
      dob: emp.dob,
      original_dob: emp.originalDob,
      blood_group: emp.bloodGroup,
      pan_number: emp.panNumber,
      aadhaar_number: emp.aadhaarNumber,
      pf_uan: emp.uanNumber,
      driving_license_number: emp.drivingLicense,
      passport_number: emp.passportNumber,
      phone_number: emp.contactNo || oldData.phone_number || '',
      personal_mobile: emp.contactNo || oldData.personal_mobile || '',
      email_address: emp.email || oldData.email_address || '',
      organization_name: 'IGREEN TECHNOLOGIES',
      organization_id: 'org_1790493894148',
      business_unit: emp.company,
      department: emp.location,
      work_location: emp.location,
      designation: emp.position,
      user_type: emp.userType,
      role: emp.userType,
      status: 'Active',
      employment_type: 'Full Time',
      work_schedule_type: 'Fixed Schedule',
      in_time: '10:00 AM',
      out_time: '07:00 PM',
      required_working_hours: 9.0,
      reporting_manager: reportingManager,
      reporting_manager_id: reportingManagerId,
      reporting_manager_title: 'Company Director',
      emergency_name: emp.emergencyContactName || oldData.emergency_name || '',
      emergency_mobile: emp.emergencyContactNumber || oldData.emergency_mobile || '',
      temporary_password: oldData.temporary_password || '123456',
      access_permissions: JSON.stringify(accessPermissions)
    };

    // Save under the new docId
    await saveDocument('employees', newDocId, updatedDocData);
    console.log(`✅ [${idx + 1}/21] Saved: ${newDocId} | ${emp.fullName} | PAN: ${emp.panNumber || '(blank)'} | Position: ${emp.position} | Dept: ${emp.location}`);
    updatedIds.push(newDocId);

    // Delete old EMP-xxxx doc if different
    if (oldDocKey && oldDocKey !== newDocId) {
      try {
        await deleteDocument('employees', oldDocKey);
        console.log(`   🗑️ Cleaned up old doc: ${oldDocKey}`);
      } catch (e) {
        console.warn(`   ⚠️ Could not delete ${oldDocKey}:`, e.message);
      }
    }
  }

  console.log(`\n🎉 Finished updating all ${updatedIds.length} employees with Excel data!`);
}

updateAllEmployees().catch(err => {
  console.error('❌ Error updating employees:', err);
  process.exit(1);
});
