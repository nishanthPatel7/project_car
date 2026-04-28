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
      args: [request.auth.uid],
    });
    return rs.rows[0] && (rs.rows[0].role === "admin" || rs.rows[0].role === "garage_owner");
  } catch (e) {
    console.error("Auth Check Error:", e);
    return false;
  }
};

exports.getInitialState = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
  cpu: 0.1,
  memory: "128MiB",
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
    "ALTER TABLE inventory ADD COLUMN created_at INTEGER",
  ];

  for (const sql of migrations) {
    try {
      await db.execute(sql);
    } catch (e) {/* Col exists */ }
  }

  const jobMigrations = [
    "ALTER TABLE jobs ADD COLUMN vehicle_type TEXT",
    "ALTER TABLE jobs ADD COLUMN brand TEXT",
    "ALTER TABLE jobs ADD COLUMN address TEXT",
    "ALTER TABLE jobs ADD COLUMN garage_uid TEXT",
    "ALTER TABLE jobs ADD COLUMN garage_id TEXT",
    "ALTER TABLE jobs ADD COLUMN total_amount INTEGER",
    "ALTER TABLE jobs ADD COLUMN cost_details TEXT",
    "ALTER TABLE jobs ADD COLUMN invoice_no TEXT",
    "ALTER TABLE jobs ADD COLUMN customer_name TEXT",
  ];

  for (const sql of jobMigrations) {
    try {
      await db.execute(sql);
    } catch (e) {/* Col exists */ }
  }

  try {
    await db.execute(`CREATE TABLE IF NOT EXISTS vehicles (id INTEGER PRIMARY KEY AUTOINCREMENT, customer_uid TEXT, vehicle_no TEXT, model TEXT, created_at INTEGER)`);
    await db.execute(`CREATE TABLE IF NOT EXISTS jobs (id INTEGER PRIMARY KEY AUTOINCREMENT, customer_uid TEXT, vehicle_no TEXT, problem TEXT, service_types TEXT, status TEXT, mode TEXT, vehicle_type TEXT, brand TEXT, address TEXT, garage_uid TEXT, total_amount INTEGER, cost_details TEXT, created_at INTEGER)`);
    await db.execute(`CREATE TABLE IF NOT EXISTS inventory (id INTEGER PRIMARY KEY AUTOINCREMENT, admin_uid TEXT, name TEXT, description TEXT, image_url TEXT, stock INTEGER DEFAULT 0, created_at INTEGER)`);
    await db.execute(`CREATE TABLE IF NOT EXISTS users (firebase_uid TEXT PRIMARY KEY, email TEXT, role TEXT, display_name TEXT, photo_url TEXT, partner_id TEXT)`);
    await db.execute(`CREATE TABLE IF NOT EXISTS garage_requests (id INTEGER PRIMARY KEY AUTOINCREMENT, user_uid TEXT, name TEXT, owner_name TEXT, phone TEXT, aadhaar TEXT, city TEXT, district TEXT, state TEXT, location TEXT, photo_urls TEXT, status TEXT, created_at INTEGER, partner_id TEXT)`);
    await db.execute(`CREATE TABLE IF NOT EXISTS notifications (id INTEGER PRIMARY KEY AUTOINCREMENT, user_uid TEXT, title TEXT, desc TEXT, icon TEXT, color TEXT, is_read INTEGER DEFAULT 0, created_at INTEGER)`);
    await db.execute(`CREATE TABLE IF NOT EXISTS platform_stats (stat_key TEXT PRIMARY KEY, stat_value INTEGER DEFAULT 0)`);
    await db.execute(`CREATE TABLE IF NOT EXISTS garage_stats (garage_uid TEXT PRIMARY KEY, daily_revenue INTEGER DEFAULT 0, lifetime_revenue INTEGER DEFAULT 0, daily_jobs INTEGER DEFAULT 0, lifetime_jobs INTEGER DEFAULT 0, last_reset INTEGER)`);
  } catch (e) { }

  // Migration: Add columns if they don't exist
  try {
    await db.execute("ALTER TABLE garage_requests ADD COLUMN owner_name TEXT");
  } catch (e) { }
  try {
    await db.execute("ALTER TABLE garage_requests ADD COLUMN partner_id TEXT");
  } catch (e) { }
  try {
    await db.execute("ALTER TABLE users ADD COLUMN partner_id TEXT");
  } catch (e) { }
  try {
    await db.execute("ALTER TABLE notifications ADD COLUMN is_read INTEGER DEFAULT 0");
  } catch (e) { }

  try {
    const rs = await db.execute({
      sql: "SELECT role, display_name, photo_url FROM users WHERE firebase_uid = ?",
      args: [request.auth.uid],
    });

    const isSystemAdmin = request.auth.uid === "KP3Ix19VEsgHO3Ei5HnyKmRyfN23";

    if (rs.rows.length === 0) {
      const role = isSystemAdmin ? "admin" : "customer";
      const email = request.auth.token.email || "";
      const displayName = request.auth.token.name || "New User";
      const photoUrl = request.auth.token.picture || "";

      await db.execute({
        sql: "INSERT INTO users (firebase_uid, email, role, display_name, photo_url) VALUES (?, ?, ?, ?, ?)",
        args: [request.auth.uid, email, role, displayName, photoUrl],
      });
      return { view: role, role: role, data: { name: displayName, photo: photoUrl } };
    }

    let currentRole = rs.rows[0].role;
    if (isSystemAdmin && currentRole !== "admin") {
      await db.execute({ sql: "UPDATE users SET role = 'admin' WHERE firebase_uid = ?", args: [request.auth.uid] });
      currentRole = "admin";
    }

    const stats = { new: 0, in_progress: 0, completed: 0, total: 0, active_garages: 0, revenue: 0 };

    if (currentRole === "garage_owner") {
      // Get all partner_ids for this owner to aggregate stats correctly
      const partnerIdsRs = await db.execute({
        sql: "SELECT partner_id FROM garage_requests WHERE user_uid = ? AND status = 'approved'",
        args: [request.auth.uid],
      });
      const partnerIds = partnerIdsRs.rows.map((r) => r.partner_id).filter(Boolean);

      // Build a filter that includes firebase_uid and ALL associated partner_ids
      // This is crucial because jobs can be linked to either.
      const identifiers = [request.auth.uid, ...partnerIds];
      const placeholders = identifiers.map(() => "?").join(",");

      const jobsRs = await db.execute({
        sql: `SELECT status, COUNT(*) as count, SUM(total_amount) as total_revenue FROM jobs WHERE garage_uid IN (${placeholders}) GROUP BY status`,
        args: identifiers
      });

      jobsRs.rows.forEach((row) => {
        const s = (row.status || "").toLowerCase();
        if (s === "pending") stats.new = Number(row.count);
        if (s === "in_progress" || s === "working" || s === "ongoing") stats.in_progress += Number(row.count);
        if (s === "completed") {
          stats.completed = Number(row.count);
          stats.revenue = Number(row.total_revenue || 0);
        }
        stats.total += Number(row.count);
      });
    } else {
      const statsRs = await db.execute({ sql: "SELECT status, COUNT(*) as count FROM jobs WHERE customer_uid = ? GROUP BY status", args: [request.auth.uid] });
      statsRs.rows.forEach((row) => {
        if (row.status === "pending") stats.new = Number(row.count);
        if (row.status === "in_progress") stats.in_progress = Number(row.count);
        if (row.status === "completed") stats.completed = Number(row.count);
        stats.total += Number(row.count);
      });
    }

    // GARAGE STATS LOGIC
    if (currentRole === "garage_owner") {
      const now = new Date();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();

      // Check if we need to reset daily stats
      // We use request.auth.uid for stats tracking record, but we'll aggregate revenue from all garages
      const statsRs = await db.execute({ sql: "SELECT * FROM garage_stats WHERE garage_uid = ?", args: [request.auth.uid] });
      if (statsRs.rows.length === 0) {
        await db.execute({
          sql: "INSERT INTO garage_stats (garage_uid, daily_revenue, lifetime_revenue, daily_jobs, lifetime_jobs, last_reset) VALUES (?, 0, 0, 0, 0, ?)",
          args: [request.auth.uid, startOfDay],
        });
      } else {
        const sRow = statsRs.rows[0];
        if (sRow.last_reset < startOfDay) {
          await db.execute({
            sql: "UPDATE garage_stats SET daily_revenue = 0, daily_jobs = 0, last_reset = ? WHERE garage_uid = ?",
            args: [startOfDay, request.auth.uid],
          });
        }
      }

      // 3. Update stats object with values from the database
      const sRow = statsRs.rows[0];
      stats.daily_revenue = Number(sRow.daily_revenue || 0);
      stats.lifetime_revenue = Number(sRow.lifetime_revenue || 0);
      stats.daily_jobs = Number(sRow.daily_jobs || 0);
      stats.lifetime_jobs = Number(sRow.lifetime_jobs || 0);

      // 4. Verification: If daily stats are 0, try a live check as a fallback 
      // (This handles cases where the garage_stats table might be out of sync)
      if (stats.daily_jobs === 0) {
        const liveStats = await db.execute({
          sql: `SELECT 
                  COUNT(*) as daily_jobs,
                  SUM(total_amount) as daily_revenue
                FROM jobs 
                WHERE garage_uid IN (${placeholders}) AND LOWER(status) = 'completed' AND created_at >= ?`,
          args: [...ids, startOfDay],
        });
        const lRow = liveStats.rows[0];
        if (Number(lRow.daily_jobs || 0) > 0) {
          stats.daily_revenue = Number(lRow.daily_revenue || 0);
          stats.daily_jobs = Number(lRow.daily_jobs || 0);
        }
      }
    }

    // ADMIN STATS OVERRIDE
    if (currentRole === "admin") {
      const garageCountRs = await db.execute("SELECT COUNT(*) as count FROM users WHERE role = 'garage_owner'");
      const garageCount = Number(garageCountRs.rows[0].count);
      await db.execute({
        sql: "INSERT INTO platform_stats (stat_key, stat_value) VALUES (?, ?) ON CONFLICT(stat_key) DO UPDATE SET stat_value = ?",
        args: ["active_garages", garageCount, garageCount],
      });
      stats.active_garages = garageCount;
    }

    // 1. Fetch personal customer data (Safely)
    let activeJobs = [];
    try {
      const aRs = await db.execute({
        sql: `SELECT 
                        j.id, j.vehicle_no, j.problem, j.service_types, j.status, j.mode, 
                        j.vehicle_type, j.brand, j.address, j.garage_uid, j.garage_id, j.total_amount, 
                        j.cost_details, j.invoice_no, j.created_at,
                        g.name as garage_name 
                      FROM jobs j 
                      LEFT JOIN garage_requests g ON (j.garage_uid = g.user_uid OR j.garage_id = g.partner_id) 
                      WHERE j.customer_uid = ? AND j.status IN ('pending', 'working', 'in_progress', 'ongoing') 
                      ORDER BY j.created_at DESC`,
        args: [request.auth.uid],
      });
      activeJobs = aRs.rows;
    } catch (e) {
      console.error("Error fetching activeJobs:", e);
    }

    let historyJobs = [];
    try {
      const hRs = await db.execute({
        sql: `SELECT 
                        j.id, j.vehicle_no, j.problem, j.service_types, j.status, j.mode, 
                        j.vehicle_type, j.brand, j.address, j.garage_uid, j.total_amount, 
                        j.cost_details, j.invoice_no, j.created_at,
                        g.name as garage_name 
                      FROM jobs j 
                      LEFT JOIN garage_requests g ON j.garage_uid = g.user_uid 
                      WHERE j.customer_uid = ? AND j.status = 'completed' 
                      ORDER BY j.created_at DESC LIMIT 10`,
        args: [request.auth.uid],
      });
      historyJobs = hRs.rows;
    } catch (e) {
      console.error("Error fetching historyJobs:", e);
    }

    let vehicles = [];
    try {
      const vRs = await db.execute({ sql: "SELECT * FROM vehicles WHERE customer_uid = ?", args: [request.auth.uid] });
      vehicles = vRs.rows;
    } catch (e) {
      console.error("Error fetching vehicles:", e);
    }

    // 2. Fetch Workshop data if user is a garage owner (Safely)
    let newJobs = [];
    let ongoingJobs = [];

    if (currentRole === "garage_owner") {
      const garageId = request.data.garageId;

      try {
        // 1. Ensure table has all columns to prevent crashes
        const columnsRs = await db.execute("PRAGMA table_info(jobs)");
        const columnNames = columnsRs.rows.map((r) => r.name);
        if (!columnNames.includes("customer_name")) await db.execute("ALTER TABLE jobs ADD COLUMN customer_name TEXT");
        if (!columnNames.includes("invoice_no")) await db.execute("ALTER TABLE jobs ADD COLUMN invoice_no TEXT");

        // 2. Fetch all identifiers for this user
        const partnerIdsRs = await db.execute({
          sql: "SELECT partner_id FROM garage_requests WHERE user_uid = ? AND status = 'approved'",
          args: [request.auth.uid],
        });
        const partnerIds = partnerIdsRs.rows.map((r) => r.partner_id).filter(Boolean);

        // IMPORTANT: Even if a specific garageId (Partner ID) is provided, 
        // we should ALSO search for jobs under the owner's UID because 
        // app bookings often use the UID as the garage_uid.
        let identifiers;
        if (garageId) {
          // If garageId matches a partner_id, we search for that partner_id OR the owner's UID.
          // This is the safest way to ensure no jobs are missed.
          identifiers = [garageId, request.auth.uid];
        } else {
          identifiers = [request.auth.uid, ...partnerIds];
        }
        const placeholders = identifiers.map(() => "?").join(",");

        // Use LEFT JOIN users to ensure walk-in jobs (null customer_uid) appear
        const nRs = await db.execute({
          sql: `SELECT jobs.*, COALESCE(users.display_name, jobs.customer_name) as display_name, users.photo_url 
                FROM jobs 
                LEFT JOIN users ON jobs.customer_uid = users.firebase_uid 
                WHERE (jobs.garage_uid IN (${placeholders}) OR jobs.garage_id IN (${placeholders})) 
                AND LOWER(jobs.status) = 'pending' 
                ORDER BY created_at DESC`,
          args: [...identifiers, ...identifiers],
        });
        newJobs = nRs.rows;

        const oRs = await db.execute({
          sql: `SELECT jobs.*, COALESCE(users.display_name, jobs.customer_name) as display_name, users.photo_url 
                FROM jobs 
                LEFT JOIN users ON jobs.customer_uid = users.firebase_uid 
                WHERE (jobs.garage_uid IN (${placeholders}) OR jobs.garage_id IN (${placeholders})) 
                AND LOWER(jobs.status) IN ('working', 'in_progress', 'ongoing') 
                ORDER BY created_at DESC`,
          args: [...identifiers, ...identifiers],
        });
        ongoingJobs = oRs.rows;
      } catch (e) {
        console.error("Error fetching workshop data:", e);
      }
    }

    let unreadCountUser = 0;
    let unreadCountGarage = 0;
    let unreadCountAdmin = 0;
    try {
      const unreadUserRs = await db.execute({
        sql: "SELECT COUNT(*) as count FROM notifications WHERE user_uid = ? AND is_read = 0 AND module = 'user'",
        args: [request.auth.uid],
      });
      unreadCountUser = Number(unreadUserRs.rows[0].count);

      const unreadGarageRs = await db.execute({
        sql: "SELECT COUNT(*) as count FROM notifications WHERE user_uid = ? AND is_read = 0 AND module = 'garage'",
        args: [request.auth.uid],
      });
      unreadCountGarage = Number(unreadGarageRs.rows[0].count);

      const unreadAdminRs = await db.execute({
        sql: "SELECT COUNT(*) as count FROM notifications WHERE user_uid = ? AND is_read = 0 AND module = 'admin'",
        args: [request.auth.uid],
      });
      unreadCountAdmin = Number(unreadAdminRs.rows[0].count);
    } catch (e) {
      console.error("Error fetching unread notifications:", e);
    }

    return {
      view: currentRole,
      role: currentRole,
      status: "success",
      data: {
        name: rs.rows[0].display_name || "User",
        photo: rs.rows[0].photo_url || "",
        stats: stats,
        vehicles: vehicles,
        activeJobs: activeJobs,
        historyJobs: historyJobs,
        newJobs: newJobs,
        ongoingJobs: ongoingJobs,
        unreadNotifications: unreadCountUser,
        unreadNotifications_user: unreadCountUser,
        unreadNotifications_garage: unreadCountGarage,
        unreadNotifications_admin: unreadCountAdmin,
      },
    };
  } catch (error) {
    console.error("getInitialState Fatal Error:", error);
    throw new HttpsError("internal", error.message);
  }
});


