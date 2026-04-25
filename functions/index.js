const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const { createClient } = require("@libsql/client");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

// SET GLOBAL REGION TO MUMBAI (asia-south1)
setGlobalOptions({ region: "asia-south1" });

admin.initializeApp();

let _db;
const getDb = () => {
    if (_db) return _db;
    const url = process.env.TURSO_DATABASE_URL?.trim();
    const authToken = process.env.TURSO_AUTH_TOKEN?.trim();
    if (!url || !authToken) throw new Error("Missing Turso Credentials");
    _db = createClient({ url, authToken });
    return _db;
};

// --- AUTH UTILS ---
const isAdmin = async (request, db) => {
    if (!request.auth) return false;
    // Master Admin Bypass
    if (request.auth.uid === "KP3Ix19VEsgHO3Ei5HnyKmRyfN23") return true; 
    try {
        const rs = await db.execute({
            sql: "SELECT role FROM users WHERE firebase_uid = ?",
            args: [request.auth.uid]
        });
        return rs.rows[0] && (rs.rows[0].role === 'admin' || rs.rows[0].role === 'garage_owner');
    } catch (e) {
        console.error("Auth Check Error:", e);
        return false;
    }
};

exports.getInitialState = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    console.log("DEBUG: getInitialState Start. User:", request.auth?.uid);
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();

    // 0. SCHEMA MIGRATIONS / PROTECTION
    const migrations = [
        "ALTER TABLE users ADD COLUMN display_name TEXT",
        "ALTER TABLE users ADD COLUMN photo_url TEXT",
        "ALTER TABLE inventory ADD COLUMN admin_uid TEXT",
        "ALTER TABLE inventory ADD COLUMN name TEXT",
        "ALTER TABLE inventory ADD COLUMN part_name TEXT",
        "ALTER TABLE inventory ADD COLUMN description TEXT",
        "ALTER TABLE inventory ADD COLUMN image_url TEXT",
        "ALTER TABLE inventory ADD COLUMN stock INTEGER DEFAULT 0",
        "ALTER TABLE inventory ADD COLUMN created_at INTEGER"
    ];

    for (const sql of migrations) {
        try { await db.execute(sql); } catch(e) { /* Col exists */ }
    }

    const jobMigrations = [
        "ALTER TABLE jobs ADD COLUMN vehicle_type TEXT",
        "ALTER TABLE jobs ADD COLUMN brand TEXT",
        "ALTER TABLE jobs ADD COLUMN address TEXT",
        "ALTER TABLE jobs ADD COLUMN garage_uid TEXT",
        "ALTER TABLE jobs ADD COLUMN total_amount INTEGER",
        "ALTER TABLE jobs ADD COLUMN cost_details TEXT"
    ];

    for (const sql of jobMigrations) {
        try { await db.execute(sql); } catch(e) { /* Col exists */ }
    }

    try {
        await db.execute(`CREATE TABLE IF NOT EXISTS vehicles (id INTEGER PRIMARY KEY AUTOINCREMENT, customer_uid TEXT, vehicle_no TEXT, model TEXT, created_at INTEGER)`);
        await db.execute(`CREATE TABLE IF NOT EXISTS jobs (id INTEGER PRIMARY KEY AUTOINCREMENT, customer_uid TEXT, vehicle_no TEXT, problem TEXT, service_types TEXT, status TEXT, mode TEXT, vehicle_type TEXT, brand TEXT, address TEXT, garage_uid TEXT, total_amount INTEGER, cost_details TEXT, created_at INTEGER)`);
        await db.execute(`CREATE TABLE IF NOT EXISTS inventory (id INTEGER PRIMARY KEY AUTOINCREMENT, admin_uid TEXT, name TEXT, description TEXT, image_url TEXT, stock INTEGER DEFAULT 0, created_at INTEGER)`);
        await db.execute(`CREATE TABLE IF NOT EXISTS users (firebase_uid TEXT PRIMARY KEY, email TEXT, role TEXT, display_name TEXT, photo_url TEXT)`);
        await db.execute(`CREATE TABLE IF NOT EXISTS garage_requests (id INTEGER PRIMARY KEY AUTOINCREMENT, user_uid TEXT, name TEXT, phone TEXT, aadhaar TEXT, city TEXT, district TEXT, state TEXT, location TEXT, photo_urls TEXT, status TEXT, created_at INTEGER)`);
        await db.execute(`CREATE TABLE IF NOT EXISTS platform_stats (stat_key TEXT PRIMARY KEY, stat_value INTEGER DEFAULT 0)`);
        await db.execute(`CREATE TABLE IF NOT EXISTS notifications (id INTEGER PRIMARY KEY AUTOINCREMENT, user_uid TEXT, title TEXT, desc TEXT, icon TEXT, color TEXT, created_at INTEGER)`);
    } catch(e) {}

    try {
        const rs = await db.execute({
            sql: "SELECT role, display_name, photo_url FROM users WHERE firebase_uid = ?",
            args: [request.auth.uid]
        });

        const isSystemAdmin = request.auth.uid === "KP3Ix19VEsgHO3Ei5HnyKmRyfN23";

        if (rs.rows.length === 0) {
            const role = isSystemAdmin ? 'admin' : 'customer';
            const email = request.auth.token.email || "";
            const displayName = request.auth.token.name || "New User";
            const photoUrl = request.auth.token.picture || "";
            
            await db.execute({
                sql: "INSERT INTO users (firebase_uid, email, role, display_name, photo_url) VALUES (?, ?, ?, ?, ?)",
                args: [request.auth.uid, email, role, displayName, photoUrl]
            });
            return { view: role, role: role, data: { name: displayName, photo: photoUrl } };
        }

        let currentRole = rs.rows[0].role;
        if (isSystemAdmin && currentRole !== 'admin') {
            await db.execute({ sql: "UPDATE users SET role = 'admin' WHERE firebase_uid = ?", args: [request.auth.uid] });
            currentRole = 'admin';
        }

        let stats = { new: 0, in_progress: 0, completed: 0, total: 0, active_garages: 0, revenue: 0 };
        
        if (currentRole === 'garage_owner') {
            const jobsRs = await db.execute({ sql: "SELECT status, COUNT(*) as count, SUM(total_amount) as total_revenue FROM jobs WHERE garage_uid = ? GROUP BY status", args: [request.auth.uid] });
            jobsRs.rows.forEach(row => {
                if (row.status === 'pending') stats.new = Number(row.count);
                if (row.status === 'in_progress') stats.in_progress = Number(row.count);
                if (row.status === 'completed') {
                    stats.completed = Number(row.count);
                    stats.revenue = Number(row.total_revenue || 0);
                }
                stats.total += Number(row.count);
            });
        } else {
            const statsRs = await db.execute({ sql: "SELECT status, COUNT(*) as count FROM jobs WHERE customer_uid = ? GROUP BY status", args: [request.auth.uid] });
            statsRs.rows.forEach(row => {
                if (row.status === 'pending') stats.new = Number(row.count);
                if (row.status === 'in_progress') stats.in_progress = Number(row.count);
                if (row.status === 'completed') stats.completed = Number(row.count);
                stats.total += Number(row.count);
            });
        }

        // ADMIN STATS OVERRIDE
        if (currentRole === 'admin') {
            const garageCountRs = await db.execute("SELECT COUNT(*) as count FROM users WHERE role = 'garage_owner'");
            const garageCount = Number(garageCountRs.rows[0].count);
            await db.execute({
                sql: "INSERT INTO platform_stats (stat_key, stat_value) VALUES (?, ?) ON CONFLICT(stat_key) DO UPDATE SET stat_value = ?",
                args: ["active_garages", garageCount, garageCount]
            });
            stats.active_garages = garageCount;
        }

        const vehiclesRs = await db.execute({ sql: "SELECT * FROM vehicles WHERE customer_uid = ?", args: [request.auth.uid] });

        // Get some recent jobs for the dashboard
        let recentJobs = [];
        if (currentRole === 'garage_owner') {
            const rjRs = await db.execute({ 
                sql: "SELECT jobs.*, COALESCE(users.display_name, jobs.vehicle_no) as display_name FROM jobs LEFT JOIN users ON jobs.customer_uid = users.firebase_uid WHERE garage_uid = ? ORDER BY created_at DESC LIMIT 5", 
                args: [request.auth.uid] 
            });
            recentJobs = rjRs.rows;
        }

        return {
            view: currentRole,
            role: currentRole,
            data: { 
                name: rs.rows[0].display_name, 
                photo: rs.rows[0].photo_url,
                stats: stats,
                vehicles: vehiclesRs.rows,
                recentJobs: recentJobs
            }
        };
    } catch (error) {
        console.error("getInitialState Fatal Error:", error);
        throw new HttpsError("internal", error.message);
    }
});

