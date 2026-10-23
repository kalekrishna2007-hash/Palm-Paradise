#!/usr/bin/env bash
# Start the dev server without clobbering .next. Callers should have already
# stopped any `next dev` on port 3000 if they intend to rebuild.
set -o pipefail
npm run dev > /tmp/dev-server.log 2>&1
BUILD_EXIT=${PIPESTATUS[0]}
echo "DEV_EXIT=${BUILD_EXIT}" >> /tmp/dev-server.log
