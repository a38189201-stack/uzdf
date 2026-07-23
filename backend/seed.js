require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

async function seed() {
  if (!process.env.DATABASE_URL || !process.env.DATABASE_URL.trim()) {
    console.log("No valid DATABASE_URL found, skipping seed.");
    return;
  }

  const p = new PrismaClient();
  try {
    const adminEmail = process.env.ADMIN_EMAIL || 'admin@uzdf.uz';
    const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';

    const h = await bcrypt.hash(adminPassword, 10);
    const u = await p.user.upsert({
      where: { email: adminEmail },
      update: { role: 'superadmin', password: h },
      create: { email: adminEmail, password: h, name: 'Admin', role: 'superadmin' }
    });
    console.log(`Superadmin created: ${u.email} | password from environment variables`);
  } catch (e) {
    console.error("Seed error:", e.message);
  } finally {
    await p.$disconnect().catch(() => {});
  }
}

seed();

