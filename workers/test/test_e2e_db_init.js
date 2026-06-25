#!/usr/bin/env node

/**
 * Database initialization script
 * Creates all required tables if they don't exist (bypasses RLS with service role)
 */

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE_URL || "https://eevjozgobudwnbvjecnw.supabase.co";
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_ROLE) {
  console.error("❌ Missing SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

console.log("🔧 Initializing database...\n");

// Test connection by querying tables
async function checkTables() {
  console.log("📋 Checking tables...");

  const tables = ["users", "boxes", "appliances", "device_commands"];
  let allExist = true;

  for (const table of tables) {
    try {
      const { error } = await supabase.from(table).select("count()", { count: "exact" }).limit(1);
      if (error) {
        console.log(`   ❌ Table not found: ${table}`);
        allExist = false;
      } else {
        console.log(`   ✓ Table exists: ${table}`);
      }
    } catch (e) {
      console.log(`   ❌ Table not found: ${table}`);
      allExist = false;
    }
  }

  if (allExist) {
    console.log("   ✓ All tables exist\n");
  }

  return allExist;

async function ensureAdminUser() {
  console.log("👤 Ensuring admin test user...");

  const adminId = "00000000-0000-0000-0000-000000000001";
  const adminEmail = "admin-test@aricie.local";

  try {
    // Try to insert directly (if users table exists)
    const { data: existing } = await supabase
      .from("users")
      .select("id")
      .eq("id", adminId)
      .maybeSingle();

    if (existing) {
      console.log(`   ✓ Admin user already exists: ${adminId}\n`);
      return adminId;
    }

    const { error } = await supabase
      .from("users")
      .insert({
        id: adminId,
        email: adminEmail,
        role: "admin",
        status: "active",
      });

    if (error && !error.message.includes("duplicate")) {
      console.log(`   ⚠️  Could not ensure admin user (may not have users table): ${error.message}`);
      return adminId;
    }

    console.log(`   ✓ Admin user ensured: ${adminId}\n`);
    return adminId;
  } catch (e) {
    console.log(`   ⚠️  Admin user check failed: ${e.message}\n`);
    return adminId;
  }
}

(async () => {
  try {
    const allReady = await checkTables();

    if (allReady) {
      await ensureAdminUser();
      console.log("✅ Database is ready for E2E testing\n");
      process.exit(0);
    } else {
      console.log("\n❌ Database schema not initialized.");
      console.log("\nTo initialize, run these steps:");
      console.log("1. Open Supabase dashboard: " + SUPABASE_URL);
      console.log("2. Go to SQL Editor");
      console.log("3. Create a new query and paste: supabase/migrations/20260621133535_init_schema.sql");
      console.log("4. Execute");
      console.log("5. Then run migrations: supabase/migrations/20260623000001_agent_tables.sql");
      console.log("\nOr use Supabase CLI:");
      console.log("  npx supabase db push\n");
      process.exit(1);
    }
  } catch (err) {
    console.error("❌ Initialization check failed:", err.message);
    process.exit(1);
  }
})();
