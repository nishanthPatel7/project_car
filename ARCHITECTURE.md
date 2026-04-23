# Project Car Platform Architecture

## 🧬 Technology Stack
| Layer | Technology | Role |
| :--- | :--- | :--- |
| **Frontend** | Flutter | Cross-platform UI (Android, iOS, Web) |
| **Authentication** | Firebase Auth | Google OAuth 2.0 Identity Provider |
| **API / Middleware** | Firebase Functions | Serverless logic, JWT Validation, Turso Gateway |
| **Database** | Turso (libSQL) | Edge-replicated SQLite for ultra-fast Job/Inventory tracking |
| **Security** | JWT / TLS 1.3 / HTTPS | End-to-end encrypted communication |

---

## 🔒 Security Architecture

### 1. Request Authentication (JWT)
The Flutter client obtains a **Firebase ID Token** (Short-lived JWT) after Google Login. This token is passed in the `Authorization: Bearer <TOKEN>` header for every API call.
- **Backend Verification**: Firebase Functions verify the JWT signature using the Firebase Admin SDK to ensure the request is from a legitimate, logged-in user.

### 2. Authorization (RBAC)
The **User Role** (Customer, Garage, Admin) is embedded in the Firestore user profile and cached in custom claims if necessary.
- **Logic**: A "Garage" user cannot call an endpoint intended for an "Admin".

### 3. Data Integrity & Privacy
- **Turso API Tokens**: Direct access to Turso is blocked from the frontend. Only the Firebase Functions (running in a secure VPC/environment) hold the Turso DB credentials.
- **HTTPS/TLS**: All endpoints are strictly `HTTPS`. No plain-text communication is allowed.

---

## 🛰️ API Workflow: Job Creation Example
1. **Frontend**: Customer clicks "Book Service" -> App gets fresh JWT -> `POST /createJob` with payload.
2. **Middleware**: Firebase Function intercepts request -> Verifies JWT -> Extracts `uid`.
3. **Database**: Logic translates payload into a SQL query -> Executes on **Turso** -> `INSERT INTO jobs ...`.
4. **Response**: Success status returned to UI -> History updated.

---

## 🗺️ Page & API Data Mapping

### 1. Customer Context
| Page | API Endpoint | Primary Data / Variables |
| :--- | :--- | :--- |
| **Role Selection** | `POST /users/set-role` | `uid`, `role_choice` |
| **Customer Home** | `GET /jobs/customer` | `job_list[]`, `active_status`, `next_reminder` |
| **Book Service** | `POST /jobs/create` | `vehicle_no`, `issue_desc`, `service_type`, `is_pickup`, `address` |
| **View Estimate** | `GET /jobs/:id/estimate` | `parts_list`, `labor_cost`, `is_approved`, `expiry` |

### 2. Garage Context
| Page | API Endpoint | Primary Data / Variables |
| :--- | :--- | :--- |
| **Garage Dashboard** | `GET /jobs/garage` | `pending_jobs[]`, `ongoing_jobs[]`, `low_stock_alerts` |
| **Vehicle Inspection** | `POST /jobs/:id/diagnose`| `job_id`, `technician_notes`, `photos[]` |
| **Create Estimate** | `POST /jobs/:id/estimate` | `parts_used[]`, `price_per_part`, `labor_total`, `tax` |
| **Inventory Mgmt** | `GET /inventory` | `part_id`, `current_stock`, `min_threshold` |

### 3. Admin Context
| Page | API Endpoint | Primary Data / Variables |
| :--- | :--- | :--- |
| **Admin Panel** | `GET /admin/analytics` | `total_revenue`, `active_garages_count`, `monthly_growth` |
| **Garage Registry** | `GET /admin/garages` | `garage_list[]`, `onboarding_status`, `rating` |

---

## 📊 Database Schema Strategy (Turso)
We will maintain the following tables in Turso for maximum performance:
- `users`: (id, email, role, firebase_uid)
- `jobs`: (id, customer_id, garage_id, status, vehicle_number, problem_desc)
- `inventory`: (id, garage_id, part_name, stock_count, threshold)
- `estimates`: (id, job_id, total_cost, parts_list, is_approved)

---

## 🛡️ Top Security Compliance Checklist
- [x] Forced HTTPS/TLS 1.3
- [x] Secure JWT Validation on every endpoint
- [x] No sensitive logic on the Client-side
- [x] Environment Variables managed via Firebase Secrets
- [x] Least Privilege Principle for DB access
