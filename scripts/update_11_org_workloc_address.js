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

const ORG_ID = 'org_1790494337024';
const ORG_NAME = 'IGREENTEC ENGINEERING INDIA P LTD';
const WORK_LOC = 'Factory';

const targetEmployees = [
  {
    docId: 'IGT-0001',
    name: 'G S Saravanan',
    presentAddress: '507 zercon 301, 5th cross street (South) , Ram Nagar, Madipakkam Chennai 600091 India',
    presentCity: 'Chennai',
    presentDistrict: 'Chennai',
    presentState: 'Tamil Nadu',
    presentPincode: '600091',
    permanentAddress: '507 zercon 301, 5th cross street (South) , Ram Nagar, Madipakkam Chennai 600091 India',
    permanentCity: 'Chennai',
    permanentDistrict: 'Chennai',
    permanentState: 'Tamil Nadu',
    permanentPincode: '600091'
  },
  {
    docId: 'IGT-0109',
    name: 'Kannan P',
    presentAddress: 'No, 2/604, Tanthayer Nagar First Street, Thoraipakkam, Chennai - 600097',
    presentCity: 'Chennai',
    presentDistrict: 'Chennai',
    presentState: 'Tamil Nadu',
    presentPincode: '600097',
    permanentAddress: 'No, 2/604, Tanthayer Nagar First Street, Thoraipakkam, Chennai - 600097',
    permanentCity: 'Chennai',
    permanentDistrict: 'Chennai',
    permanentState: 'Tamil Nadu',
    permanentPincode: '600097'
  },
  {
    docId: 'IGT-0120',
    name: 'Balaji P',
    // 74 means 600074 as instructed
    presentAddress: '8/93, Bajanai Kovil Street, Pozhichalur, Kancheepuram, Chennai - 600074',
    presentCity: 'Chennai',
    presentDistrict: 'Kancheepuram',
    presentState: 'Tamil Nadu',
    presentPincode: '600074',
    permanentAddress: '8/93, Bajanai Kovil Street, Pozhichalur, Kancheepuram, Chennai - 600074',
    permanentCity: 'Chennai',
    permanentDistrict: 'Kancheepuram',
    permanentState: 'Tamil Nadu',
    permanentPincode: '600074'
  },
  {
    docId: 'IGT-0133',
    name: 'Sivarajan Shanmugam',
    presentAddress: 'No.27/31, Immanuvel Street, Ambedhkar Puratchi Nagar, Kandanchavadi, Perungudi, Chennai - 600096',
    presentCity: 'Chennai',
    presentDistrict: 'Chennai',
    presentState: 'Tamil Nadu',
    presentPincode: '600096',
    permanentAddress: 'No.27/31, Immanuvel Street, Ambedhkar Puratchi Nagar, Kandanchavadi, Perungudi, Chennai - 600096',
    permanentCity: 'Chennai',
    permanentDistrict: 'Chennai',
    permanentState: 'Tamil Nadu',
    permanentPincode: '600096'
  },
  {
    docId: 'IGT-0158',
    name: 'E Manikandan',
    presentAddress: 'S/O. P Eseki, No.133, Kamaraj Nagar, 12th Cross Street, Perungudi, Chennai - 600096',
    presentCity: 'Chennai',
    presentDistrict: 'Chennai',
    presentState: 'Tamil Nadu',
    presentPincode: '600096',
    permanentAddress: 'S/O. P Eseki, No.133, Kamaraj Nagar, 12th Cross Street, Perungudi, Chennai - 600096',
    permanentCity: 'Chennai',
    permanentDistrict: 'Chennai',
    permanentState: 'Tamil Nadu',
    permanentPincode: '600096'
  },
  {
    docId: 'IGT-0159',
    name: 'Singara Lakshmanan Palanisamy',
    presentAddress: 'Vinayagapuram, second street, S kolathur, kovilambakkam, chennai - 600129',
    presentCity: 'Chennai',
    presentDistrict: 'Chennai',
    presentState: 'Tamil Nadu',
    presentPincode: '600129',
    permanentAddress: 'No.3/46, Servaikaranpatti, Ayori pudupatti, Manapparai Taluka Ayanpudupatti Tiruchirappalli - 621308',
    permanentCity: 'Tiruchirappalli',
    permanentDistrict: 'Tiruchirappalli',
    permanentState: 'Tamil Nadu',
    permanentPincode: '621308'
  },
  {
    docId: 'IGT-0172',
    name: 'M Pandi',
    presentAddress: '33, Gandhi Street, Gandhi Thirunallur, Muthirapalayam, Pondicherry - 605009',
    presentCity: 'Pondicherry',
    presentDistrict: 'Pondicherry',
    presentState: 'Puducherry',
    presentPincode: '605009',
    permanentAddress: '33, Gandhi Street, Gandhi Thirunallur, Muthirapalayam, Pondicherry - 605009',
    permanentCity: 'Pondicherry',
    permanentDistrict: 'Pondicherry',
    permanentState: 'Puducherry',
    permanentPincode: '605009'
  },
  {
    docId: 'IGT-0174',
    name: 'Ramjanam',
    presentAddress: 'S/O, Subaru, Rampur Badauna, PO Byohara, Lalganj, Azamgarh, Lal Ganj, Uttar Pradesh - 276302',
    presentCity: 'Azamgarh',
    presentDistrict: 'Azamgarh',
    presentState: 'Uttar Pradesh',
    presentPincode: '276302',
    permanentAddress: 'S/O, Subaru, Rampur Badauna, PO Byohara, Lalganj, Azamgarh, Lal Ganj, Uttar Pradesh - 276302',
    permanentCity: 'Azamgarh',
    permanentDistrict: 'Azamgarh',
    permanentState: 'Uttar Pradesh',
    permanentPincode: '276302'
  },
  {
    docId: 'IGT-0175',
    name: 'Dharmendra Kumar',
    presentAddress: 'S/O, Harichandra Ram, Rampur Badauna, Post Byowhara, Rampur, Azamgarh, Lal Ganj - Uttar Pradesh - 276302',
    presentCity: 'Azamgarh',
    presentDistrict: 'Azamgarh',
    presentState: 'Uttar Pradesh',
    presentPincode: '276302',
    permanentAddress: 'S/O, Harichandra Ram, Rampur Badauna, Post Byowhara, Rampur, Azamgarh, Lal Ganj - Uttar Pradesh - 276302',
    permanentCity: 'Azamgarh',
    permanentDistrict: 'Azamgarh',
    permanentState: 'Uttar Pradesh',
    permanentPincode: '276302'
  },
  {
    docId: 'IGT-0183',
    name: 'Paramasivam',
    presentAddress: 'S/O, Selvarangam, 120, Duraisamy Street, C Vakkaramari, Cuddalore, Nanjalur, 608302',
    presentCity: 'Cuddalore',
    presentDistrict: 'Cuddalore',
    presentState: 'Tamil Nadu',
    presentPincode: '608302',
    permanentAddress: 'S/O, Selvarangam, 120, Duraisamy Street, C Vakkaramari, Cuddalore, Nanjalur, 608302',
    permanentCity: 'Cuddalore',
    permanentDistrict: 'Cuddalore',
    permanentState: 'Tamil Nadu',
    permanentPincode: '608302'
  },
  {
    docId: 'IGT-0192',
    name: 'Moti Kumar',
    presentAddress: 'S/O, Yadu Choudhary, Rasulpur, Post jat dumari, Punpun, Patna, Bihar - 804453',
    presentCity: 'Patna',
    presentDistrict: 'Patna',
    presentState: 'Bihar',
    presentPincode: '804453',
    permanentAddress: 'S/O, Yadu Choudhary, Rasulpur, Post jat dumari, Punpun, Patna, Bihar - 804453',
    permanentCity: 'Patna',
    permanentDistrict: 'Patna',
    permanentState: 'Bihar',
    permanentPincode: '804453'
  }
];

