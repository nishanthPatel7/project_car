const { createClient } = require("@libsql/client");

const url = "libsql://projectcardb-for10-services.aws-ap-south-1.turso.io";
const authToken = "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3NzY4NjE4MTcsImlkIjoiMDE5ZGI1MzYtMzAwMS03MDQ0LTllZGUtN2QwOWU4M2VhYWNiIiwicmlkIjoiYTY2ZjVlMjktYmJhYS00OGM2LTk0YTctYzhmYWE1ZjFkYWVjIn0.kEw9jpv3qOFoMTvxnPUGRUI42qtJapyeFhmzQpFDklUn8fFeAbd_xgxfeAtddOPxsB8-ONh_X0EW_BzTS1duBg";

async function initDb() {
    const db = createClient({ url, authToken });

    console.log("Initializing Turso Tables...");

    try {
        await db.execute(`
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                firebase_uid TEXT UNIQUE NOT NULL,
                email TEXT,
                role TEXT DEFAULT 'none',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS jobs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_uid TEXT NOT NULL,
                garage_id INTEGER,
                vehicle_no TEXT NOT NULL,
                problem TEXT,
                status TEXT DEFAULT 'pending',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        `);

        await db.execute(`
            CREATE TABLE IF NOT EXISTS inventory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                part_name TEXT NOT NULL,
                stock INTEGER DEFAULT 0,
                threshold INTEGER DEFAULT 5
            );
        `);

        console.log("✅ All tables created successfully!");
    } catch (e) {
        console.error("❌ Error creating tables:", e);
    }
}

initDb();
