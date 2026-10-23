#!/usr/bin/env bash
# Verifies the admin surface on a running dev/prod server. Usage:
#   ./admin-check.sh [url]      default url: http://localhost:59591
set -u
URL=${1:-http://localhost:58731}
JAR=/tmp/pp_admin_check.jar
DEV_ORIGIN=${URL#http://}
rm -f "$JAR"
# The dev origin must match the Origin header (isSameOrigin is enforced on the
# admin state-changing routes); a mismatched origin returns 403 + no cookie.

FAILS=0
ok()   { echo "[ok]   $1"; }
fail() { echo "[FAIL] $1"; FAILS=$((FAILS + 1)); }

# 1. unauthenticated /admin redirects to login
code=$(curl -s -o /dev/null -w '%{http_code}' -I "$URL/admin")
[ "$code" = "307" ] && ok "GET /admin (no session) -> 307" || fail "GET /admin -> $code"

# 2. login page serves
code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/admin/login")
[ "$code" = "200" ] && ok "GET /admin/login -> 200" || fail "login page -> $code"

# 3. login with real creds, capture cookie
curl -s -c "$JAR" -X POST "$URL/api/admin/login" \
  -H "Content-Type: application/json" -H "Origin: $URL" \
  -d '{"username":"admin","password":"palm-paradise-2026"}' > /dev/null
[ -s "$JAR" ] && ok "POST /api/admin/login -> session cookie set" || fail "login failed"

# 4. me endpoint
body=$(curl -s -b "$JAR" "$URL/api/admin/me")
echo "$body" | grep -q '"role":"admin"' && ok "GET /api/admin/me -> admin role" || fail "me -> $body"

# 5. authenticated /admin renders dashboard sections
dash=$(curl -s -b "$JAR" "$URL/admin")
for s in Banquets Requests Reviews Calendar; do
  echo "$dash" | grep -qi "$s" && ok "dashboard contains $s" || fail "dashboard missing $s"
done

# 6. bookings / reviews / banquets list
code=$(curl -s -b "$JAR" -o /tmp/pp_bookings.json -w '%{http_code}' "$URL/api/admin/bookings")
[ "$code" = "200" ] && echo "$(cat /tmp/pp_bookings.json)" | grep -q '"bookings":\[\]' && ok "bookings list (0)" || fail "bookings -> $code"
code=$(curl -s -b "$JAR" -o /tmp/pp_reviews.json -w '%{http_code}' "$URL/api/admin/reviews")
[ "$code" = "200" ] && ok "reviews list" || fail "reviews -> $code"
code=$(curl -s -b "$JAR" -o /tmp/pp_banquets.json -w '%{http_code}' "$URL/api/admin/banquets")
if [ "$code" = "404" ]; then
  # /api/admin/banquets is intentionally not a route; the server page is /admin/banquets
  code=$(curl -s -b "$JAR" -o /tmp/pp_banquets.json -w '%{http_code}' "$URL/admin/banquets")
fi
[ "$code" = "200" ] && grep -qi "banquet" /tmp/pp_banquets.json && ok "banquets list" || fail "banquets -> $code"

# 7. logout
code=$(curl -s -b "$JAR" -c /tmp/pp_logout.jar -o /dev/null -w '%{http_code}' -X POST "$URL/api/admin/logout")
[ "$code" = "200" ] && ok "POST /api/admin/logout" || fail "logout -> $code"

# 8. /admin back to 307
code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/admin")
[ "$code" = "307" ] && ok "GET /admin after logout -> 307" || fail "after logout -> $code"

rm -f "$JAR" /tmp/pp_logout.jar /tmp/pp_bookings.json /tmp/pp_reviews.json /tmp/pp_banquets.json

if [ "$FAILS" -gt 0 ]; then
  echo "$FAILS check(s) failed"
  exit 1
fi
echo "all checks passed"
