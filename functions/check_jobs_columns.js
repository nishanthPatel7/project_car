const {createClient} = require("@libsql/client");

const url = "libsql://projectcardb-for10-services.aws-ap-south-1.turso.io";
const authToken = "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3NzY4NjE4MTcsImlkIjoiMDE5ZGI1MzYtMzAwMS03MDQ0LTllZGUtN2QwOWU4M2VhYWNiIiwicmlkIjoiYTY2ZjVlMjktYmJhYS00OGM2LTk0YTctYzhmYWE1ZjFkYWVjIn0.kEw9jpv3qOFoMTvxnPUGRUI42qtJapyeFhmzQpFDklUn8fFeAbd_xgxfeAtddOPxsB8-ONh_X0EW_BzTS1duBg";

async function check() {
  const db = createClient({url, authToken});
  
  console.log("Inspecting Jobs table columns and data...");
  const columns = await db.execute("PRAGMA table_info(jobs)");
  console.log("Columns:");
  console.table(columns.rows.map(r => ({name: r.name, type: r.type})));
  
  const rs = await db.execute("SELECT id, customer_uid, garage_id, garage_uid, status FROM jobs LIMIT 20");
  console.log("\nJobs Data (first 20):");
  console.table(rs.rows);
}

check();
