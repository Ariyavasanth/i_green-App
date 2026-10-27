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

// 11 rows from the image
const imageRows = [
  {
    sNo: 1,
    empId: 'IGT-0001',
    name: 'G S Saravanan',
    contact: '9790600789',
    email: 'Saravanan@igreentec.in',
    dob: '12-07-1982',
    isoDob: '1982-07-12',
    uan: '100303730050',
    pan: 'AZWPS3726Q',
    aadhaar: '800750098144',
    emergencyName: '',
    emergencyContact: '',
    presentAddress: '507 zercon 301, 5th cross street (South) , Ram Nagar, Madipakkam Chennai 600091 India',
    permanentAddress: '507 zercon 301, 5th cross street (South) , Ram Nagar, Madipakkam Chennai 600091 India'
  },
  {
    sNo: 8,
    empId: 'IGT-0109',
    name: 'Kannan P',
    contact: '9790904031',
    email: 'dummy109@igreentec.in',
    dob: '03-12-1988',
    isoDob: '1988-12-03',
    uan: '101492484144',
    pan: '',
    aadhaar: '842457603254',
    emergencyName: 'Nithya',
    emergencyContact: '7448714247',
    presentAddress: 'No, 2/604, Tanthayer Nagar First Street, Thoraipakkam, Chennai - 600097',
    permanentAddress: 'No, 2/604, Tanthayer Nagar First Street, Thoraipakkam, Chennai - 600097'
  },
  {
    sNo: 9,
    empId: 'IGT-0120',
    name: 'Balaji P',
    contact: '8608830499',
    email: 'support@igreentec.in',
    dob: '08-03-1989',
    isoDob: '1989-03-08',
    uan: '101575881232',
    pan: 'BNEPP8018B',
    aadhaar: '904224008037',
    emergencyName: 'Padmanaban',
    emergencyContact: '9962844174',
    presentAddress: '8/93, Bajanai Kovil Street, Pozhichalur, Kancheepuram, Chennai - 74',
    permanentAddress: '8/93, Bajanai Kovil Street, Pozhichalur, Kancheepuram, Chennai - 74'
  },
  {
    sNo: 11,
    empId: 'IGT-0133',
    name: 'Sivarajan Shanmugam',
    contact: '9825043212',
    email: 'IGT133@gmail.com',
    dob: '11-08-1990',
    isoDob: '1990-08-11',
    uan: '102063204073',
    pan: 'ENJPB9270H',
    aadhaar: '354128083102',
    emergencyName: 'Sadila',
    emergencyContact: '8939369660',
    presentAddress: 'No.27/31, Immanuvel Street, Ambedhkar Puratchi Nagar, Kandanchavadi, Perungudi, Chennai - 600096',
    permanentAddress: 'No.27/31, Immanuvel Street, Ambedhkar Puratchi Nagar, Kandanchavadi, Perungudi, Chennai - 600096'
  },
  {
    sNo: 13,
    empId: 'IGT-0158',
    name: 'E Manikandan',
    contact: '8667831057',
    email: 'dummy158@igreentec.in',
    dob: '07-07-1980',
    isoDob: '1980-07-07',
    uan: '102063204020',
    pan: 'DBOPM1746C',
    aadhaar: '424668890701',
    emergencyName: 'Kalyani',
    emergencyContact: '7358084223',
    presentAddress: 'S/O. P Eseki, No.133, Kamaraj Nagar, 12th Cross Street, Perungudi, Chennai - 600096',
    permanentAddress: 'S/O. P Eseki, No.133, Kamaraj Nagar, 12th Cross Street, Perungudi, Chennai - 600096'
  },
  {
    sNo: 14,
    empId: 'IGT-0159',
    name: 'Singara Lakshmanan Palanisamy',
    contact: '9789374579',
    email: 'dummy159@igreentec.in',
    dob: '21-04-1988',
    isoDob: '1988-04-21',
    uan: '101732574735',
    pan: 'GYLPP3087B',
    aadhaar: '640721430125',
    emergencyName: 'Malarvizhi',
    emergencyContact: '9787885088',
    presentAddress: 'Vinayagapuram, second street, S kolathur, kovilambakkam, chennai - 600129',
    permanentAddress: 'No.3/46, Servaikaranpatti, Ayori pudupatti, Manapparai Taluka Ayanpudupatti Tiruchirappalli - 621308'
  },
  {
    sNo: 15,
    empId: 'IGT-0172',
    name: 'M Pandi',
    contact: '8608858064',
    email: 'dummy172@igreentec.in',
    dob: '15-04-1970',
    isoDob: '1970-04-15',
    uan: '100265081533',
    pan: '',
    aadhaar: '730028707025',
    emergencyName: 'Vijayalakshmi',
    emergencyContact: '8608723171',
    presentAddress: '33, Gandhi Street, Gandhi Thirunallur, Muthirapalayam, Pondicherry - 605009',
    permanentAddress: '33, Gandhi Street, Gandhi Thirunallur, Muthirapalayam, Pondicherry - 605009'
  },
  {
    sNo: 16,
    empId: 'IGT-0174',
    name: 'Ramjanam',
    contact: '9677084751',
    email: 'dummy174@igreentec.in',
    dob: '01-01-1977',
    isoDob: '1977-01-01',
    uan: '102063204042',
    pan: '',
    aadhaar: '949656506514',
    emergencyName: 'Chinta',
    emergencyContact: '7275064970',
    presentAddress: 'S/O, Subaru, Rampur Badauna, PO Byohara, Lalganj, Azamgarh, Lal Ganj, Uttar Pradesh - 276302',
    permanentAddress: 'S/O, Subaru, Rampur Badauna, PO Byohara, Lalganj, Azamgarh, Lal Ganj, Uttar Pradesh - 276302'
  },
  {
    sNo: 17,
    empId: 'IGT-0175',
    name: 'Dharmendra Kumar',
    contact: '9791064196',
    email: 'dummy175@igreentec.in',
    dob: '01-01-1994',
    isoDob: '1994-01-01',
    uan: '101254601561',
    pan: '',
    aadhaar: '596011122047',
    emergencyName: 'Harish Chandra',
    emergencyContact: '9791063986',
    presentAddress: 'S/O, Harichandra Ram, Rampur Badauna, Post Byowhara, Rampur, Azamgarh, Lal Ganj - Uttar Pradesh - 276302',
    permanentAddress: 'S/O, Harichandra Ram, Rampur Badauna, Post Byowhara, Rampur, Azamgarh, Lal Ganj - Uttar Pradesh - 276302'
  },
  {
    sNo: 19,
    empId: 'IGT-0183',
    name: 'Paramasivam',
    contact: '7904325827',
    email: 'dummy183@igreentec.in',
    dob: '14-07-1989',
    isoDob: '1989-07-14',
    uan: '101481914985',
    pan: 'FBSPP9081K',
    aadhaar: '812213971532',
    emergencyName: 'Aruna',
    emergencyContact: '8270353775',
    presentAddress: 'S/O, Selvarangam, 120, Duraisamy Street, C Vakkaramari, Cuddalore, Nanjalur, 608302',
    permanentAddress: 'S/O, Selvarangam, 120, Duraisamy Street, C Vakkaramari, Cuddalore, Nanjalur, 608302'
  },
  {
    sNo: 20,
    empId: 'IGT-0192',
    name: 'Moti Kumar',
    contact: '',
    email: 'dummy192@igreentec.in',
    dob: '10-11-1975',
    isoDob: '1975-11-10',
    uan: '102265626829',
    pan: '',
    aadhaar: '413629357546',
    emergencyName: '',
    emergencyContact: '',
    presentAddress: 'S/O, Yadu Choudhary, Rasulpur, Post jat dumari, Punpun, Patna, Bihar - 804453',
    permanentAddress: 'S/O, Yadu Choudhary, Rasulpur, Post jat dumari, Punpun, Patna, Bihar - 804453'
  }
];

