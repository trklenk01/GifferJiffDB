# scripts/run_migrations.ps1
# Runs db migrations in order and tracks them in schema_migrations.
# Usage (PowerShell): .\scripts\run_migrations.ps1
# If execution policy blocks it:
# powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_migrations.ps1

$ErrorActionPreference = "Stop"

# Must be run from repo root (where docker-compose.yml lives)
if (!(Test-Path "docker-compose.yml")) {
    throw "Run this from the repo root (the folder containing docker-compose.yml)."
}

$dbUser = "app"
$dbName = "tenorclone"

# Ensure DB container is up
Write-Host "Starting database container (docker compose up -d)..."
docker compose up -d | Out-Host

# Get container ID for the 'db' service (portable, no hardcoded name)
$containerIdRaw = docker compose ps -q db
if (-not $containerIdRaw) {
    throw "No running container found for service 'db'. Run: docker compose up -d"
}
$containerId = $containerIdRaw.Trim()
if ([string]::IsNullOrWhiteSpace($containerId)) {
    throw "Could not find a running container for service 'db'. Try: docker compose up -d, then docker compose ps"
}

Write-Host "Using db container: $containerId"

# Ensure schema_migrations exists (safe on fresh DBs)
$ensureTableSql = @"
CREATE TABLE IF NOT EXISTS schema_migrations (
  version text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
"@

Write-Host "Ensuring schema_migrations table exists..."
$ensureTableSql | docker exec -i $containerId psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 | Out-Host

# Get migrations in sorted order
$migrationFiles = Get-ChildItem "db\migrations\*.sql" | Sort-Object Name

foreach ($file in $migrationFiles) {
    $version = $file.Name.Replace("'", "''")  # simple safety for single quotes in filenames (rare)

    # Check if already applied
    $checkSql = "SELECT 1 FROM schema_migrations WHERE version = '$version' LIMIT 1;"
    $alreadyApplied = docker exec -i $containerId psql -U $dbUser -d $dbName -t -A -v ON_ERROR_STOP=1 -c $checkSql

    if ($alreadyApplied.Trim() -eq "1") {
        Write-Host "Skipping $version (already applied)"
        continue
    }

    Write-Host "Applying $version..."

    # Apply migration file (stop on error)
    Get-Content $file.FullName | docker exec -i $containerId psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 | Out-Host

    # Record it as applied
    $recordSql = "INSERT INTO schema_migrations(version) VALUES ('$version');"
    docker exec -i $containerId psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -c $recordSql | Out-Host

    Write-Host "Applied $version"
}

Write-Host "All migrations complete."