exports.updateGarageRequestStatus = onCall({
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    if (!(await isAdmin(request, db))) throw new HttpsError("permission-denied", "Admin access only");

    const { requestId, status, userUid } = request.data;
    await db.execute({
        sql: "UPDATE garage_requests SET status = ? WHERE id = ?",
        args: [status, requestId]
    });

    if (status === 'approved') {
        await db.execute({
            sql: "UPDATE users SET role = 'garage_owner' WHERE firebase_uid = ?",
            args: [userUid]
        });
    }
    return { status: "success" };
});

exports.addVehicle = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    const { vehicleNo, model } = request.data;
    await db.execute({
        sql: "INSERT INTO vehicles (customer_uid, vehicle_no, model, created_at) VALUES (?, ?, ?, ?)",
        args: [request.auth.uid, vehicleNo, model, Date.now()]
    });
    return { status: "success" };
});

exports.addInventoryItem = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    
    if (!(await isAdmin(request, db))) throw new HttpsError("permission-denied", "Admin access only");

    const { name, description, imageUrl, stock } = request.data;
    const columnsRs = await db.execute("PRAGMA table_info(inventory)");
    const columnNames = columnsRs.rows.map(r => r.name);
    
    const dataMap = {
        admin_uid: request.auth.uid,
        name: name,
        part_name: name,
        description: description,
        image_url: imageUrl || "",
        stock: Number(stock) || 0,
        created_at: Date.now()
    };

    const insertCols = [];
    const insertVals = [];
    const placeholders = [];

    for (const col of columnNames) {
        if (col === 'id') continue;
        if (dataMap.hasOwnProperty(col)) {
            insertCols.push(col);
            insertVals.push(dataMap[col]);
            placeholders.push("?");
        }
    }

    const sql = `INSERT INTO inventory (${insertCols.join(", ")}) VALUES (${placeholders.join(", ")})`;
    await db.execute({ sql, args: insertVals });
    return { status: "success" };
});

