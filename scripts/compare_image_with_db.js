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

// Data extracted directly from the image
const imageRows = [
  {
    sNo: 1,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0001',
    cleanEmpId: 'IGT-0001',
    name: 'G S Saravanan',
    bloodGroup: 'B+',
    uan: '100303730050',
    position: 'Company Director',
    dob: '12-07-1982',
    age: '44',
    pan: 'AZWPS3726Q',
    aadhaar: '8007 5009 8144',
    drivingLicense: '',
    passport: 'C5151971',
    contact: '9790600789',
    emergencyName: '',
    emergencyContact: '',
    email: 'Saravanan@igreentec.in',
    userType: 'ADMIN',
    presentAddress: '507 zercon 301, 5th cross street (South) , Ram Nagar, Madipakkam Chennai 600091 India',
    permanentAddress: '507 zercon 301, 5th cross street (South) , Ram Nagar, Madipakkam Chennai 600091 India'
  },
  {
    sNo: 8,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0109',
    cleanEmpId: 'IGT-0109',
    name: 'Kannan P',
    bloodGroup: 'O+',
    uan: '101492484144',
    position: 'Trainee',
    dob: '03-12-1988',
    age: '37',
    pan: '',
    aadhaar: '8424 5760 3254',
    drivingLicense: '',
    passport: '',
    contact: '9790904031',
    emergencyName: 'Nithya',
    emergencyContact: '74487 14247',
    email: 'dummy109@igreentec.in',
    userType: 'EMPLOYEE',
    presentAddress: 'No, 2/604, Tanthayer Nagar First Street, Thoraipakkam, Chennai - 600097',
    permanentAddress: 'No, 2/604, Tanthayer Nagar First Street, Thoraipakkam, Chennai - 600097'
  },
  {
    sNo: 9,
    location: 'Factory',
    company: 'Igreen Technologies',
    empId: 'IGT - 0120',
    cleanEmpId: 'IGT-0120',
    name: 'Balaji P',
    bloodGroup: 'O+',
    uan: '101575881232',
    position: 'Executive',
    dob: '08-03-1989',
    age: '37',
    pan: 'BNEPP8018B',
    aadhaar: '9042 2400 8037',
    drivingLicense: '',
    passport: '',
    contact: '8608830499',
    emergencyName: 'Padmanaban',
    emergencyContact: '99628 44174',
    email: 'support@igreentec.in',
    userType: 'EMPLOYEE',
    presentAddress: '8/93, Bajanai Kovil Street, Pozhichalur, Kancheepuram, Chennai - 74',
    permanentAddress: '8/93, Bajanai Kovil Street, Pozhichalur, Kancheepuram, Chennai - 74'
  },
  {
    sNo: 11,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0133',
    cleanEmpId: 'IGT-0133',
    name: 'Sivarajan Shanmugam',
    bloodGroup: 'B+',
    uan: '102063204073',
    position: 'CNC Programmer',
    dob: '11-08-1990',
    age: '36',
    pan: 'ENJPB9270H',
    aadhaar: '3541 2808 3102',
    drivingLicense: '',
    passport: '',
    contact: '9825043212',
    emergencyName: 'Sadila',
    emergencyContact: '8939369660',
    email: 'IGT133@gmail.com',
    userType: 'EMPLOYEE',
    presentAddress: 'No.27/31, Immanuvel Street, Ambedhkar Puratchi Nagar, Kandanchavadi, Perungudi, Chennai - 600096',
    permanentAddress: 'No.27/31, Immanuvel Street, Ambedhkar Puratchi Nagar, Kandanchavadi, Perungudi, Chennai - 600096'
  },
  {
    sNo: 13,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0158',
    cleanEmpId: 'IGT-0158',
    name: 'E Manikandan',
    bloodGroup: 'B+',
    uan: '102063204020',
    position: 'CNC Operator',
    dob: '07-07-1980',
    age: '46',
    pan: 'DBOPM1746C',
    aadhaar: '4246 6889 0701',
    drivingLicense: '',
    passport: '',
    contact: '8667831057',
    emergencyName: 'Kalyani',
    emergencyContact: '7358084223',
    email: 'dummy158@igreentec.in',
    userType: 'EMPLOYEE',
    presentAddress: 'S/O. P Eseki, No.133, Kamaraj Nagar, 12th Cross Street, Perungudi, Chennai - 600096',
    permanentAddress: 'S/O. P Eseki, No.133, Kamaraj Nagar, 12th Cross Street, Perungudi, Chennai - 600096'
  },
  {
    sNo: 14,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0159',
    cleanEmpId: 'IGT-0159',
    name: 'Singara Lakshmanan Palanisamy',
    bloodGroup: 'O+',
    uan: '101732574735',
    position: 'Lathe Operator',
    dob: '21-04-1988',
    age: '38',
    pan: 'GYLPP3087B',
    aadhaar: '6407 2143 0125',
    drivingLicense: '',
    passport: '',
    contact: '9789374579',
    emergencyName: 'Malarvizhi',
    emergencyContact: '9787885088',
    email: 'dummy159@igreentec.in',
    userType: 'EMPLOYEE',
    presentAddress: 'Vinayagapuram, second street, S kolathur, kovilambakkam, chennai - 600129',
    permanentAddress: 'No.3/46, Servaikaranpatti, Ayori pudupatti, Manapparai Taluka Ayanpudupatti Tiruchirappalli - 621308'
  },
  {
    sNo: 15,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0172',
    cleanEmpId: 'IGT-0172',
    name: 'M Pandi',
    bloodGroup: 'O+',
    uan: '100265081533',
    position: 'Fitter',
    dob: '15-04-1970',
    age: '56',
    pan: '',
    aadhaar: '7300 2870 7025',
    drivingLicense: '',
    passport: '',
    contact: '8608858064',
    emergencyName: 'Vijayalakshmi',
    emergencyContact: '8608723171',
    email: 'dummy172@igreentec.in',
    userType: 'EMPLOYEE',
    presentAddress: '33, Gandhi Street, Gandhi Thirunallur, Muthirapalayam, Pondicherry - 605009',
    permanentAddress: '33, Gandhi Street, Gandhi Thirunallur, Muthirapalayam, Pondicherry - 605009'
  },
  {
    sNo: 16,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0174',
    cleanEmpId: 'IGT-0174',
    name: 'Ramjanam',
    bloodGroup: 'O+',
    uan: '102063204042',
    position: 'Welder',
    dob: '01-01-1977',
    age: '49',
    pan: '',
    aadhaar: '9496 5650 6514',
    drivingLicense: '',
    passport: '',
    contact: '9677084751',
    emergencyName: 'Chinta',
    emergencyContact: '7275064970',
    email: 'dummy174@igreentec.in',
    userType: 'EMPLOYEE',
    presentAddress: 'S/O, Subaru, Rampur Badauna, PO Byohara, Lalganj, Azamgarh, Lal Ganj, Uttar Pradesh - 276302',
    permanentAddress: 'S/O, Subaru, Rampur Badauna, PO Byohara, Lalganj, Azamgarh, Lal Ganj, Uttar Pradesh - 276302'
  },
  {
    sNo: 17,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0175',
    cleanEmpId: 'IGT-0175',
    name: 'Dharmendra Kumar',
    bloodGroup: 'O+',
    uan: '101254601561',
    position: 'Welder',
    dob: '01-01-1994',
    age: '32',
    pan: '',
    aadhaar: '5960 1112 2047',
    drivingLicense: '',
    passport: '',
    contact: '9791064196',
    emergencyName: 'Harish Chandra',
    emergencyContact: '9791063986',
    email: 'dummy175@igreentec.in',
    userType: 'EMPLOYEE',
    presentAddress: 'S/O, Harichandra Ram, Rampur Badauna, Post Byowhara, Rampur, Azamgarh, Lal Ganj - Uttar Pradesh - 276302',
    permanentAddress: 'S/O, Harichandra Ram, Rampur Badauna, Post Byowhara, Rampur, Azamgarh, Lal Ganj - Uttar Pradesh - 276302'
  },
  {
    sNo: 19,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0183',
    cleanEmpId: 'IGT-0183',
    name: 'Paramasivam',
    bloodGroup: 'B+',
    uan: '101481914985',
    position: 'VMC Operator',
    dob: '14-07-1989',
    age: '37',
    pan: 'FBSPP9081K',
    aadhaar: '8122 1397 1532',
    drivingLicense: '',
    passport: '',
    contact: '7904325827',
    emergencyName: 'Aruna',
    emergencyContact: '8270353775',
    email: 'dummy183@igreentec.in',
    userType: 'EMPLOYEE',
    presentAddress: 'S/O, Selvarangam, 120, Duraisamy Street, C Vakkaramari, Cuddalore, Nanjalur, 608302',
    permanentAddress: 'S/O, Selvarangam, 120, Duraisamy Street, C Vakkaramari, Cuddalore, Nanjalur, 608302'
  },
  {
    sNo: 20,
    location: 'Factory',
    company: 'IGT Manufacturing',
    empId: 'IGT - 0192',
    cleanEmpId: 'IGT-0192',
    name: 'Moti Kumar',
    bloodGroup: 'O+',
    uan: '102265626829',
    position: 'Helper',
    dob: '10-11-1975',
    age: '50',
    pan: '',
    aadhaar: '4136 2935 7546',
    drivingLicense: '',
    passport: '',
    contact: '',
    emergencyName: '',
    emergencyContact: '',
    email: 'dummy192@igreentec.in',
    userType: 'EMPLOYEE',
    presentAddress: 'S/O, Yadu Choudhary, Rasulpur, Post jat dumari, Punpun, Patna, Bihar - 804453',
    permanentAddress: 'S/O, Yadu Choudhary, Rasulpur, Post jat dumari, Punpun, Patna, Bihar - 804453'
  }
];

