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

function saveDocument(collection, docId, data) {
  return new Promise((resolve, reject) => {
    const fields = {};
    for (const [k, v] of Object.entries(data)) {
      fields[k] = toFirestoreValue(v);
    }
    const body = JSON.stringify({ fields });

    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}?key=${API_KEY}`,
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

const employees = [
  {
    id: 3,
    employee_id: 'EMP-0003',
    first_name: 'Shajan',
    last_name: 'B',
    gender: 'Male',
    dob: '1999-04-22',
    blood_group: 'O-',
    aadhaar_number: '432013498291',
    phone_number: '8148262183',
    personal_mobile: '8148262183',
    email_address: 'shajan.b@igreentech.in',
    user_name: 'SHAJAN',
    joining_date: '2025-02-17',
    organization_id: 'org_1790493894148',
    organization_name: 'IGREEN TECHNOLOGIES',
    department: 'Office',
    designation: 'Accounts Assistant',
    user_type: 'EMPLOYEE',
    role: 'EMPLOYEE',
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
    reporting_manager: 'Saravanan GS',
    reporting_manager_id: '',
    reporting_manager_title: 'Managing Director',
    temporary_password: '123456',
    access_permissions: JSON.stringify([
      'My Asset',
      'Attendance',
      'On-Duty',
      'Time Clocking',
      'My Tasks',
      'My Payslips',
      'Loan'
    ]),
    street: 'No. 9 Venkatesh Perumal St, Ram Nagar',
    city: 'Chennai',
    state: 'Tamil Nadu',
    postal_code: '600091',
    country: 'India',
    present_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    present_city: 'Chennai',
    present_state: 'Tamil Nadu',
    present_district: 'Chennai',
    present_pincode: '600091',
    present_country: 'India',
    permanent_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    permanent_city: 'Chennai',
    permanent_state: 'Tamil Nadu',
    permanent_district: 'Chennai',
    permanent_pincode: '600091',
    permanent_country: 'India',
    same_as_permanent: 1,
    education_items: [],
    experience_items: [],
    document_items: []
  },
  {
    id: 4,
    employee_id: 'EMP-0004',
    first_name: 'Sri Kaliyaraj',
    last_name: 'B',
    gender: 'Male',
    dob: '1994-05-01',
    blood_group: 'O+',
    aadhaar_number: '713346284914',
    phone_number: '8608414851',
    personal_mobile: '8608414851',
    email_address: 'srikaliyaraj.b@igreentech.in',
    user_name: 'KALIYARAJ',
    joining_date: '2021-11-18',
    organization_id: 'org_1790493894148',
    organization_name: 'IGREEN TECHNOLOGIES',
    department: 'Project',
    designation: 'Project Leader',
    user_type: 'EMPLOYEE',
    role: 'EMPLOYEE',
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
    reporting_manager: 'Saravanan GS',
    reporting_manager_id: '',
    reporting_manager_title: 'Managing Director',
    temporary_password: '123456',
    access_permissions: JSON.stringify([
      'My Asset',
      'Attendance',
      'On-Duty',
      'Time Clocking',
      'My Tasks',
      'My Payslips',
      'Loan'
    ]),
    street: 'No. 9 Venkatesh Perumal St, Ram Nagar',
    city: 'Chennai',
    state: 'Tamil Nadu',
    postal_code: '600091',
    country: 'India',
    present_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    present_city: 'Chennai',
    present_state: 'Tamil Nadu',
    present_district: 'Chennai',
    present_pincode: '600091',
    present_country: 'India',
    permanent_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    permanent_city: 'Chennai',
    permanent_state: 'Tamil Nadu',
    permanent_district: 'Chennai',
    permanent_pincode: '600091',
    permanent_country: 'India',
    same_as_permanent: 1,
    education_items: [],
    experience_items: [],
    document_items: []
  },
  {
    id: 5,
    employee_id: 'EMP-0005',
    first_name: 'Ganesh',
    last_name: 'Chandra Das',
    gender: 'Male',
    dob: '1981-06-15',
    blood_group: 'O+',
    aadhaar_number: '316868806215',
    phone_number: '8340542241',
    personal_mobile: '8340542241',
    email_address: 'ganeshsavita8056338@gmail.com',
    user_name: 'GANESH',
    joining_date: '2018-04-26',
    organization_id: 'org_1790493894148',
    organization_name: 'IGREEN TECHNOLOGIES',
    department: 'Executiion',
    designation: 'Bore Path Specalist',
    user_type: 'EMPLOYEE',
    role: 'EMPLOYEE',
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
    reporting_manager: 'Saravanan GS',
    reporting_manager_id: '',
    reporting_manager_title: 'Managing Director',
    temporary_password: '123456',
    access_permissions: JSON.stringify([
      'My Asset',
      'Attendance',
      'On-Duty',
      'Time Clocking',
      'My Tasks',
      'My Payslips',
      'Loan'
    ]),
    street: 'No. 9 Venkatesh Perumal St, Ram Nagar',
    city: 'Chennai',
    state: 'Tamil Nadu',
    postal_code: '600091',
    country: 'India',
    present_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    present_city: 'Chennai',
    present_state: 'Tamil Nadu',
    present_district: 'Chennai',
    present_pincode: '600091',
    present_country: 'India',
    permanent_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    permanent_city: 'Chennai',
    permanent_state: 'Tamil Nadu',
    permanent_district: 'Chennai',
    permanent_pincode: '600091',
    permanent_country: 'India',
    same_as_permanent: 1,
    education_items: [],
    experience_items: [],
    document_items: []
  },
  {
    id: 6,
    employee_id: 'EMP-0006',
    first_name: 'Sankar',
    last_name: 'Raja',
    gender: 'Male',
    dob: '1990-11-27',
    blood_group: 'A+',
    aadhaar_number: '723120160512',
    phone_number: '8939101333',
    personal_mobile: '8939101333',
    email_address: 'rsankar.dme@gmail.com',
    user_name: 'SHANKAR',
    joining_date: '2019-07-15',
    organization_id: 'org_1790493894148',
    organization_name: 'IGREEN TECHNOLOGIES',
    department: 'Executiion',
    designation: 'Site Manager',
    user_type: 'EMPLOYEE',
    role: 'EMPLOYEE',
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
    reporting_manager: 'Saravanan GS',
    reporting_manager_id: '',
    reporting_manager_title: 'Managing Director',
    temporary_password: '123456',
    access_permissions: JSON.stringify([
      'My Asset',
      'Attendance',
      'On-Duty',
      'Time Clocking',
      'My Tasks',
      'My Payslips',
      'Loan'
    ]),
    street: 'No. 9 Venkatesh Perumal St, Ram Nagar',
    city: 'Chennai',
    state: 'Tamil Nadu',
    postal_code: '600091',
    country: 'India',
    present_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    present_city: 'Chennai',
    present_state: 'Tamil Nadu',
    present_district: 'Chennai',
    present_pincode: '600091',
    present_country: 'India',
    permanent_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    permanent_city: 'Chennai',
    permanent_state: 'Tamil Nadu',
    permanent_district: 'Chennai',
    permanent_pincode: '600091',
    permanent_country: 'India',
    same_as_permanent: 1,
    education_items: [],
    experience_items: [],
    document_items: []
  },
  {
    id: 7,
    employee_id: 'EMP-0007',
    first_name: 'Anitha',
    last_name: 'S',
    gender: 'Female',
    dob: '1991-07-02',
    blood_group: 'O+',
    aadhaar_number: '669559768117',
    phone_number: '8939036333',
    personal_mobile: '8939036333',
    email_address: 'anitha.trenchless@gmail.com',
    user_name: 'ANITHA',
    joining_date: '2017-12-04',
    organization_id: 'org_1790493894148',
    organization_name: 'IGREEN TECHNOLOGIES',
    department: 'finance',
    designation: 'Vice Presidet',
    user_type: 'ADMIN',
    role: 'ADMIN',
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
    reporting_manager: 'Saravanan GS',
    reporting_manager_id: '',
    reporting_manager_title: 'Managing Director',
    temporary_password: '123456',
    access_permissions: JSON.stringify([
      'My Asset',
      'Attendance',
      'On-Duty',
      'Time Clocking',
      'My Tasks',
      'My Payslips',
      'Loan'
    ]),
    street: 'No. 9 Venkatesh Perumal St, Ram Nagar',
    city: 'Chennai',
    state: 'Tamil Nadu',
    postal_code: '600091',
    country: 'India',
    present_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    present_city: 'Chennai',
    present_state: 'Tamil Nadu',
    present_district: 'Chennai',
    present_pincode: '600091',
    present_country: 'India',
    permanent_address: 'No. 9 Venkatesh Perumal St, Ram Nagar, Madipakkam',
    permanent_city: 'Chennai',
    permanent_state: 'Tamil Nadu',
    permanent_district: 'Chennai',
    permanent_pincode: '600091',
    permanent_country: 'India',
    same_as_permanent: 1,
    education_items: [],
    experience_items: [],
    document_items: []
  }
];

async function main() {
  console.log('Seeding employees...');
  for (const emp of employees) {
    try {
      const res = await saveDocument('employees', emp.employee_id, emp);
      console.log(`✅ Successfully seeded ${emp.employee_id}: ${emp.first_name} ${emp.last_name}`);
    } catch(e) {
      console.error(`❌ Failed to seed ${emp.employee_id}:`, e.message);
    }
  }
}

main();
