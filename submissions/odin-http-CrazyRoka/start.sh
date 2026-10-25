#!/usr/bin/env bash
# Runs the server in the foreground. Config: DATABASE_URL, JWT_SECRET, HOST, PORT.
set -euo pipefail
cd "$(dirname "$0")"

export DB_WORKERS="${DB_WORKERS:-80}"
export IO_THREADS="${IO_THREADS:-8}"

exec ./bin/conduit
