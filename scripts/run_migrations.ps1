# scripts/run_migrations.ps1
$ErrorActionPreference = "Stop"

if (!(Test-Path "docker-compose.yml")) {
    throw "Run this from the repo root (the folder containing docker-compose.yml)."
}

$dbUser = "app"
$dbName = "tenorclone"

Write-Host "Starting database container (docker compose up -d)..."
docker compose up -d | Out-Host

$containerIdRaw = docker compose ps -q db
if (-not $containerIdRaw) {
    throw "No container found for service 'db'. Check docker-compose.yml service name and run: docker compose ps"
}
$containerId = $containerIdRaw.Trim()
Write-Host "Using db container: $containerId"
Write-Host "Bootstrapping schema_migrations (000_migrations.sql)..."
$bootstrap = Get-Content "db\migrations\000_migrations.sql" |
  docker exec -i $containerId psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 2>&1

if ($LASTEXITCODE -ne 0) {
  throw "Bootstrap failed:`n$bootstrap"
}

$bootstrap | Out-Host

# Wait for Postgres to be ready (prevents null outputs early on)
Write-Host "Waiting for Postgres to be ready..."

for ($i = 1; $i -le 30; $i++) {
    $ready = docker exec $containerId pg_isready -U $dbUser -d $dbName 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 1
}
if ($LASTEXITCODE -ne 0) {
    throw "Postgres not ready after waiting. Run: docker logs $(docker compose ps -q db)"
}

$migrationFiles = Get-ChildItem "db\migrations\*.sql" |
  Where-Object { $_.Name -ne "000_migrations.sql" } |
  Sort-Object Name


foreach ($file in $migrationFiles) {
    $version = $file.Name.Replace("'", "''")

    # Check if already applied (capture stderr too)
    $checkSql = "SELECT 1 FROM schema_migrations WHERE version = '$version' LIMIT 1;"
    $alreadyAppliedOut = docker exec -i $containerId psql -U $dbUser -d $dbName -t -A -v ON_ERROR_STOP=1 -c $checkSql 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "psql failed checking migration '$version':`n$alreadyAppliedOut"
    }

    $alreadyApplied = ($alreadyAppliedOut | Out-String).Trim()

    if ($alreadyApplied -eq "1") {
        Write-Host "Skipping $version (already applied)"
        continue
    }

    Write-Host "Applying $version..."

    $applyOut = Get-Content $file.FullName | docker exec -i $containerId psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed applying migration '$version':`n$applyOut"
    }
    $applyOut | Out-Host

    $recordSql = "INSERT INTO schema_migrations(version) VALUES ('$version');"
    $recordOut = docker exec -i $containerId psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -c $recordSql 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed recording migration '$version':`n$recordOut"
    }

    Write-Host "Applied $version"
}

Write-Host "All migrations complete."