exports.addVehicle = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
  cpu: 0.1,
  memory: "128MiB",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  const { vehicleNo, model } = request.data;
  await db.execute({
    sql: "INSERT INTO vehicles (customer_uid, vehicle_no, model, created_at) VALUES (?, ?, ?, ?)",
    args: [request.auth.uid, vehicleNo, model, Date.now()],
  });
  return { status: "success" };
});

exports.addInventoryItem = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();

  if (!(await isAdmin(request, db))) throw new HttpsError("permission-denied", "Admin access only");

  const { name, description, imageUrl, stock } = request.data;
  const columnsRs = await db.execute("PRAGMA table_info(inventory)");
  const columnNames = columnsRs.rows.map((r) => r.name);

  const dataMap = {
    admin_uid: request.auth.uid,
    name: name,
    part_name: name,
    description: description,
    image_url: imageUrl || "",
    stock: Number(stock) || 0,
    created_at: Date.now(),
  };

  const insertCols = [];
  const insertVals = [];
  const placeholders = [];

  for (const col of columnNames) {
    if (col === "id") continue;
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
  cors: true,
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
    if (imageUrl && imageUrl.includes("storage.googleapis.com")) {
      try {
        const fileName = imageUrl.split("/").pop().split("?")[0];
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
  cors: true,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  try {
    const db = getDb();
    const res = await db.execute({
      sql: "SELECT * FROM inventory WHERE admin_uid = ? ORDER BY id DESC LIMIT 100",
      args: [request.auth.uid],
    });
    const items = res.rows.map((row) => {
      const obj = {};
      for (const key in row) {
        obj[key] = row[key];
      }
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
  cors: true,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  if (!(await isAdmin(request, db))) throw new HttpsError("permission-denied", "Admin access only");

  const { id, adjustment } = request.data;
  await db.execute({
    sql: "UPDATE inventory SET stock = stock + ? WHERE id = ?",
    args: [adjustment, id],
  });
  return { status: "success" };
});

exports.uploadInventoryImage = onRequest({
  cors: true,
}, async (req, res) => {
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");
  try {
    const bodyData = req.body.data || req.body;
    const { fileName, contentType, base64Data } = bodyData;
    if (!base64Data) return res.status(400).json({ data: { status: "error", message: "Missing image data" } });

    const bucket = admin.storage().bucket();
    const file = bucket.file(`inventory/${Date.now()}-${fileName}`);
    await file.save(Buffer.from(base64Data, "base64"), {
      metadata: { contentType },
      public: true,
      resumable: false,
    });
    await file.makePublic();
    return res.json({ data: { status: "success", publicUrl: `https://storage.googleapis.com/${bucket.name}/${file.name}` } });
  } catch (error) {
    console.error("Upload Error:", error);
    return res.status(500).json({ data: { status: "error", message: error.message } });
  }
});

exports.submitJob = onCall({ region: "asia-south1", cpu: 0.1, memory: "128MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  const { vehicleNo, problemDesc, serviceTypes, mode, vehicleType, brand, address, totalAmount, costDetails } = request.data;
  let invoiceNo = request.data.invoiceNo;

  // DEFENSIVE: Invoice generation
  if (!invoiceNo || invoiceNo === "Loading...") {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let isUnique = false;
    while (!isUnique) {
      invoiceNo = "";
      for (let i = 0; i < 8; i++) invoiceNo += chars.charAt(Math.floor(Math.random() * chars.length));
      const rs = await db.execute({ sql: "SELECT id FROM jobs WHERE invoice_no = ?", args: [invoiceNo] });
      if (rs.rows.length === 0) isUnique = true;
    }
  }

  try {
    // 1. Ensure table schema is up to date (Self-Healing)
    const tableInfo = await db.execute("PRAGMA table_info(jobs)");
    const columns = tableInfo.rows.map((r) => r.name);

    const requiredColumns = [
      { name: "service_types", type: "TEXT" },
      { name: "status", type: "TEXT" },
      { name: "mode", type: "TEXT" },
      { name: "problem", type: "TEXT" },
      { name: "brand", type: "TEXT" },
      { name: "vehicle_type", type: "TEXT" },
      { name: "address", type: "TEXT" },
      { name: "garage_uid", type: "TEXT" },
      { name: "garage_id", type: "TEXT" },
      { name: "total_amount", type: "INTEGER" },
      { name: "cost_details", type: "TEXT" },
      { name: "invoice_no", type: "TEXT" },
      { name: "customer_name", type: "TEXT" },
    ];

    for (const col of requiredColumns) {
      if (!columns.includes(col.name)) {
        await db.execute(`ALTER TABLE jobs ADD COLUMN ${col.name} ${col.type}`);
      }
    }

    // 2. Resolve Identities
    // Use request.auth.uid as default customer (supports owner as user)
    let customerUid = request.auth.uid; 
    let resolvedGarageUid = null;
    let resolvedPartnerId = null;

    const inputGarageId = request.data.garage_uid;
    if (inputGarageId) {
      const garageLookup = await db.execute({
        sql: "SELECT user_uid, partner_id FROM garage_requests WHERE partner_id = ? OR user_uid = ? LIMIT 1",
        args: [inputGarageId, inputGarageId]
      });
      if (garageLookup.rows.length > 0) {
        resolvedGarageUid = garageLookup.rows[0].user_uid;
        resolvedPartnerId = garageLookup.rows[0].partner_id;
      } else {
        const userLookup = await db.execute({
          sql: "SELECT firebase_uid, partner_id FROM users WHERE firebase_uid = ? OR partner_id = ? LIMIT 1",
          args: [inputGarageId, inputGarageId]
        });
        resolvedGarageUid = userLookup.rows[0]?.firebase_uid || inputGarageId;
        resolvedPartnerId = userLookup.rows[0]?.partner_id;
      }
    } else if (request.data.mode === "Walk-in") {
      resolvedGarageUid = request.auth.uid;
      const ownerLookup = await db.execute({ sql: "SELECT partner_id FROM users WHERE firebase_uid = ?", args: [request.auth.uid] });
      resolvedPartnerId = ownerLookup.rows[0]?.partner_id;
      customerUid = null; 
    }

    await db.execute({
      sql: "INSERT INTO jobs (customer_uid, vehicle_no, problem, service_types, status, mode, vehicle_type, brand, address, garage_uid, garage_id, total_amount, cost_details, invoice_no, customer_name, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      args: [
        customerUid,
        vehicleNo,
        problemDesc,
        JSON.stringify(serviceTypes || []),
        request.data.status || "pending",
        mode || "Walk-in",
        vehicleType || "Car",
        brand || "",
        address || "",
        resolvedGarageUid,
        resolvedPartnerId,
        totalAmount || 0,
        costDetails ? JSON.stringify(costDetails) : null,
        invoiceNo,
        request.data.customerName || "Customer",
        Date.now(),
      ],
    });

    // 3. Update Stats (Original query format)
    if (request.data.status === "completed" && resolvedGarageUid) {
      const amount = totalAmount || 0;
      await db.execute({
        sql: "UPDATE garage_stats SET daily_revenue = daily_revenue + ?, lifetime_revenue = lifetime_revenue + ?, daily_jobs = daily_jobs + 1, lifetime_jobs = lifetime_jobs + 1 WHERE garage_uid = ? OR garage_uid = (SELECT partner_id FROM users WHERE firebase_uid = ?)",
        args: [amount, amount, resolvedGarageUid, resolvedGarageUid],
      });
    }

    // 4. Notify Garage Owner
    if (resolvedGarageUid && request.data.status !== "completed" && resolvedGarageUid !== request.auth.uid) {
      await db.execute({
        sql: "INSERT INTO notifications (user_uid, title, desc, icon, color, is_read, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        args: [
          resolvedGarageUid,
          "New Job Request",
          `New service request received for vehicle [${vehicleNo}].`,
          "add_task_rounded",
          "primary",
          0,
          Date.now(),
        ],
      });
    }

    return { status: "success" };
  } catch (e) {
    console.error("submitJob Fatal Error:", e);
    return { status: "error", message: e.toString() };
  }
});

exports.generateInvoiceNo = onCall({ region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();

  // Fetch user's partner_id
  const userRs = await db.execute({
    sql: "SELECT partner_id FROM users WHERE firebase_uid = ?",
    args: [request.auth.uid],
  });
  const partnerId = userRs.rows[0]?.partner_id || "GUEST";

  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let invoiceNo = "";
  let isUnique = false;
  let attempts = 0;

  while (!isUnique && attempts < 10) {
    let randomPart = "";
    for (let i = 0; i < 5; i++) {
      randomPart += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    invoiceNo = `${partnerId.toUpperCase()}-${randomPart}`;

    try {
      const rs = await db.execute({
        sql: "SELECT id FROM jobs WHERE invoice_no = ?",
        args: [invoiceNo],
      });
      if (rs.rows.length === 0) isUnique = true;
    } catch (e) {
      isUnique = true;
    }
    attempts++;
  }

  return { status: "success", invoiceNo };
});

exports.getUploadUrl = onCall({
  secrets: ["R2_ACCESS_KEY", "R2_SECRET_KEY", "R2_ENDPOINT", "R2_BUCKET_NAME"],
  cors: true,
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
  cors: true,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  const { name, ownerName, phone, city, district, state, location, photoUrls } = request.data;

  await db.execute({
    sql: "INSERT INTO garage_requests (user_uid, name, owner_name, phone, city, district, state, location, photo_urls, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    args: [
      request.auth.uid,
      name,
      ownerName || "",
      phone,
      city,
      district,
      state,
      location,
      JSON.stringify(photoUrls || []),
      "pending",
      Date.now(),
    ],
  });

  // --- ADD NOTIFICATION FOR USER ---
  await db.execute({
    sql: "INSERT INTO notifications (user_uid, title, desc, icon, color, is_read, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
    args: [
      request.auth.uid,
      "Application Submitted",
      `Your request for "${name}" has been received and is under review.`,
      "history_edu_rounded",
      "primary",
      0,
      Date.now(),
    ],
  });

  // --- ADD NOTIFICATION FOR ADMINS ---
  try {
    const admins = await db.execute("SELECT firebase_uid FROM users WHERE role = 'admin'");
    for (const admin of admins.rows) {
      await db.execute({
        sql: "INSERT INTO notifications (user_uid, title, desc, icon, color, is_read, created_at, module) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        args: [
          admin.firebase_uid,
          "New Garage Request",
          `A new garage application for "${name}" is waiting for approval.`,
          "admin_panel_settings_rounded",
          "warning",
          0,
          Date.now(),
          "admin",
        ],
      });
    }
  } catch (e) {
    console.error("Admin notification error:", e);
  }

  return { status: "success" };
});

exports.getGarageRequestStatus = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  const res = await db.execute({
    sql: "SELECT * FROM garage_requests WHERE user_uid = ? ORDER BY id DESC",
    args: [request.auth.uid],
  });
  return { status: "success", requests: res.rows };
});

