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

// Exactly the 11 employees and only the requested 10 fields
const updates = [
  {
    docId: 'IGT-0001',
    data: {
      phone_number: '9790600789',
      personal_mobile: '9790600789',
      email_address: 'Saravanan@igreentec.in',
      dob: '1982-07-12',
      original_dob: '12-07-1982',
      pf_uan: '100303730050',
      pf_number: '100303730050',
      pan_number: 'AZWPS3726Q',
      aadhaar_number: '800750098144',
      emergency_name: '',
      emergency_mobile: '',
      present_address: '507 zercon 301, 5th cross street (South) , Ram Nagar, Madipakkam Chennai 600091 India',
      permanent_address: '507 zercon 301, 5th cross street (South) , Ram Nagar, Madipakkam Chennai 600091 India'
    }
  },
  {
    docId: 'IGT-0109',
    data: {
      phone_number: '9790904031',
      personal_mobile: '9790904031',
      email_address: 'dummy109@igreentec.in',
      dob: '1988-12-03',
      original_dob: '03-12-1988',
      pf_uan: '101492484144',
      pf_number: '101492484144',
      pan_number: '',
      aadhaar_number: '842457603254',
      emergency_name: 'Nithya',
      emergency_mobile: '7448714247',
      present_address: 'No, 2/604, Tanthayer Nagar First Street, Thoraipakkam, Chennai - 600097',
      permanent_address: 'No, 2/604, Tanthayer Nagar First Street, Thoraipakkam, Chennai - 600097'
    }
  },
  {
    docId: 'IGT-0120',
    data: {
      phone_number: '8608830499',
      personal_mobile: '8608830499',
      email_address: 'support@igreentec.in',
      dob: '1989-03-08',
      original_dob: '08-03-1989',
      pf_uan: '101575881232',
      pf_number: '101575881232',
      pan_number: 'BNEPP8018B',
      aadhaar_number: '904224008037',
      emergency_name: 'Padmanaban',
      emergency_mobile: '9962844174',
      present_address: '8/93, Bajanai Kovil Street, Pozhichalur, Kancheepuram, Chennai - 74',
      permanent_address: '8/93, Bajanai Kovil Street, Pozhichalur, Kancheepuram, Chennai - 74'
    }
  },
  {
    docId: 'IGT-0133',
    data: {
      phone_number: '9825043212',
      personal_mobile: '9825043212',
      email_address: 'IGT133@gmail.com',
      dob: '1990-08-11',
      original_dob: '11-08-1990',
      pf_uan: '102063204073',
      pf_number: '102063204073',
      pan_number: 'ENJPB9270H',
      aadhaar_number: '354128083102',
      emergency_name: 'Sadila',
      emergency_mobile: '8939369660',
      present_address: 'No.27/31, Immanuvel Street, Ambedhkar Puratchi Nagar, Kandanchavadi, Perungudi, Chennai - 600096',
      permanent_address: 'No.27/31, Immanuvel Street, Ambedhkar Puratchi Nagar, Kandanchavadi, Perungudi, Chennai - 600096'
    }
  },
  {
    docId: 'IGT-0158',
    data: {
      phone_number: '8667831057',
      personal_mobile: '8667831057',
      email_address: 'dummy158@igreentec.in',
      dob: '1980-07-07',
      original_dob: '07-07-1980',
      pf_uan: '102063204020',
      pf_number: '102063204020',
      pan_number: 'DBOPM1746C',
      aadhaar_number: '424668890701',
      emergency_name: 'Kalyani',
      emergency_mobile: '7358084223',
      present_address: 'S/O. P Eseki, No.133, Kamaraj Nagar, 12th Cross Street, Perungudi, Chennai - 600096',
      permanent_address: 'S/O. P Eseki, No.133, Kamaraj Nagar, 12th Cross Street, Perungudi, Chennai - 600096'
    }
  },
  {
    docId: 'IGT-0159',
    data: {
      phone_number: '9789374579',
      personal_mobile: '9789374579',
      email_address: 'dummy159@igreentec.in',
      dob: '1988-04-21',
      original_dob: '21-04-1988',
      pf_uan: '101732574735',
      pf_number: '101732574735',
      pan_number: 'GYLPP3087B',
      aadhaar_number: '640721430125',
      emergency_name: 'Malarvizhi',
      emergency_mobile: '9787885088',
      present_address: 'Vinayagapuram, second street, S kolathur, kovilambakkam, chennai - 600129',
      permanent_address: 'No.3/46, Servaikaranpatti, Ayori pudupatti, Manapparai Taluka Ayanpudupatti Tiruchirappalli - 621308'
    }
  },
  {
    docId: 'IGT-0172',
    data: {
      phone_number: '8608858064',
      personal_mobile: '8608858064',
      email_address: 'dummy172@igreentec.in',
      dob: '1970-04-15',
      original_dob: '15-04-1970',
      pf_uan: '100265081533',
      pf_number: '100265081533',
      pan_number: '',
      aadhaar_number: '730028707025',
      emergency_name: 'Vijayalakshmi',
      emergency_mobile: '8608723171',
      present_address: '33, Gandhi Street, Gandhi Thirunallur, Muthirapalayam, Pondicherry - 605009',
      permanent_address: '33, Gandhi Street, Gandhi Thirunallur, Muthirapalayam, Pondicherry - 605009'
    }
  },
  {
    docId: 'IGT-0174',
    data: {
      phone_number: '9677084751',
      personal_mobile: '9677084751',
      email_address: 'dummy174@igreentec.in',
      dob: '1977-01-01',
      original_dob: '01-01-1977',
      pf_uan: '102063204042',
      pf_number: '102063204042',
      pan_number: '',
      aadhaar_number: '949656506514',
      emergency_name: 'Chinta',
      emergency_mobile: '7275064970',
      present_address: 'S/O, Subaru, Rampur Badauna, PO Byohara, Lalganj, Azamgarh, Lal Ganj, Uttar Pradesh - 276302',
      permanent_address: 'S/O, Subaru, Rampur Badauna, PO Byohara, Lalganj, Azamgarh, Lal Ganj, Uttar Pradesh - 276302'
    }
  },
  {
    docId: 'IGT-0175',
    data: {
      phone_number: '9791064196',
      personal_mobile: '9791064196',
      email_address: 'dummy175@igreentec.in',
      dob: '1994-01-01',
      original_dob: '01-01-1994',
      pf_uan: '101254601561',
      pf_number: '101254601561',
      pan_number: '',
      aadhaar_number: '596011122047',
      emergency_name: 'Harish Chandra',
      emergency_mobile: '9791063986',
      present_address: 'S/O, Harichandra Ram, Rampur Badauna, Post Byowhara, Rampur, Azamgarh, Lal Ganj - Uttar Pradesh - 276302',
      permanent_address: 'S/O, Harichandra Ram, Rampur Badauna, Post Byowhara, Rampur, Azamgarh, Lal Ganj - Uttar Pradesh - 276302'
    }
  },
  {
    docId: 'IGT-0183',
    data: {
      phone_number: '7904325827',
      personal_mobile: '7904325827',
      email_address: 'dummy183@igreentec.in',
      dob: '1989-07-14',
      original_dob: '14-07-1989',
      pf_uan: '101481914985',
      pf_number: '101481914985',
      pan_number: 'FBSPP9081K',
      aadhaar_number: '812213971532',
      emergency_name: 'Aruna',
      emergency_mobile: '8270353775',
      present_address: 'S/O, Selvarangam, 120, Duraisamy Street, C Vakkaramari, Cuddalore, Nanjalur, 608302',
      permanent_address: 'S/O, Selvarangam, 120, Duraisamy Street, C Vakkaramari, Cuddalore, Nanjalur, 608302'
    }
  },
  {
    docId: 'IGT-0192',
    data: {
      phone_number: '',
      personal_mobile: '',
      email_address: 'dummy192@igreentec.in',
      dob: '1975-11-10',
      original_dob: '10-11-1975',
      pf_uan: '102265626829',
      pf_number: '102265626829',
      pan_number: '',
      aadhaar_number: '413629357546',
      emergency_name: '',
      emergency_mobile: '',
      present_address: 'S/O, Yadu Choudhary, Rasulpur, Post jat dumari, Punpun, Patna, Bihar - 804453',
      permanent_address: 'S/O, Yadu Choudhary, Rasulpur, Post jat dumari, Punpun, Patna, Bihar - 804453'
    }
  }
];

async function applyUpdates() {
  console.log(`🚀 Starting update of ${updates.length} employees in Cloud Firestore...\n`);

  for (const item of updates) {
    try {
      await patchSpecificFields('employees', item.docId, item.data);
      console.log(`✅ Successfully updated [${item.docId}] with ${Object.keys(item.data).length} fields!`);
    } catch (e) {
      console.error(`❌ Error updating [${item.docId}]:`, e);
    }
  }

  console.log(`\n🎉 All ${updates.length} employees updated successfully!`);
}

applyUpdates().catch(console.error);
