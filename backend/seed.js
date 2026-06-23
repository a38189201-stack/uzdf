require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const p = new PrismaClient();

const adminEmail = process.env.ADMIN_EMAIL || 'admin@uzdf.uz';
const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';

bcrypt.hash(adminPassword, 10)
  .then(h => p.user.upsert({
    where: { email: adminEmail },
    update: { role: 'superadmin', password: h },
    create: { email: adminEmail, password: h, name: 'Admin', role: 'superadmin' }
  }))
  .then(u => console.log(`Superadmin created: ${u.email} | password from environment variables`))
  .catch(e => console.error(e))
  .finally(() => p.$disconnect());