exports.getGarageRequestsAdmin = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
  cpu: 0.1,
  memory: "128MiB",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  if (!(await isAdmin(request, db))) throw new HttpsError("permission-denied", "Admin access only");

  const res = await db.execute("SELECT * FROM garage_requests ORDER BY id DESC");
  const requests = res.rows.map((row) => {
    const obj = {};
    for (const key in row) {
      obj[key] = row[key];
    }
    if (obj.photo_urls) {
      try {
        obj.photo_urls = JSON.parse(obj.photo_urls);
      } catch (e) {
        obj.photo_urls = [];
      }
    } else {
      obj.photo_urls = [];
    }
    return obj;
  });
  return { status: "success", requests: requests };
});

exports.updateGarageRequestStatus = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
  cpu: 0.1,
  memory: "128MiB",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  if (!(await isAdmin(request, db))) throw new HttpsError("permission-denied", "Admin access only");

  const { id, status } = request.data;

  // 0. Check if already approved to prevent duplicates
  const checkStatus = await db.execute({ sql: "SELECT status FROM garage_requests WHERE id = ?", args: [id] });
  if (checkStatus.rows.length > 0 && checkStatus.rows[0].status === "approved" && status === "approved") {
    return { status: "success", message: "Already approved" };
  }

  // 1. Update the request status
  await db.execute({
    sql: "UPDATE garage_requests SET status = ? WHERE id = ?",
    args: [status, id],
  });

  const reqRes = await db.execute({ sql: "SELECT user_uid, name FROM garage_requests WHERE id = ?", args: [id] });
  if (reqRes.rows.length > 0) {
    const userUid = reqRes.rows[0].user_uid;
    const garageName = reqRes.rows[0].name;

    // 2. If approved, promote user to garage_owner and assign unique 5-char Partner ID
    if (status === "approved") {
      // Generate Unique 5-char ID (A-Z, a-z, 0-9)
      const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
      let partnerId = "";
      let isUnique = false;
      while (!isUnique) {
        partnerId = "";
        for (let i = 0; i < 5; i++) {
          partnerId += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        const check = await db.execute({ sql: "SELECT firebase_uid FROM users WHERE partner_id = ?", args: [partnerId] });
        if (check.rows.length === 0) isUnique = true;
      }

      await db.execute({
        sql: "UPDATE users SET role = 'garage_owner', partner_id = ? WHERE firebase_uid = ?",
        args: [partnerId, userUid],
      });

      await db.execute({
        sql: "UPDATE garage_requests SET partner_id = ? WHERE id = ?",
        args: [partnerId, id],
      });

      // 3. Send Notification to User
      await db.execute({
        sql: "INSERT INTO notifications (user_uid, title, desc, icon, color, is_read, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        args: [
          userUid,
          "Garage Approved!",
          `"${garageName}" is now active! Your Partner ID is ${partnerId.toUpperCase()}.`,
          "verified_user_rounded",
          "success",
          0,
          Date.now(),
        ],
      });

      // INCREMENT DEDICATED STAT TABLE
      await db.execute("UPDATE platform_stats SET stat_value = stat_value + 1 WHERE stat_key = 'active_garages'");
    } else if (status === "rejected") {
      // Send Rejection Notification
      await db.execute({
        sql: "INSERT INTO notifications (user_uid, title, desc, icon, color, is_read, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        args: [
          userUid,
          "Application Update",
          `Regrettably, your request for "${garageName}" could not be approved at this time.`,
          "error_outline_rounded",
          "danger",
          0,
          Date.now(),
        ],
      });
    }
  }

  return { status: "success" };
});

