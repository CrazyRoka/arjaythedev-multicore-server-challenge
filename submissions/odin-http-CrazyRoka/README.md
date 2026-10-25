# Odin Conduit

**Front: direct**

RealWorld Conduit API implemented in [Odin](https://odin-lang.org/), using a vendored
and patched copy of [`laytan/odin-http`](https://github.com/laytan/odin-http) on top of
Odin's `core:nbio` io_uring event loops, and [`laytan/odin-postgresql`](https://github.com/laytan/odin-postgresql)
for libpq access.

## Versions

- Odin `dev-2026-08` (pinned, sha256-checked in `install.sh`)
- `laytan/odin-http` commit `fac113fbd828aad3d71479a534b5de4358b6a07b` (vendored in `src/lib/http`)
- `laytan/odin-postgresql` commit `9d82bb88e99fd2d47aac57c00e9e6f9aabf48238` (vendored in `src/lib/pq`)
- PostgreSQL 18 via system `libpq`
- bcrypt via system `libxcrypt`

## Design

- 2 non-blocking io_uring event-loop threads accept connections and parse HTTP.
- 24 blocking libpq worker threads each own one PostgreSQL connection and process
  queued requests. Responses are sent asynchronously back onto the originating
  connection's event loop with `nbio.send_poly2`/`send_poly3`.
- Request bodies are fully drained before dispatch, so keep-alive connections stay open.
- JSON is written directly into byte buffers; timestamps and `tagList` JSON are produced
  by PostgreSQL to avoid parsing/formatting work in the hot path.
- List queries select the page of articles first, bound the inner page to 100 rows,
  and only then compute tags, favorite counts and viewer flags for the returned rows.
  Tag names are fetched by primary key; favorite count and viewer flag share one
  `LEFT JOIN LATERAL` scan. The capped `articlesCount` is returned by the same
  statement, avoiding a second round trip for non-empty pages.
- Article creation is a single transaction (article, tags, article_tags).
- Per-connection virtual arenas start at 8 KiB instead of the upstream 1 MiB, and the
  listen backlog is 65535.
- Per-connection PostgreSQL settings: `plan_cache_mode=force_generic_plan`, `jit=off`,
  `max_parallel_workers_per_gather=0`.
- The server is configured with `HOST`, `PORT`, `DATABASE_URL`, and `JWT_SECRET`;
  `DB_WORKERS` and `IO_THREADS` may be overridden. On the 8-vCPU target, 24 workers
  and 2 io_uring loops measured best.
