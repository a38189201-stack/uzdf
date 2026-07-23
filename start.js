const { execSync } = require('child_process');

if (!process.env.DATABASE_URL || !process.env.DATABASE_URL.trim()) {
  process.env.DATABASE_URL = "postgresql://postgres:admin@localhost:5432/drone_db?schema=public";
}

console.log('🚀 Starting UZDF Application...');

// 1. Repair migrations safely
try {
  console.log('🔧 [1/4] Running migration repair...');
  require('./backend/repair_migration.js');
} catch (e) {
  console.warn('⚠️ Migration repair warning:', e.message);
}

// 2. Run Prisma migrate deploy
if (process.env.DATABASE_URL && process.env.DATABASE_URL.trim()) {
  try {
    console.log('🗄️ [2/4] Running Prisma migrate deploy...');
    execSync('npx --prefix backend prisma migrate deploy --schema=backend/prisma/schema.prisma', { stdio: 'inherit' });
  } catch (e) {
    console.warn('⚠️ Prisma migrate deploy warning:', e.message);
    try {
      console.log('🔄 Attempting fallback: db push...');
      execSync('npx --prefix backend prisma db push --schema=backend/prisma/schema.prisma --accept-data-loss', { stdio: 'inherit' });
    } catch (pushErr) {
      console.error('❌ DB Push warning:', pushErr.message);
    }
  }

  // 3. Seed database
  try {
    console.log('🌱 [3/4] Seeding database...');
    require('./backend/seed.js');
    try { require('./backend/seed_about.js'); } catch (_) {}
    try { require('./backend/seed_zones.js'); } catch (_) {}
  } catch (e) {
    console.warn('⚠️ Seeding warning:', e.message);
  }
} else {
  console.warn('⚠️ DATABASE_URL is not set. Skipping migrations and seeding.');
}

// 4. Start main server
console.log('⚡ [4/4] Starting server.js...');
require('./backend/server.js');