exports.getUserJobs = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  const res = await db.execute({
    sql: `SELECT 
                j.*, 
                g.name as garage_name,
                g.city as garage_city,
                g.district as garage_district,
                g.state as garage_state,
                COALESCE(u.display_name, j.customer_name) as display_name
              FROM jobs j 
              LEFT JOIN garage_requests g ON (j.garage_uid = g.partner_id OR j.garage_uid = g.user_uid)
              LEFT JOIN users u ON j.customer_uid = u.firebase_uid
              WHERE j.customer_uid = ? 
              ORDER BY j.created_at DESC`,
    args: [request.auth.uid],
  });
  return { status: "success", jobs: res.rows };
});

exports.getGarageJobsV2 = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  const garageId = request.data.garageId;

  try {
    // Ensure table schema is up to date (Self-Healing)
    const tableInfo = await db.execute("PRAGMA table_info(jobs)");
    const columns = tableInfo.rows.map((r) => r.name);
    if (!columns.includes("garage_id")) await db.execute("ALTER TABLE jobs ADD COLUMN garage_id TEXT");

    // Fetch ALL associated IDs for this user
    const partnerIdsRs = await db.execute({
      sql: "SELECT partner_id FROM garage_requests WHERE user_uid = ? AND status = 'approved'",
      args: [request.auth.uid],
    });
    const userProfileRs = await db.execute({
      sql: "SELECT partner_id FROM users WHERE firebase_uid = ?",
      args: [request.auth.uid],
    });
    
    const partnerIds = [
      ...partnerIdsRs.rows.map((r) => r.partner_id),
      userProfileRs.rows[0]?.partner_id
    ].filter(Boolean);
    
    // Match getInitialState logic for identifiers
    let identifiers;
    if (garageId && garageId !== "null" && garageId !== "") {
      identifiers = [garageId, request.auth.uid];
    } else {
      identifiers = [request.auth.uid, ...partnerIds];
    }

    const uniqueIds = [...new Set(identifiers)].filter(Boolean);
    const placeholders = uniqueIds.map(() => "?").join(",");

    const sql = `SELECT jobs.*, 
                        COALESCE(users.display_name, jobs.customer_name) as display_name,
                        g.city as garage_city,
                        g.district as garage_district,
                        g.state as garage_state
                 FROM jobs 
                 LEFT JOIN users ON jobs.customer_uid = users.firebase_uid 
                 LEFT JOIN garage_requests g ON (jobs.garage_uid = g.partner_id OR jobs.garage_uid = g.user_uid)
                 WHERE (jobs.garage_uid IN (${placeholders}) OR jobs.garage_id IN (${placeholders}))
                 ORDER BY created_at DESC 
                 LIMIT 100`;

    const res = await db.execute({ sql, args: [...uniqueIds, ...uniqueIds] });
    return { status: "success", jobs: res.rows };
  } catch (e) {
    console.error("getGarageJobs Error:", e);
    return { status: "error", message: e.toString(), jobs: [] };
  }
});

