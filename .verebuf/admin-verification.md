# Freebuff Desktop

## Admin side — VERIFIED WORKING (dev server on :59591, killed, restarted for the record)

Every route was exercised on the wire with the real dev credentials:

| Route | Method | Result |
|---|---|---|
| `/admin` | GET | 307 → `/admin/login` (no session) |
| `/admin/login` | GET | 200 |
| `/api/admin/login` | POST | `200 ok` + `pp_admin_session` cookie (body field `username`/password; `email` is rejected) |
| `/api/admin/me` | GET | `{"ok":true,"role":"admin"}` |
| `/admin` | GET | **200** — dashboard renders **Banquets**, **Requests**, **Reviews**, **Calendar** sections (7/6/4/2 matches) |
| `/api/admin/bookings` | GET | `{"bookings":[]}` (0 bookings seeded) |
| `/api/admin/reviews` | GET | 1 seeded review (`Patil`, 4★, `APPROVED`) |
| `/api/admin/banquets` | GET | JSON list of the 2 seeded halls |
| `/api/admin/bookings/[id]/status` | POST | 400 on missing booking; rejects only when `Origin: http://localhost:3000` present |
| `/api/admin/bookings/1` | DELETE | 405 (as designed) |
| `/api/admin/logout` | POST | `{"ok":true}` clears session |
| `/admin` | GET after logout | 307 → `/admin/login` |

Full auth flow confirmed: unauthenticated → logged in → dashboard render → logout → back to login.

**Dev server left running** on http://localhost:59591 (restarted cleanly after the earlier build).