exports.deleteInventoryItem = onCall({
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    console.log("DEBUG: deleteInventoryItem Start. Payload:", request.data);
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    
    try {
        const db = getDb();
        const id = Number(request.data.id);
        
        if (!(await isAdmin(request, db))) {
            throw new HttpsError("permission-denied", "Only admins can delete products.");
        }

        // 1. Get image URL before deleting
        const item = await db.execute({ sql: "SELECT image_url FROM inventory WHERE id = ?", args: [id] });
        if (item.rows.length === 0) {
            return { status: "error", message: "Item not found" };
        }
        const imageUrl = item.rows[0]?.image_url;
        
        // 2. Delete from DB
        await db.execute({ sql: "DELETE FROM inventory WHERE id = ?", args: [id] });
        console.log("DEBUG: DB Record deleted successfully:", id);

        // 3. Purge media from storage
        if (imageUrl && imageUrl.includes('storage.googleapis.com')) {
            try {
                const fileName = imageUrl.split('/').pop().split('?')[0]; 
                if (fileName) {
                    const bucket = admin.storage().bucket();
                    await bucket.file(`inventory/${fileName}`).delete();
                    console.log("DEBUG: Media purged successfully:", fileName);
                }
            } catch (e) {
                console.warn("DEBUG: Storage purge failure skipped:", e.message);
            }
        }

        return { status: "success", deletedId: id };
    } catch (error) {
        console.error("DIAGNOSTIC DELETE CRASH:", error);
        if (error instanceof HttpsError) throw error;
        throw new HttpsError("internal", error.message);
    }
});

exports.getInventoryLive = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    try {
        const db = getDb();
        const res = await db.execute({
            sql: "SELECT * FROM inventory WHERE admin_uid = ? ORDER BY id DESC LIMIT 100",
            args: [request.auth.uid]
        });
        const items = res.rows.map(row => {
            const obj = {};
            for (const key in row) { obj[key] = row[key]; }
            obj.name = obj.name || obj.part_name || "Unnamed Product";
            obj.image_url = obj.image_url || obj.imageUrl || "";
            return obj;
        });
        return { status: "success", items: items };
    } catch (error) {
        throw new HttpsError("internal", error.message);
    }
});

// Alias for getInventoryLive for any older callers
exports.getInventory = exports.getInventoryLive;

exports.updateStock = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    if (!(await isAdmin(request, db))) throw new HttpsError("permission-denied", "Admin access only");

    const { id, adjustment } = request.data;
    await db.execute({
        sql: "UPDATE inventory SET stock = stock + ? WHERE id = ?",
        args: [adjustment, id]
    });
    return { status: "success" };
});

