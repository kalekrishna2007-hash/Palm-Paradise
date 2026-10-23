# Vercel deployment — Palm Paradise

## Current state (Turso migration complete)

- **Database: Turso (hosted libSQL).** The `/tmp` SQLite file is gone — bookings,
  reviews and banquet edits are now durable across cold starts and redeploys.
- Driver: `@libsql/client` (`better-sqlite3` and `@types/better-sqlite3` removed).
- Production URL verified this session: **https://palmparadisekopargaon.vercel.app**
  (the project's other `*.vercel.app` aliases sit behind Vercel Deployment
  Protection and return 302 to anonymous requests).

### Vercel environment variables (Production)

| Name | Purpose |
| --- | --- |
| `ADMIN_USERNAME` | admin login user |
| `ADMIN_PASSWORD` | admin login password |
| `SESSION_SECRET` | signs the `pp_admin_session` cookie |
| `NEXT_PUBLIC_SITE_URL` | canonical/OG base URL (must be set) |
| `TURSO_DATABASE_URL` | `libsql://…turso.io` database URL |
| `TURSO_AUTH_TOKEN` | Turso auth token for that database |

`TURSO_DATABASE_URL` / `TURSO_AUTH_TOKEN` are read by `src/lib/db.ts` at startup
and are **required at build time too**, because `/` and `/banquets/[slug]` are
prerendered and read the database during `next build`. Missing/invalid values
fail the build (a bad token surfaces as `LibsqlError: SERVER_ERROR … HTTP 401`).

Locally the same two values live in `.env.local` (git-ignored); admin secrets
live in `.env`.

## Database layer notes (`src/lib/db.ts`)

- One `Client` per process, memoised as a **promise** (`getClient()`), so
  concurrent first requests share a single migrate+seed instead of racing.
  A failed init is not cached, so a transient network error can recover.
- Turso executes one statement per call, so the schema is `split(";")` into
  individual statements and run in a loop. All are `IF NOT EXISTS`, so this is
  a no-op after the first boot.
- The `booking_request.source` column migration relies on SQLite having no
  `ADD COLUMN IF NOT EXISTS`: the `duplicate column name` error is the
  already-applied signal. Any other error is re-thrown.
- **The double-booking guard is unchanged**: the partial unique index
  `idx_booking_confirmed_unique ON booking_request(banquet_id, event_date)
  WHERE status = 'CONFIRMED'` is created on Turso and verified working
  (a second CONFIRMED booking for the same hall+date returns 409).
- `setBookingStatus` uses an interactive `client.transaction("write")` with an
  explicit `commit()`/`rollback()`. Note `Transaction.execute()` accepts only
  the `{ sql, args }` form (no `(sql, args)` overload).
- **Constraint-error detection must not be simplified.** better-sqlite3 reported
  the precise code `SQLITE_CONSTRAINT_UNIQUE`; Turso/libSQL reports the general
  `SQLITE_CONSTRAINT` code and puts the detail in the **message**
  (`UNIQUE constraint failed: …`). `isUniqueViolation()` therefore requires
  both a `SQLITE_CONSTRAINT` code and a `UNIQUE constraint failed` message —
  a FOREIGN KEY or CHECK failure also reports `SQLITE_CONSTRAINT` and must not
  be reported as a booking conflict.
- Foreign-key enforcement is active on Turso (a bad `banquet_id` is rejected).

## Verified live (this session)

Local production build (`next start`) **and** the deployed site:

- 13/13 admin checks pass (`admin-check.sh` exits 0): `/admin` 307 → login →
  session cookie → `/api/admin/me` → dashboard sections → logout → 307.
- Public pages 200: `/`, `/banquets`, both hall detail pages, `/book`,
  `/gallery`, `/contact`, `/legal`.
- Public booking POST → 201 with a `PP-######` reference; the row is visible in
  the admin dashboard.
- Two PENDING bookings may share a hall+date; confirming the second → **409**.
- Offline (admin) booking inserts as CONFIRMED/OFFLINE → 201; a duplicate
  offline lock for the same hall+date → **409**.
- Review POST → 201, admin approve → 200, and the approved review appears on
  the dynamic `/admin/reviews` page.
- Rows written through the **production** site were read back directly from
  Turso, confirming production and local point at the same database.
- All test rows were deleted afterwards; the database is left in its seeded
  state (hotel 1, banquets 2, bookings 0, reviews 0).

## Known limitations

1. **Static pages don't self-refresh.** `/`, `/banquets`, `/book`, `/gallery`,
   `/contact`, `/legal` and the hall detail pages are prerendered at build
   time, so a review approved in the admin panel appears on the site only
   after the next build/redeploy. (Pre-existing behaviour, not caused by the
   Turso move — but now that the DB is durable it is worth fixing with
   `revalidatePath`/`revalidate` on the review and booking routes.)
