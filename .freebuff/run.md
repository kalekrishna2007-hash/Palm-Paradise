# Run doc — Palm Paradise (Next.js 15 + SQLite)

## Reproduce the artifacts

1. Install dependencies with npm (project uses npm — there is a `package-lock.json`):
   ```bash
   npm install
   ```
2. Environment: `.env` lives in the project root and is git-ignored. It holds
   `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `SESSION_SECRET` for the admin login and is
   already present in this checkout. Never commit it; copy it manually when moving
   checkouts and change the values for any non-local environment (template: `.env.example`).
3. Database: none to reproduce — `data/palm-paradise.db` (SQLite, WAL) is created and
   seeded automatically on first server start, including the two banquet halls.
   The `data/` folder is git-ignored.
4. Typecheck / production build (optional pre-flight):
   ```bash
   npm run typecheck
   npm run build
   ```

## Run the server

```bash
npm run dev -- -p 3000
```

- Default port 3000 (Next.js default). If taken, use another: `npm run dev -- -p 3001`
  and adjust the preview URL accordingly. No other config references the port.
- Windows detached start (stdout and stderr must go to different files):
  ```powershell
  powershell -NoProfile -Command "(Start-Process -FilePath 'npm.cmd' -ArgumentList 'run','dev' -RedirectStandardOutput '.freebuff\preview.log' -RedirectStandardError '.freebuff\preview.log.err' -WindowStyle Hidden -PassThru).Id"
  ```
  Confirm survival with `Get-Process -Id <pid>`, then wait for `http://localhost:3000/`
  to answer before registering the preview.
- Production mode: `npm run build && npm start` (same port rules).
- Routes: public site at `/`, staff login at `/admin/login`
  (credentials come from `.env` — see `.env.example` for the variable names).