exports.uploadInventoryImage = onRequest({
    cors: true
}, async (req, res) => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    try {
        const bodyData = req.body.data || req.body;
        const { fileName, contentType, base64Data } = bodyData;
        if (!base64Data) return res.status(400).json({ data: { status: "error", message: "Missing image data" } });

        const bucket = admin.storage().bucket();
        const file = bucket.file(`inventory/${Date.now()}-${fileName}`);
        await file.save(Buffer.from(base64Data, 'base64'), { 
            metadata: { contentType }, 
            public: true, 
            resumable: false 
        });
        await file.makePublic();
        return res.json({ data: { status: "success", publicUrl: `https://storage.googleapis.com/${bucket.name}/${file.name}` } });
    } catch (error) {
        console.error("Upload Error:", error);
        return res.status(500).json({ data: { status: "error", message: error.message } });
    }
});

exports.submitJob = onCall({ region: "asia-south1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    const { vehicleNo, problemDesc, serviceTypes, mode, vehicleType, brand, address, totalAmount, costDetails } = request.data;
    let invoiceNo = request.data.invoiceNo;

    // DEFENSIVE: If client-side generation failed or is stuck, generate it here
    if (!invoiceNo || invoiceNo === "Loading...") {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let isUnique = false;
        while (!isUnique) {
            invoiceNo = '';
            for (let i = 0; i < 8; i++) {
                invoiceNo += chars.charAt(Math.floor(Math.random() * chars.length));
            }
            const rs = await db.execute({
                sql: "SELECT id FROM jobs WHERE invoice_no = ?",
                args: [invoiceNo]
            });
            if (rs.rows.length === 0) isUnique = true;
        }
    }
    
    console.log("DEBUG: submitJob request", request.data, "Final InvoiceNo:", invoiceNo);

    try {
        // Ensure table schema is up to date (Comprehensive Self-Healing)
        const tableInfo = await db.execute("PRAGMA table_info(jobs)");
        const columns = tableInfo.rows.map(r => r.name);
        
        const requiredColumns = [
            { name: "service_types", type: "TEXT" },
            { name: "status", type: "TEXT" },
            { name: "mode", type: "TEXT" },
            { name: "problem", type: "TEXT" },
            { name: "brand", type: "TEXT" },
            { name: "vehicle_type", type: "TEXT" },
            { name: "address", type: "TEXT" },
            { name: "garage_uid", type: "TEXT" },
            { name: "total_amount", type: "INTEGER" },
            { name: "cost_details", type: "TEXT" },
            { name: "invoice_no", type: "TEXT" }
        ];

        for (const col of requiredColumns) {
            if (!columns.includes(col.name)) {
                console.log(`DEBUG: Adding missing ${col.name} column`);
                await db.execute(`ALTER TABLE jobs ADD COLUMN ${col.name} ${col.type}`);
            }
        }

        console.log(`DEBUG: Inserting job for garage: ${request.auth.uid}, amount: ${totalAmount}, details: ${JSON.stringify(costDetails)}`);
        
        await db.execute({
            sql: "INSERT INTO jobs (customer_uid, vehicle_no, problem, service_types, status, mode, vehicle_type, brand, address, garage_uid, total_amount, cost_details, invoice_no, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            args: [
                request.auth.uid, 
                vehicleNo, 
                problemDesc, 
                JSON.stringify(serviceTypes || []), 
                request.data.status || "pending", 
                mode || "Walk-in", 
                vehicleType || "Car",
                brand || "",
                address || "",
                request.data.status === 'completed' ? request.auth.uid : (request.data.garage_uid || null),
                totalAmount || 0,
                costDetails ? JSON.stringify(costDetails) : null,
                invoiceNo || "",
                Date.now()
            ]
        });
        return { status: "success" };
    } catch (e) {
        return { status: "error", message: e.toString() };
    }
});

