const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { createClient } = require("@libsql/client");

admin.initializeApp();

const getDbClient = () => {
    const url = process.env.TURSO_DATABASE_URL;
    const authToken = process.env.TURSO_AUTH_TOKEN;
    if (!url || !authToken) throw new Error("Missing Turso Credentials");
    return createClient({ url, authToken });
};

exports.getInitialState = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: [
        "https://carservices-4774a.web.app",
        "https://carservices-4774a.firebaseapp.com",
        "http://localhost:50800",
        "http://localhost:8081"
    ]
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

    const db = getDbClient();
    
    // Auto-migration: Ensure columns exist
    try { await db.execute("ALTER TABLE users ADD COLUMN display_name TEXT"); } catch(e) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN photo_url TEXT"); } catch(e) {}
    try { 
        await db.execute(`
            CREATE TABLE IF NOT EXISTS vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_uid TEXT,
                vehicle_no TEXT,
                model TEXT,
                created_at INTEGER
            )
        `);
        await db.execute(`
            CREATE TABLE IF NOT EXISTS inventory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                admin_uid TEXT,
                name TEXT,
                description TEXT,
                image_url TEXT,
                stock INTEGER DEFAULT 0,
                created_at INTEGER
            )
        `);
    } catch(e) {}

    try {
        // 1. Check if user exists (Select all relevant columns)
        const rs = await db.execute({
            sql: "SELECT role, display_name, photo_url, email FROM users WHERE firebase_uid = ?",
            args: [request.auth.uid]
        });

        const adminUid = "KP3Ix19VEsgHO3Ei5HnyKmRyfN23";
        const isSystemAdmin = request.auth.uid === adminUid;

        if (rs.rows.length === 0) {
            // 2. NEW USER: Save Gmail Email, Name and Photo to Turso
            const email = request.auth.token.email || "";
            const displayName = request.auth.token.name || "New User";
            const photoUrl = request.auth.token.picture || "";
            const role = isSystemAdmin ? 'admin' : 'customer';
            
            await db.execute({
                sql: "INSERT INTO users (firebase_uid, email, role, display_name, photo_url) VALUES (?, ?, ?, ?, ?)",
                args: [request.auth.uid, email, role, displayName, photoUrl]
            });
            
            return {
                view: role,
                role: role,
                data: { name: displayName, photo: photoUrl, email: email }
            };
        }

        // Handle existing user role upgrade to admin if UID matches
        let currentRole = rs.rows[0].role;
        if (isSystemAdmin && currentRole !== 'admin') {
            await db.execute({
                sql: "UPDATE users SET role = 'admin' WHERE firebase_uid = ?",
                args: [request.auth.uid]
            });
            currentRole = 'admin';
        }

        // 2. Fetch Job Stats
        const statsRs = await db.execute({
            sql: "SELECT status, COUNT(*) as count FROM jobs WHERE customer_uid = ? GROUP BY status",
            args: [request.auth.uid]
        });

        const stats = { new: 0, in_progress: 0, completed: 0, total: 0 };
        statsRs.rows.forEach(row => {
            if (row.status === 'pending') stats.new = Number(row.count);
            if (row.status === 'in_progress') stats.in_progress = Number(row.count);
            if (row.status === 'completed') stats.completed = Number(row.count);
            stats.total += Number(row.count);
        });

        // 3. Fetch Vehicles
        const vehiclesRs = await db.execute({
            sql: "SELECT * FROM vehicles WHERE customer_uid = ?",
            args: [request.auth.uid]
        });

        return {
            view: currentRole,
            role: currentRole,
            data: { 
                name: rs.rows[0].display_name, 
                photo: rs.rows[0].photo_url,
                email: rs.rows[0].email,
                stats: stats,
                vehicles: vehiclesRs.rows,
                revenue: "0"
            }
        };
    } catch (error) {
        throw new HttpsError("internal", error.message);
    }
});

exports.addVehicle = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: ["https://carservices-4774a.web.app", "https://carservices-4774a.firebaseapp.com", "http://localhost:50800", "http://localhost:8081"]
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const { vehicleNo, model } = request.data;
    const db = getDbClient();
    try {
        await db.execute({
            sql: "INSERT INTO vehicles (customer_uid, vehicle_no, model, created_at) VALUES (?, ?, ?, ?)",
            args: [request.auth.uid, vehicleNo, model, Date.now()]
        });
        return { status: "success" };
    } catch (error) {
        throw new HttpsError("internal", error.message);
    }
});

exports.addInventoryItem = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: ["https://carservices-4774a.web.app", "https://carservices-4774a.firebaseapp.com", "http://localhost:50800", "http://localhost:8081"]
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDbClient();
    const user = await db.execute({ sql: "SELECT role FROM users WHERE firebase_uid = ?", args: [request.auth.uid] });
    if (user.rows[0]?.role !== 'admin') throw new HttpsError("permission-denied", "Admin access only");

    const { name, description, imageUrl, stock } = request.data;
    try {
        await db.execute({
            sql: "INSERT INTO inventory (admin_uid, name, description, image_url, stock, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            args: [request.auth.uid, name, description, imageUrl, stock, Date.now()]
        });
        return { status: "success" };
    } catch (error) {
        throw new HttpsError("internal", error.message);
    }
});

exports.getInventory = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: ["https://carservices-4774a.web.app", "https://carservices-4774a.firebaseapp.com", "http://localhost:50800", "http://localhost:8081"]
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDbClient();
    const user = await db.execute({ sql: "SELECT role FROM users WHERE firebase_uid = ?", args: [request.auth.uid] });
    if (user.rows[0]?.role !== 'admin') throw new HttpsError("permission-denied", "Admin access only");

    try {
        const rs = await db.execute("SELECT * FROM inventory ORDER BY created_at DESC");
        return { status: "success", data: rs.rows };
    } catch (error) {
        throw new HttpsError("internal", error.message);
    }
});

exports.updateStock = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: ["https://carservices-4774a.web.app", "https://carservices-4774a.firebaseapp.com", "http://localhost:50800", "http://localhost:8081"]
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDbClient();
    const user = await db.execute({ sql: "SELECT role FROM users WHERE firebase_uid = ?", args: [request.auth.uid] });
    if (user.rows[0]?.role !== 'admin') throw new HttpsError("permission-denied", "Admin access only");

    const { id, adjustment } = request.data; // adjustment can be +1 or -1
    try {
        await db.execute({
            sql: "UPDATE inventory SET stock = stock + ? WHERE id = ?",
            args: [adjustment, id]
        });
        return { status: "success" };
    } catch (error) {
        throw new HttpsError("internal", error.message);
    }
});

exports.submitJob = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: [
        "https://carservices-4774a.web.app",
        "https://carservices-4774a.firebaseapp.com",
        "http://localhost:50800",
        "http://localhost:8081"
    ]
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    
    // Auto-migration for jobs table
    const db = getDbClient();
    try { await db.execute("ALTER TABLE jobs ADD COLUMN service_types TEXT"); } catch(e) {}

    const { vehicleNo, problemDesc, serviceTypes, mode } = request.data;
    try {
        await db.execute({
            sql: "INSERT INTO jobs (customer_uid, vehicle_no, problem, service_types, status, mode, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            args: [
                request.auth.uid, 
                vehicleNo, 
                problemDesc, 
                JSON.stringify(serviceTypes || []), 
                "pending", 
                mode || "Walk-in", 
                Date.now()
            ]
        });
        return { status: "success" };
    } catch (error) {
        throw new HttpsError("internal", error.message);
    }
});
