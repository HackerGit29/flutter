#!/usr/bin/env pwsh

<#
.SYNOPSIS
  Force apply Supabase migrations by executing SQL directly
.DESCRIPTION
  Bypasses migration versioning issues by running SQL directly in Supabase
#>

$SUPABASE_URL = "https://eevjozgobudwnbvjecnw.supabase.co"
$PROJECT_ID = "eevjozgobudwnbvjecnw"

Write-Host "🔗 Supabase Direct SQL Migration" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Steps:" -ForegroundColor Yellow
Write-Host "1. Open SQL Editor: $SUPABASE_URL/dashboard/sql/new"
Write-Host ""
Write-Host "2. Run migrations in order:" -ForegroundColor Yellow
Write-Host ""

$migrations = @(
    @{
        file = "supabase/migrations/20260621133535_init_schema.sql"
        name = "1. Initialize Schema (users, boxes, appliances, etc)"
    },
    @{
        file = "supabase/migrations/20260623000001_agent_tables.sql"
        name = "2. Agent Tables (device_commands, agent_audit_logs, chat_embeddings)"
    },
    @{
        file = "supabase/migrations/20260624000001_fix_device_commands_status.sql"
        name = "3. Fix device_commands Status"
    },
    @{
        file = "supabase/migrations/20260624000002_user_creation_trigger.sql"
        name = "4. User Creation Trigger"
    },
    @{
        file = "supabase/migrations/20260625162827_fix_admin_rls_and_auth_profile_loading.sql"
        name = "5. Fix Admin RLS Policies"
    }
)

foreach ($mig in $migrations) {
    Write-Host "$($mig.name)" -ForegroundColor Green
    Write-Host "   File: $($mig.file)" -ForegroundColor Gray
    
    if (Test-Path $mig.file) {
        $lines = (Get-Content $mig.file | Measure-Object -Line).Lines
        Write-Host "   Lines: $lines" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "3. After each migration, verify:" -ForegroundColor Yellow
Write-Host "   SELECT COUNT(*) FROM boxes;" -ForegroundColor Gray
Write-Host "   SELECT COUNT(*) FROM appliances;" -ForegroundColor Gray
Write-Host "   SELECT COUNT(*) FROM device_commands;" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Verify all tables:" -ForegroundColor Yellow
Write-Host "   SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;" -ForegroundColor Gray
Write-Host ""

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "After migrations applied, run E2E test:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   node workers/test/test_e2e_simple.js" -ForegroundColor Yellow
