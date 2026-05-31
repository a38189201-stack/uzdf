const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const p = new PrismaClient();
bcrypt.hash('admin123', 10)
  .then(h => p.user.upsert({
    where: { email: 'admin@skycheck.uz' },
    update: { role: 'superadmin' },
    create: { email: 'admin@skycheck.uz', password: h, name: 'Admin', role: 'superadmin' }
  }))
  .then(u => console.log('Superadmin created:', u.email, '| password: admin123'))
  .catch(e => console.error(e))
  .finally(() => p.$disconnect());
