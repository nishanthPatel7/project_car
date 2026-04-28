const {createClient} = require("@libsql/client");

const url = "libsql://projectcardb-for10-services.aws-ap-south-1.turso.io";
const authToken = "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3NzY4NjE4MTcsImlkIjoiMDE5ZGI1MzYtMzAwMS03MDQ0LTllZGUtN2QwOWU4M2VhYWNiIiwicmlkIjoiYTY2ZjVlMjktYmJhYS00OGM2LTk0YTctYzhmYWE1ZjFkYWVjIn0.kEw9jpv3qOFoMTvxnPUGRUI42qtJapyeFhmzQpFDklUn8fFeAbd_xgxfeAtddOPxsB8-ONh_X0EW_BzTS1duBg";

async function debug() {
  const db = createClient({url, authToken});
  const uid = "9rNGtmBJ1QPDNpUUd7trTehqeKH3";
  
  console.log("Simulating getGarageJobs for UID:", uid);
  
  // 1. Get Partner IDs
  const partnerIdsRs = await db.execute({
    sql: "SELECT partner_id FROM garage_requests WHERE user_uid = ? AND status = 'approved'",
    args: [uid],
  });
  console.log("Partner IDs from requests:", partnerIdsRs.rows);
  
  const userProfileRs = await db.execute({
    sql: "SELECT partner_id FROM users WHERE firebase_uid = ?",
    args: [uid],
  });
  console.log("Partner ID from profile:", userProfileRs.rows);
  
  const partnerIds = [
    ...partnerIdsRs.rows.map((r) => r.partner_id),
    userProfileRs.rows[0]?.partner_id
  ].filter(Boolean);
  
  const identifiers = [...new Set([
    uid,
    ...partnerIds,
    ...partnerIds.map(id => id.toLowerCase())
  ])];
  console.log("Final Identifiers list:", identifiers);
  
  const placeholders = identifiers.map(() => "?").join(",");
  
  // 2. Run the actual query
  const sql = `SELECT jobs.*, COALESCE(users.display_name, jobs.customer_name) as display_name 
               FROM jobs 
               LEFT JOIN users ON jobs.customer_uid = users.firebase_uid 
               WHERE (jobs.garage_uid IN (${placeholders}) OR jobs.garage_id IN (${placeholders}))
               ORDER BY created_at DESC`;
  
  const res = await db.execute({ sql, args: [...identifiers, ...identifiers] });
  console.log("Query Results Count:", res.rows.length);
  if (res.rows.length > 0) {
    console.log("First Result Sample:", res.rows[0]);
  } else {
    console.log("NO JOBS FOUND!");
  }
}

debug();
