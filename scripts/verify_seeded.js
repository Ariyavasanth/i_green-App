const { get, parseFields } = require('./inspect_orgs.js');

async function verify() {
  const emps = await get('employees');
  const docs = emps.documents || [];
  console.log(`Total employee documents in Firestore: ${docs.length}`);
  docs.forEach((d, i) => {
    const f = parseFields(d.fields);
    const docKey = d.name.split('/').pop();
    console.log(`${String(i + 1).padStart(2, ' ')}. [${docKey}] id:${f.id} | emp_id:${f.employee_id} | name:${f.first_name} ${f.last_name} | desig:${f.designation} | loc:${f.department} | email:${f.email_address} | role:${f.role || f.user_type}`);
  });
}

verify().catch(console.error);