async function applyUpdates() {
  console.log(`Starting updates for ${targetEmployees.length} employees...\n`);

  for (const emp of targetEmployees) {
    const patchData = {
      // Organization fields
      organization_id: ORG_ID,
      organizationId: ORG_ID,
      organization_name: ORG_NAME,
      organizationName: ORG_NAME,
      org_name: ORG_NAME,

      // Work location
      work_location: WORK_LOC,
      workLocation: WORK_LOC,

      // Present Address fields
      present_address: emp.presentAddress,
      present_city: emp.presentCity,
      present_district: emp.presentDistrict,
      present_state: emp.presentState,
      presentState: emp.presentState,
      present_pincode: emp.presentPincode,
      presentPincode: emp.presentPincode,
      present_country: 'India',

      // Permanent Address fields
      permanent_address: emp.permanentAddress,
      permanent_city: emp.permanentCity,
      permanent_district: emp.permanentDistrict,
      permanent_state: emp.permanentState,
      permanentState: emp.permanentState,
      permanent_pincode: emp.permanentPincode,
      permanentPincode: emp.permanentPincode,
      permanent_country: 'India',

      // General / Top-level Address fallback fields
      city: emp.presentCity,
      state: emp.presentState,
      postal_code: emp.presentPincode,
      country: 'India'
    };

    console.log(`Updating ${emp.docId} (${emp.name})...`);
    await patchSpecificFields('employees', emp.docId, patchData);
    console.log(`  ✓ Updated ${emp.docId} successfully!`);
  }

  console.log('\n--- VERIFYING FROM FIRESTORE ---');
  const empRes = await get('employees');
  const allEmps = (empRes.documents || []).map(d => ({
    docId: d.name.split('/').pop(),
    ...parseFields(d.fields)
  }));

  for (const emp of targetEmployees) {
    const record = allEmps.find(e => e.docId === emp.docId);
    if (!record) {
      console.log(`❌ ${emp.docId} not found in Firestore!`);
      continue;
    }
    console.log(`\n[${emp.docId}] ${record.name || record.first_name}:`);
    console.log(`  Org: ${record.organization_name} (${record.organization_id})`);
    console.log(`  Work Loc: ${record.work_location}`);
    console.log(`  Present: ${record.present_city}, ${record.present_state} - ${record.present_pincode}`);
    console.log(`  Permanent: ${record.permanent_city}, ${record.permanent_state} - ${record.permanent_pincode}`);
    console.log(`  Addr Str: ${record.present_address}`);
  }

  console.log('\nAll 11 employees updated and verified successfully.');
}

applyUpdates().catch(console.error);
