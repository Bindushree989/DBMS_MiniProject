# Back2You – Lost Item Return & Ownership Management System

DBMS Level 3 project. MySQL is the source of truth (lifecycle state machine in triggers + stored procedures);
a vector store (Qdrant) adds semantic matching; Next.js provides the UI and API layer.

**Lifecycle:** Found → Registered → Claimed → Verified → Handed Over → Returned
Roles: `user`, `staff`, `admin` (re-checked from the DB on every request).

## Run it

Prerequisites: Node 20+, MySQL 8 (or `docker compose up -d`, which also starts Qdrant).

```bash
npm install
cp .env.example .env          # then edit: DB_USER/DB_PASSWORD (admin account), JWT_SECRET
docker compose up -d          # optional if you already have MySQL; Qdrant is optional
npm run db:reset              # DROPS and recreates database `back2you`, loads db/01..07 SQL, creates app account
npm run db:seed               # ~650 demo items, users, claims, handovers
npm run build && npm start    # http://localhost:3000   (or: npm run dev)
```

Demo logins: `admin@back2you.dev / Admin@123`, `staff1@back2you.dev / Staff@123`, `user1@back2you.dev / User@123`.

Vector search: open **Admin → Vector status → Reindex** after seeding. If Qdrant or the MiniLM model is
unavailable, matching falls back automatically to MySQL FULLTEXT (the UI shows which engine was used).

## Tests
```bash
npm test                      # 25 DB tests (triggers, procedures, concurrency, audit chain); needs the admin DB account
npm run test:smoke            # HTTP journey; start the app first, BASE_URL=http://localhost:3000
```
Run `npm test` on a freshly seeded DB (`db:reset` + `db:seed`); T20 (match ranking) is data-dependent.
Results are written to `docs/test-results.md`.

## Layout
`db/` schema, functions, triggers, procedures, indexes, views · `lib/` DB, auth, matching, Qdrant ·
`app/` pages and `app/api/**` routes · `scripts/` setup & seed · `tests/` · `docs/` EXPLAIN plans, matching evaluation, screenshots.

> Warning: `db/01_schema.sql` starts with `DROP DATABASE IF EXISTS back2you`. Never run it against data you want to keep.
- ER diagram and data dictionary: `docs/ER_DIAGRAM.md` (Mermaid)