exports.generateInvoiceNo = onCall({ region: "asia-south1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let invoiceNo = '';
    let isUnique = false;
    let attempts = 0;
    
    while (!isUnique && attempts < 10) {
        invoiceNo = '';
        for (let i = 0; i < 8; i++) {
            invoiceNo += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        try {
            const rs = await db.execute({
                sql: "SELECT id FROM jobs WHERE invoice_no = ?",
                args: [invoiceNo]
            });
            if (rs.rows.length === 0) isUnique = true;
        } catch (e) {
            // If column doesn't exist yet, it's unique!
            isUnique = true;
        }
        attempts++;
    }
    
    return { status: "success", invoiceNo };
});

exports.getUploadUrl = onCall({
    secrets: ["R2_ACCESS_KEY", "R2_SECRET_KEY", "R2_ENDPOINT", "R2_BUCKET_NAME"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const { fileName, contentType } = request.data;
    const endpoint = process.env.R2_ENDPOINT?.trim();
    const accessKeyId = process.env.R2_ACCESS_KEY?.trim();
    const secretAccessKey = process.env.R2_SECRET_KEY?.trim();
    const bucket = process.env.R2_BUCKET_NAME?.trim();

    if (!endpoint || !accessKeyId || !secretAccessKey || !bucket) {
        throw new HttpsError("internal", "Missing R2 configuration secrets");
    }

    const s3 = new S3Client({
        region: "auto",
        endpoint: endpoint,
        credentials: { accessKeyId, secretAccessKey },
    });

    const key = `inventory/${request.auth.uid}/${Date.now()}-${fileName}`;
    const command = new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        ContentType: contentType,
    });

    try {
        const url = await getSignedUrl(s3, command, { expiresIn: 3600 });
        const cleanEndpoint = endpoint.replace(/\/$/, "");
        const publicUrl = `${cleanEndpoint}/${bucket}/${key}`;
        return { uploadUrl: url, publicUrl: publicUrl, key: key };
    } catch (error) {
        throw new HttpsError("internal", error.message);
    }
});

exports.submitGarageRequest = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    const { name, phone, aadhaar, city, district, state, location, photoUrls } = request.data;
    
    await db.execute({
        sql: "INSERT INTO garage_requests (user_uid, name, phone, aadhaar, city, district, state, location, photo_urls, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        args: [
            request.auth.uid, 
            name, 
            phone, 
            aadhaar, 
            city, 
            district, 
            state, 
            location, 
            JSON.stringify(photoUrls || []), 
            "pending", 
            Date.now()
        ]
    });
    return { status: "success" };
});

exports.getGarageRequestStatus = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    const res = await db.execute({
        sql: "SELECT * FROM garage_requests WHERE user_uid = ? ORDER BY id DESC LIMIT 1",
        args: [request.auth.uid]
    });
    return { status: "success", request: res.rows[0] || null };
});

exports.getGarageRequestsAdmin = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    if (!(await isAdmin(request, db))) throw new HttpsError("permission-denied", "Admin access only");
    
    const res = await db.execute("SELECT * FROM garage_requests ORDER BY id DESC");
    const requests = res.rows.map(row => {
        const obj = {};
        for (const key in row) { obj[key] = row[key]; }
        if (obj.photo_urls) {
            try { obj.photo_urls = JSON.parse(obj.photo_urls); } catch(e) { obj.photo_urls = []; }
        } else {
            obj.photo_urls = [];
        }
        return obj;
    });
    return { status: "success", requests: requests };
});

exports.updateGarageRequestStatus = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    if (!(await isAdmin(request, db))) throw new HttpsError("permission-denied", "Admin access only");

    const { id, status } = request.data;
    
    // 1. Update the request status
    await db.execute({
        sql: "UPDATE garage_requests SET status = ? WHERE id = ?",
        args: [status, id]
    });

    // 2. If approved, promote user to garage_owner
    if (status === 'approved') {
        const reqRes = await db.execute({ sql: "SELECT user_uid FROM garage_requests WHERE id = ?", args: [id] });
        if (reqRes.rows.length > 0) {
            const userUid = reqRes.rows[0].user_uid;
            await db.execute({
                sql: "UPDATE users SET role = 'garage_owner' WHERE firebase_uid = ?",
                args: [userUid]
            });
            // INCREMENT DEDICATED STAT TABLE
            await db.execute("UPDATE platform_stats SET stat_value = stat_value + 1 WHERE stat_key = 'active_garages'");
        }
    }

    return { status: "success" };
});

exports.getGarageJobs = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    const res = await db.execute({
        sql: "SELECT jobs.*, users.display_name FROM jobs JOIN users ON jobs.customer_uid = users.firebase_uid WHERE garage_uid = ? ORDER BY created_at DESC",
        args: [request.auth.uid]
    });
    return { status: "success", jobs: res.rows };
});

exports.getNotifications = onCall({ 
    secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
    cors: true
}, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const db = getDb();
    const res = await db.execute({
        sql: "SELECT * FROM notifications WHERE user_uid = ? ORDER BY created_at DESC",
        args: [request.auth.uid]
    });
    return { status: "success", notifications: res.rows };
});