function cleanDigits(val) {
  return (val || '').toString().replace(/\D/g, '');
}

async function prepareDiff() {
  const empRes = await get('employees');
  const allEmps = (empRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  for (const img of imageRows) {
    const db = allEmps.find(e => e.docId === img.empId);
    if (!db) {
      console.log(`❌ Employee ${img.empId} NOT FOUND in DB`);
      continue;
    }

    console.log(`\n================================================================================`);
    console.log(`👤 S.No ${img.sNo} | Employee: ${img.name} (Emp ID / Doc ID: ${img.empId})`);
    console.log(`================================================================================`);

    const fieldsToCompare = [
      {
        field: 'Contact No',
        dbKey: 'phone_number / personal_mobile',
        current: db.phone_number || db.personal_mobile || '',
        target: img.contact,
        isMatch: cleanDigits(db.phone_number || db.personal_mobile) === cleanDigits(img.contact)
      },
      {
        field: 'Email',
        dbKey: 'email_address',
        current: db.email_address || '',
        target: img.email,
        isMatch: (db.email_address || '').trim().toLowerCase() === img.email.trim().toLowerCase()
      },
      {
        field: 'Date of Birth',
        dbKey: 'dob / original_dob',
        current: `${db.original_dob || db.dob || ''}`,
        target: `${img.dob} (ISO: ${img.isoDob})`,
        isMatch: (db.original_dob === img.dob) || (db.dob === img.isoDob)
      },
      {
        field: 'UAN Number',
        dbKey: 'pf_uan / pf_number',
        current: db.pf_uan || db.pf_number || '',
        target: img.uan,
        isMatch: cleanDigits(db.pf_uan || db.pf_number) === cleanDigits(img.uan)
      },
      {
        field: 'PAN Number',
        dbKey: 'pan_number',
        current: db.pan_number || '',
        target: img.pan,
        isMatch: (db.pan_number || '').trim().toUpperCase() === img.pan.trim().toUpperCase()
      },
      {
        field: 'Aadhaar Number',
        dbKey: 'aadhaar_number',
        current: db.aadhaar_number || '',
        target: img.aadhaar,
        isMatch: cleanDigits(db.aadhaar_number) === cleanDigits(img.aadhaar)
      },
      {
        field: 'Emergency Contact Name',
        dbKey: 'emergency_name',
        current: db.emergency_name || '',
        target: img.emergencyName,
        isMatch: (db.emergency_name || '').trim().toLowerCase() === img.emergencyName.trim().toLowerCase()
      },
      {
        field: 'Emergency Contact Number',
        dbKey: 'emergency_mobile',
        current: db.emergency_mobile || '',
        target: img.emergencyContact,
        isMatch: cleanDigits(db.emergency_mobile) === cleanDigits(img.emergencyContact)
      },
      {
        field: 'Present Address',
        dbKey: 'present_address',
        current: db.present_address || '',
        target: img.presentAddress,
        isMatch: (db.present_address || '').trim() === img.presentAddress.trim()
      },
      {
        field: 'Permanent Address',
        dbKey: 'permanent_address',
        current: db.permanent_address || '',
        target: img.permanentAddress,
        isMatch: (db.permanent_address || '').trim() === img.permanentAddress.trim()
      }
    ];

    let changesCount = 0;
    for (const f of fieldsToCompare) {
      if (f.isMatch) {
        console.log(`  ✓ ${f.field}: "${f.current}" (Already Matches Image)`);
      } else {
        changesCount++;
        console.log(`  ⚡ ${f.field}:`);
        console.log(`       Current in DB : "${f.current}"`);
        console.log(`       Will Change To: "${f.target}"`);
      }
    }
    console.log(`  👉 Total fields to update for this employee: ${changesCount}`);
  }
}

prepareDiff().catch(console.error);
