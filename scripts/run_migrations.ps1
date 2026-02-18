# scripts/run_migrations.ps1
# Runs db migrations in order and tracks them in schema_migrations.
# Usage: .\scripts\run_migrations.ps1

$ErrorActionPreference = "Stop"

$container = "tenorclone-db"
$dbUser = "app"
$dbName = "tenorclone"

# Ensure schema_migrations exists (so the runner is safe on fresh DBs)
$ensureTableSql = @"
CREATE TABLE IF NOT EXISTS schema_migrations (
  version text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
"@

Write-Host "Ensuring schema_migrations table exists..."
$ensureTableSql | docker exec -i $container psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 | Out-Host

# Get migrations in sorted order
$migrationFiles = Get-ChildItem "db\migrations\*.sql" | Sort-Object Name

foreach ($file in $migrationFiles) {
    $version = $file.Name

    # Check if already applied
    $checkSql = "SELECT 1 FROM schema_migrations WHERE version = '$version' LIMIT 1;"
    $alreadyApplied = docker exec -i $container psql -U $dbUser -d $dbName -t -A -v ON_ERROR_STOP=1 -c $checkSql

    if ($alreadyApplied -eq "1") {
        Write-Host "Skipping $version (already applied)"
        continue
    }

    Write-Host "Applying $version..."

    # Apply migration file (stop on error)
    Get-Content $file.FullName | docker exec -i $container psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 | Out-Host

    # Record it as applied
    $recordSql = "INSERT INTO schema_migrations(version) VALUES ('$version');"
    docker exec -i $container psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -c $recordSql | Out-Host

    Write-Host "Applied $version"
}

Write-Host "All migrations complete."