exports.getNotifications = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  const res = await db.execute({
    sql: "SELECT * FROM notifications WHERE user_uid = ? ORDER BY created_at DESC",
    args: [request.auth.uid],
  });
  return { status: "success", notifications: res.rows };
});

exports.markNotificationsAsRead = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
  cpu: 0.1,
  memory: "128MiB",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  await db.execute({
    sql: "UPDATE notifications SET is_read = 1 WHERE user_uid = ?",
    args: [request.auth.uid],
  });
  return { status: "success" };
});

exports.getApprovedGarages = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
  cpu: 0.1,
  memory: "128MiB",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();

  // Fetch only approved garages
  const res = await db.execute("SELECT id, user_uid, partner_id, name, owner_name, phone, city, district, state, location, photo_urls FROM garage_requests WHERE status = 'approved' ORDER BY name ASC");

  const garages = res.rows.map((row) => {
    const obj = {};
    for (const key in row) {
      obj[key] = row[key];
    }
    if (obj.photo_urls) {
      try {
        obj.photo_urls = JSON.parse(obj.photo_urls);
      } catch (e) {
        obj.photo_urls = [];
      }
    } else {
      obj.photo_urls = [];
    }
    return obj;
  });

  return { status: "success", garages: garages };
});

exports.updateJobStatus = onCall({
  secrets: ["TURSO_DATABASE_URL", "TURSO_AUTH_TOKEN"],
  cors: true,
  cpu: 0.1,
  memory: "128MiB",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const db = getDb();
  const { jobId, status, pricing } = request.data;

  // 1. Security Check: Only the assigned garage owner can update this job
  const jobCheckRs = await db.execute({ sql: "SELECT * FROM jobs WHERE id = ?", args: [jobId] });
  if (jobCheckRs.rows.length === 0) throw new HttpsError("not-found", "Job not found");
  const job = jobCheckRs.rows[0];
  const userRs = await db.execute({ sql: "SELECT partner_id FROM users WHERE firebase_uid = ?", args: [request.auth.uid] });
  const userPartnerId = userRs.rows[0]?.partner_id;

  if (job.garage_uid !== request.auth.uid && job.garage_uid !== userPartnerId) {
    throw new HttpsError("permission-denied", "You are not authorized to update this job");
  }

  // 2. Process Pricing & Stats if Completed
  if (status === "completed" && pricing) {
    const totalAmount = pricing.totalAmount || 0;
    const costDetails = pricing.costDetails || {};

    await db.execute({
      sql: "UPDATE jobs SET status = ?, total_amount = ?, cost_details = ? WHERE id = ?",
      args: [status, totalAmount, JSON.stringify(costDetails), jobId],
    });

    // UPDATE GARAGE STATS
    await db.execute({
      sql: "UPDATE garage_stats SET daily_revenue = daily_revenue + ?, lifetime_revenue = lifetime_revenue + ?, daily_jobs = daily_jobs + 1, lifetime_jobs = lifetime_jobs + 1 WHERE garage_uid = ?",
      args: [totalAmount, totalAmount, request.auth.uid],
    });
  } else {
    // Just update status
    await db.execute({
      sql: "UPDATE jobs SET status = ? WHERE id = ?",
      args: [status, jobId],
    });
  }

  // 3. Notify Customer
  const customerUid = job.customer_uid;
  const vehicleInfo = job.vehicle_no ? `[${job.vehicle_no}]` : "your vehicle";

  let title = "Job Update";
  let desc = `Status for ${vehicleInfo} is now: ${status.toUpperCase()}`;
  let icon = "settings_rounded";
  let color = "primary";

  if (status === "working") {
    title = "Mechanic is Working!";
    desc = `Service has started for ${vehicleInfo}.`;
    icon = "engineering_rounded";
    color = "warning";
  } else if (status === "completed") {
    title = "Service Completed!";
    desc = `Your ${vehicleInfo} is ready for pickup. Final amount: ₹${pricing?.totalAmount || job.total_amount}`;
    icon = "verified_user_rounded";
    color = "success";
  } else if (status === "rejected") {
    title = "Job Rejected";
    desc = `The garage is unable to service ${vehicleInfo} at this time.`;
    icon = "cancel_rounded";
    color = "danger";
  }

  await db.execute({
    sql: "INSERT INTO notifications (user_uid, title, desc, icon, color, is_read, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
    args: [customerUid, title, desc, icon, color, 0, Date.now()],
  });

  return { status: "success" };
});