2. **`palmparadise.com` does not reach this app.** Vercel has the domain
   recorded against the project, but its nameservers are third-party and it
   currently 301-redirects to an unrelated site. Attach it properly before
   advertising it.
3. **Stale alias.** `palm-and-paradise-vortex-b788.vercel.app` still points at
   the 6-day-old deployment, and `palm-and-paradise.vercel.app` returns a
   Vercel 404 — that older URL no longer belongs to this project. The aliases
   for the current build are **palmparadisekopargaon.vercel.app** (public) and
   `palm-paradise-vortex-b788.vercel.app` (behind Deployment Protection).
4. `engines: { "node": "22.x" }` in `package.json` is still in place. It is no
   longer load-bearing now that the native `better-sqlite3` module is gone,
   but keeping it pinned avoids surprises from Node major upgrades.

---

## Rate limiting (updated — was in-process, now durable)

`src/lib/http.ts` previously kept a counter in a module-level `Map`. On
serverless that meant one counter per warm instance and a full reset on every
cold start, so the limit was near-meaningless in production.

It is now backed by the `rate_limit` table in Turso:

- The increment is a single atomic upsert
  (`INSERT … ON CONFLICT(key) DO UPDATE … RETURNING count`), so concurrent
  requests for the same key cannot lose a count.
- Keys are salted (`SESSION_SECRET`) SHA-256 hashes, so the table never holds
  raw client IPs. Rotating `SESSION_SECRET` starts fresh counters.
- **Fails open**: if Turso is unreachable the request is allowed and a warning
  is logged. A false 429 would silently drop a real enquiry.
- Expired counters are pruned on roughly 1 request in 50; a prune failure is
  logged and never affects the request being served.

Verified: 5 requests allowed, the 6th returns 429, the counter reads back as
`count=6` in Turso, and — after killing the server and starting a fresh
process — the same client is **still** throttled. The old implementation reset
in that scenario.

## Image uploads (Vercel Blob)

Admin → Banquet Halls → Edit Hall → Photography now accepts real file uploads
(drag-and-drop or file picker, multiple at once) in addition to pasted URLs.

- **Store**: Vercel Blob, created as `palm-paradise-images` (`store_wCBqMEoCaonBZ6qj`,
  public access, iad1) and connected to the project for all three environments.
  `vercel storage connect` wrote `BLOB_READ_WRITE_TOKEN`, `BLOB_STORE_ID` and
  `BLOB_WEBHOOK_PUBLIC_KEY`; it was connected with `--auth oidc --add-rw-token`
  so deployments use OIDC while local dev uses the static token.
- **Route**: `POST /api/admin/uploads` — admin session + same-origin required.
  Rejects anything over 4 MB (a backstop under Vercel's ~4.5 MB request-body
  limit) and **identifies the image from its magic bytes**, not the
  browser-supplied content type. Verified: a text file renamed `.jpg` is
  rejected, and a PNG renamed `.jpg` is stored as `image/png`.
- **Client**: `BanquetEditForm` downscales in the browser first (longest edge
  2000 px, WebP ~85%) so photos stay small and fast to serve; a photo already
  under 600 KB and 2000 px is passed through untouched to preserve quality.
- Uploading does not require saving: the returned URL is appended to the list,
  and Save persists it.

### Bug fixed along the way

`banquetUpdateSchema` required `z.string().url()` for every image, but the
seeded halls use site-relative `/images/…` paths. **Saving any seeded hall
returned `400 "Each image must be a valid URL"`** — the admin edit page was
effectively read-only. The schema (and the form's own "add photo" check, which
claimed to accept `/images/…` but didn't) now accept an https URL **or** a
site-relative path. Verified in a real browser: Save Changes on The Palm
Ballroom now issues `PUT /api/admin/banquets/1 → 200`.

## Additional limitations found

1. **Preview deployments will not build.** `TURSO_DATABASE_URL` /
   `TURSO_AUTH_TOKEN` are set for Production only. A preview build prerenders
   `/` and `/banquets/[slug]`, so it fails without database credentials.
   Deliberately not fixed by sharing the production values with Preview —
   that would let preview runs write to live booking data. The correct fix is
   a separate Turso database for preview.
2. **Uploaded photos are not deleted when removed from a hall.** Removing an
   image only drops it from the hall's list; the blob is orphaned. There is no
   cleanup job yet.
3. **The Blob list/delete API rejects the token from outside a Vercel
   runtime** (`BLOB_READ_WRITE_TOKEN` works for writes from the app and the
   CDN serves reads publicly, but `list`/`del` return "Access denied" via both
   the CLI and the SDK locally). Test uploads therefore remain in the store and
   must be removed from the Vercel dashboard: Storage → `palm-paradise-images`.
