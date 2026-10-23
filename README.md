# Palm Paradise — Hotel & Banquet Venue Website

A premium, production-ready website for **Palm Paradise**: hotel + two banquet halls, a
banquet booking/enquiry system, and a simple admin dashboard.

Built with **Next.js 15 (App Router) + TypeScript + Tailwind CSS v4 + SQLite** (better-sqlite3).

---

## Quick start

```bash
npm install
npm run dev        # http://localhost:3000
```

The SQLite database (`data/palm-paradise.db`) is created and seeded automatically on first run —
including the two banquet halls.

### Admin access

1. Copy `.env.example` to `.env` (a dev `.env` with credentials is already provided for local work).
2. **Change `ADMIN_USERNAME` / `ADMIN_PASSWORD` / `SESSION_SECRET` before going live.**
3. Visit `/admin/login` and sign in.

> ⚠️ The dev credentials in `.env` are for local development only. Never deploy with them.

---

## What's inside

### Public website
| Route | Description |
| --- | --- |
| `/` | Cinematic home page: hero, welcome, highlights, the two banquet halls, occasions, gallery preview, guest reviews |
| `/about` | Hotel story, hospitality philosophy, ambience & location |
| `/banquets` | The two banquet halls + how booking works |
| `/banquets/palm-ballroom`, `/banquets/paradise-garden` | Full hall experience: hero, capacity, facilities, suitable events, gallery, booking CTA |
| `/gallery` | Editorial gallery with category filters and fullscreen lightbox |
| `/contact` | Phone / email / address / hours, WhatsApp, directions, map |
| `/book` | Booking/enquiry form with live availability check |
| `/legal` | Privacy policy & terms |

### Booking system
- Enquiry fields: banquet, event date, event type, guest count, name, phone, optional email, message.
- Live availability check per **banquet + date** (confirmed bookings only).
- Submitting creates a **PENDING request** — it never auto-confirms.
- The exact required messages are used:
  - Available: *"Date available — continue with your enquiry."*
  - Unavailable: *"This banquet is unavailable for the selected date. Please choose another date or contact us."*
  - Confirmation conflict: *"This banquet is already booked for this date."*
  - Success: *"Thank you for contacting Palm Paradise. Your booking request has been received. Our team will get in touch with you shortly."*

### Status workflow
```
PENDING → CONFIRMED   (marks banquet + date as BOOKED)
PENDING → REJECTED    (date stays available)
CONFIRMED → CANCELLED (releases the date)
```

**Double-booking prevention is enforced by the database itself**: a partial unique index on
`(banquet_id, event_date) WHERE status = 'CONFIRMED'`. Two admins confirming simultaneously
cannot double-book — the second gets the conflict message. Pending requests never block a date,
and different banquets can be booked on the same date.

### Guest reviews
- Home page section showing **approved** reviews (stars, name, event) with a *"Share Your Experience"*
  form (name, rating, optional event, comment).
- Submissions are stored as **PENDING** and only appear publicly after admin approval — no
  moderation gap, no fake reviews. Rate-limited (5/hour/IP).

### Offline bookings (date locks)
- Admin can **lock a banquet + date as booked** for walk-in / phone orders from
  **Bookings Calendar → *Lock a Date (Offline Booking)*** (hall, date, event type, optional
  customer name / guests / notes).
- The lock is saved as a `CONFIRMED` booking with `source = OFFLINE` and immediately shows as
  booked everywhere: calendar, availability API, public booking form (blocked).
- The same database-level unique index prevents locking an already-booked date (exact
  message: *"This banquet is already booked for this date."*). Offline rows carry an
  **OFFLINE badge** in Booking Requests and the calendar popover; **Cancel** releases the date.

### Admin dashboard (`/admin`)
- **Dashboard** — pending / confirmed / upcoming / total cards, pending reviews, recent requests, upcoming events.
- **Booking Requests** — filter by banquet, status, event type, date, and search by name/phone;
  expand any row for full customer + event details; **Confirm / Reject / Cancel** with
  confirmation dialogs and a conflict warning when another confirmed booking already holds the date.
- **Bookings Calendar** — one month grid per banquet; booked dates are highlighted and show
  customer/event details when clicked (staff-only view). Also the home of the offline lock form.
- **Guest Reviews** — filter by status + search; **Approve / Reject / Delete** each review.
- **Banquet Halls** — edit each hall's name, description, capacity, seating, facilities,
  suitable events, photography, and visibility. Changes go live instantly.

### Security
- Admin routes redirect to `/admin/login`; all admin APIs return `401` without a valid session.
- HMAC-signed, httpOnly, SameSite=Lax session cookie; credentials live in `.env` (server-side only,
  never in the client bundle).
- Server-side validation (zod) on every endpoint; rate limiting on public booking submissions;
  same-origin checks on admin mutations; security headers (nosniff, frame, referrer).
- `data/*.db` and `.env` are git-ignored.

---

## Replacing placeholder content

Everything is centralised — no hunting through components:

| What | Where |
| --- | --- |
| Tagline, intro copy, contact details (phone/email/address/hours), WhatsApp, social links, highlights, occasions, event types, gallery categories | `src/lib/site.ts` |
| All photography (Unsplash placeholders) | `src/lib/images.ts` — swap `src` values or drop files into `public/images/` |
| Banquet content (names, descriptions, capacity, facilities, images) | Admin → **Banquet Halls** (stored in SQLite) |
| Admin credentials & session secret | `.env` |

> ⚠️ **Placeholder policy:** anything marked *PLACEHOLDER*, *"On request"*, or *"to be confirmed"*
> is not real client data (no awards, years, ratings, prices, addresses or capacities have been
> invented). Replace it before launch.

The text-based logo (`src/components/Logo.tsx`) is a single component — swap in the real logo there.

---

## Deployment

1. Set real values in `.env` (`ADMIN_USERNAME`, `ADMIN_PASSWORD`, `SESSION_SECRET`).
2. `npm run build && npm start` — or deploy to any Node host (Vercel, Railway, a VPS, etc.).
3. SQLite needs a writable `data/` directory; on serverless platforms prefer a hosted
   database/volume and set `DATABASE_PATH` accordingly (edit `src/lib/db.ts` if you change storage).

`npm run typecheck` and `npm run build` are your pre-flight checks.

---

## Project structure

```
src/
  app/                  routes (public site + /admin + /api)
  components/           reusable UI + admin components
  lib/
    db.ts               SQLite schema, seed, queries, atomic status transitions
    auth.ts             admin auth + HMAC sessions
    validation.ts       zod schemas (shared client/server)
    site.ts             editable site content
    images.ts           central image registry
    types.ts            shared types
  data/                 (runtime) SQLite database — git-ignored
```

**Data model:** `hotel`, `banquet`, `booking_request` with
`status ∈ {PENDING, CONFIRMED, REJECTED, CANCELLED}` and `source ∈ {ONLINE, OFFLINE}` — one
confirmed booking per banquet + date. `review` with
`status ∈ {PENDING, APPROVED, REJECTED}` for guest reviews.