# Tenor Clone Backend

## Requirements
- Docker Desktop
- Git

## Setup

1. Clone repo:
   git clone <repo-url>
   cd tenorclone-backend

2. Start database:
   docker compose up -d

3. Run migrations:
   Get-Content db/migrations/000_schema_migrations.sql | docker exec -i tenorclone-db psql -U app -d tenorclone
   Get-Content db/migrations/001_init.sql | docker exec -i tenorclone-db psql -U app -d tenorclone
   Get-Content db/migrations/002_seed_minimal.sql | docker exec -i tenorclone-db psql -U app -d tenorclone
   Get-Content db/migrations/004_search_function.sql | docker exec -i tenorclone-db psql -U app -d tenorclone

Database URL:
postgresql://app:app@localhost:5432/tenorclone