async function compare() {
  const empRes = await get('employees');
  const allEmps = (empRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  for (const img of imageRows) {
    const dbDoc = allEmps.find(e => 
      e.docId === img.cleanEmpId ||
      (e.employee_id || '').trim().replace(/\s+/g, '') === img.cleanEmpId
    );

    console.log(`\n======================================================================`);
    console.log(`S.No ${img.sNo} : ${img.name}`);
    console.log(`Status in UI & DB: ${dbDoc ? 'PRESENT (Fully in DB & UI)' : 'NOT FOUND IN DB'}`);
    console.log(`Image Emp ID: ${img.empId} | DB Doc ID: ${dbDoc ? dbDoc.docId : 'N/A'}`);
    console.log(`----------------------------------------------------------------------`);
    if (dbDoc) {
      const dbFullName = `${dbDoc.first_name || ''} ${dbDoc.last_name || ''}`.trim() || dbDoc.name || '';
      console.log(`DB Full Name: "${dbFullName}" | Image Name: "${img.name}"`);
      console.log(`DB Company / Org: "${dbDoc.organization_name}" (BU: "${dbDoc.business_unit}") | Image: "${img.company}"`);
      console.log(`DB Position / Desig: "${dbDoc.designation}" | Image: "${img.position}"`);
      console.log(`DB Department: "${dbDoc.department}" | Image Location: "${img.location}"`);
      console.log(`DB User Type / Role: "${dbDoc.user_type || dbDoc.role}" | Image: "${img.userType}"`);
      console.log(`DB Contact No: "${dbDoc.phone_number || dbDoc.personal_mobile}" | Image: "${img.contact}"`);
      console.log(`DB Email: "${dbDoc.email_address}" | Image: "${img.email}"`);
      console.log(`DB DOB: "${dbDoc.original_dob || dbDoc.dob}" | Image: "${img.dob}" (Age: ${img.age})`);
      console.log(`DB Blood Group: "${dbDoc.blood_group}" | Image: "${img.bloodGroup}"`);
      console.log(`DB UAN / PF: "${dbDoc.pf_uan || dbDoc.pf_number}" | Image: "${img.uan}"`);
      console.log(`DB PAN: "${dbDoc.pan_number}" | Image: "${img.pan}"`);
      console.log(`DB Aadhaar: "${dbDoc.aadhaar_number}" | Image: "${img.aadhaar}"`);
      console.log(`DB Passport: "${dbDoc.passport_number}" | Image: "${img.passport}"`);
      console.log(`DB Emergency Name: "${dbDoc.emergency_name}" | Image: "${img.emergencyName}"`);
      console.log(`DB Emergency Contact: "${dbDoc.emergency_mobile}" | Image: "${img.emergencyContact}"`);
      console.log(`DB Present Address: "${dbDoc.present_address}"`);
      console.log(`Image Present Address: "${img.presentAddress}"`);
      console.log(`DB Permanent Address: "${dbDoc.permanent_address}"`);
      console.log(`Image Permanent Address: "${img.permanentAddress}"`);
    }
  }
}

compare().catch(console.error);
