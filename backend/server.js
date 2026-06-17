require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const fs = require('fs');
const { spawn } = require('child_process');
const https = require('https');
const os = require('os');

const app = express();
const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'uzdf-super-secret-2024';
const { OAuth2Client } = require('google-auth-library');
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '623890287900-og7m9d6pi7i6ptk525afmc7kdalp2php.apps.googleusercontent.com';
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);


const pendingRegistrations = new Map();

// Nodemailer transport setup
let transporter;
if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT) || 587,
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

async function sendVerificationEmail(email, code) {
  const mailOptions = {
    from: process.env.SMTP_FROM || '"UZDF" <noreply@uzdf.uz>',
    to: email,
    subject: 'Код подтверждения регистрации UZDF',
    html: `
      <div style="font-family: Arial, sans-serif; background-color: #050814; color: #ffffff; padding: 30px; border-radius: 10px; max-width: 500px; margin: 0 auto; border: 1px solid #0066FF;">
        <div style="text-align: center; margin-bottom: 20px;">
          <h1 style="color: #0066FF; margin: 0; font-size: 28px; letter-spacing: 2px;">UZDF</h1>
          <p style="color: #00E5FF; margin: 5px 0 0 0; font-size: 10px; letter-spacing: 4px; font-weight: bold;">УЗБЕКИСТАН</p>
        </div>
        <hr style="border-color: #0066FF; opacity: 0.3; margin-bottom: 25px;">
        <p style="font-size: 16px; line-height: 1.5;">Здравствуйте!</p>
        <p style="font-size: 16px; line-height: 1.5;">Спасибо за регистрацию в UZDF Uzbekistan. Для подтверждения вашей почты используйте следующий код подтверждения:</p>
        <div style="background-color: #0A0D1A; border: 1px solid #00E5FF; border-radius: 8px; padding: 15px; text-align: center; margin: 30px 0; letter-spacing: 6px;">
          <span style="font-size: 32px; font-weight: bold; color: #00E5FF;">${code}</span>
        </div>
        <p style="font-size: 14px; color: #94A3B8; line-height: 1.5;">Код действителен в течение 10 минут. Если вы не запрашивали этот код, просто проигнорируйте это письмо.</p>
        <hr style="border-color: #0066FF; opacity: 0.3; margin-top: 25px; margin-bottom: 15px;">
        <p style="font-size: 12px; color: #64748B; text-align: center; margin: 0;">&copy; 2026 UZDF Uzbekistan. Все права защищены.</p>
      </div>
    `,
  };

  console.log('────────────────────────────────────────────────────────');
  console.log(`📧 ОТПРАВЛЕНО ПИСЬМО НА: ${email}`);
  console.log(`🔑 КОД ПОДТВЕРЖДЕНИЯ: ${code}`);
  console.log('────────────────────────────────────────────────────────');

  if (transporter) {
    try {
      await transporter.sendMail(mailOptions);
      console.log(`✅ Письмо успешно отправлено на ${email}`);
    } catch (error) {
      console.error(`❌ Ошибка отправки письма через SMTP: ${error.message}`);
    }
  } else {
    console.log('ℹ️ SMTP не настроен. Письмо выведено в консоль для отладки.');
  }
}


app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});
// Serve the web folder as static files
app.use(express.static(path.join(__dirname, '../web')));

// ─────────────────────────────────────────────
// MIDDLEWARE
// ─────────────────────────────────────────────
const ADMIN_ROLES = ['superadmin', 'admin', 'supersupport', 'support'];
const STAFF_ROLES = ['superadmin', 'admin', 'supersupport', 'support'];

const authMiddleware = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1] || req.query.token;
  if (!token) return res.status(401).json({ error: 'Токен не найден' });
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await prisma.user.findUnique({ where: { id: decoded.id } });
    if (!user) return res.status(401).json({ error: 'Пользователь не найден' });
    if (user.isBlocked) {
      return res.status(403).json({ error: 'Ваш доступ временно приостановлен. Обратитесь к администратору' });
    }

    let session = await prisma.session.findUnique({ where: { token } });
    if (!session) {
      // Auto-create session for active JWT to prevent breaking existing users during migration
      session = await prisma.session.create({
        data: {
          userId: user.id,
          token,
          ipAddress: req.ip || req.headers['x-forwarded-for'] || null,
          userAgent: req.headers['user-agent'] || null,
          lastActive: new Date()
        }
      }).catch(() => null);
    } else if (session.isRevoked) {
      return res.status(401).json({ error: 'Сессия была завершена или недействительна. Пожалуйста, войдите снова.' });
    } else {
      // Update lastActive and browser details asynchronously
      prisma.session.update({
        where: { id: session.id },
        data: {
          lastActive: new Date(),
          ipAddress: req.ip || req.headers['x-forwarded-for'] || session.ipAddress,
          userAgent: req.headers['user-agent'] || session.userAgent
        }
      }).catch(err => console.error('Error updating session lastActive:', err));
    }

    if (['superadmin', 'admin', 'supersupport', 'support', 'superuser'].includes(user.role)) {
      user.courseLives = 3;
    }

    // Auto-restore lives: +1 life every 24 hours (max 3)
    if (user.courseLives < 3) {
      const lastRestore = user.livesRestoredAt || user.createdAt;
      const hoursSinceRestore = (Date.now() - new Date(lastRestore).getTime()) / (1000 * 60 * 60);
      if (hoursSinceRestore >= 24) {
        const livesToAdd = Math.min(Math.floor(hoursSinceRestore / 24), 3 - user.courseLives);
        if (livesToAdd > 0) {
          const updatedUser = await prisma.user.update({
            where: { id: user.id },
            data: {
              courseLives: user.courseLives + livesToAdd,
              livesRestoredAt: new Date()
            }
          });
          user.courseLives = updatedUser.courseLives;
          user.livesRestoredAt = updatedUser.livesRestoredAt;
        }
      }
    }

    req.user = user;
    next();
  } catch (e) {
    res.status(401).json({ error: 'Недействительный токен или сессия устарела' });
  }
};

// Any staff role (superadmin, admin, supersupport, support)
const adminMiddleware = (req, res, next) => {
  authMiddleware(req, res, () => {
    if (!STAFF_ROLES.includes(req.user.role)) return res.status(403).json({ error: 'Только для администраторов' });
    next();
  });
};

// superadmin only
const superAdminMiddleware = (req, res, next) => {
  authMiddleware(req, res, () => {
    if (req.user.role !== 'superadmin') return res.status(403).json({ error: 'Только для суперадминистраторов' });
    next();
  });
};

// superadmin + admin only (not support roles)
const fullAdminMiddleware = (req, res, next) => {
  authMiddleware(req, res, () => {
    if (req.user.role !== 'superadmin' && req.user.role !== 'admin') return res.status(403).json({ error: 'Только для администраторов' });
    next();
  });
};

// support and above (supersupport, admin, superadmin)
const supportMiddleware = (req, res, next) => {
  authMiddleware(req, res, () => {
    if (!STAFF_ROLES.includes(req.user.role)) return res.status(403).json({ error: 'Только для поддержки' });
    next();
  });
};

// ─────────────────────────────────────────────
// GAMIFICATION HELPERS
// ─────────────────────────────────────────────
function getRequiredExpForLevel(level) {
  if (level <= 1) return 0;
  return (level - 1) * 100 + (level - 1) * (level - 1) * 15;
}

const ACHIEVEMENTS = {
  first_steps: { name: "Первый взлет", expReward: 100 },
  theory_master: { name: "Теоретик авиации", expReward: 200 },
  certified_pilot: { name: "Дипломированный ас", expReward: 500 },
  all_courses: { name: "Безопасное небо", expReward: 800 }
};

async function grantUserExpAndCheckAchievements(userId, expAmount, triggerEvent, prismaInstance) {
  const db = prismaInstance || prisma;
  const user = await db.user.findUnique({
    where: { id: userId },
    include: { achievements: true }
  });
  if (!user) return null;

  let newExp = user.exp + expAmount;
  let newLevel = user.level;

  const existingAchievements = new Set(user.achievements.map(a => a.achievementId));
  const newlyUnlocked = [];

  async function unlock(achievementId) {
    if (ACHIEVEMENTS[achievementId] && !existingAchievements.has(achievementId)) {
      await db.userAchievement.create({
        data: { userId, achievementId }
      });
      newlyUnlocked.push(achievementId);
      const reward = ACHIEVEMENTS[achievementId]?.expReward || 0;
      newExp += reward;
    }
  }

  if (triggerEvent === 'course_step') {
    await unlock('first_steps');
  } else if (triggerEvent === 'course_completed') {
    const completions = await db.courseCompletion.findMany({ where: { userId } });
    if (completions.length >= 1) {
      await unlock('theory_master');
    }
    if (completions.length >= 3) {
      await unlock('certified_pilot');
    }
    if (completions.length >= 5) {
      await unlock('all_courses');
    }
  }

  // Calculate level
  let calculatedLevel = 1;
  while (calculatedLevel < 30) {
    const nextLevelExp = getRequiredExpForLevel(calculatedLevel + 1);
    if (newExp >= nextLevelExp) {
      calculatedLevel++;
    } else {
      break;
    }
  }
  newLevel = calculatedLevel;

  await db.user.update({
    where: { id: userId },
    data: {
      exp: newExp,
      level: newLevel
    }
  });

  return { exp: newExp, level: newLevel, newlyUnlocked };
}

// ─────────────────────────────────────────────
// SYSTEM SETTINGS HELPERS
// ─────────────────────────────────────────────
async function getSystemSetting(key, defaultValue) {
  try {
    const setting = await prisma.systemSetting.findUnique({
      where: { key }
    });
    if (setting) return setting.value;
  } catch (e) {
    console.error(`Error reading system setting ${key}:`, e.message);
  }
  return defaultValue;
}

async function setSystemSetting(key, value) {
  try {
    await prisma.systemSetting.upsert({
      where: { key },
      update: { value: value.toString() },
      create: { key, value: value.toString() }
    });
    return true;
  } catch (e) {
    console.error(`Error saving system setting ${key}:`, e.message);
    return false;
  }
}

// ─────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────
app.post('/auth/register', async (req, res) => {
  try {
    const { email, password, name, phone } = req.body;
    if (!email || !password || !name) return res.status(400).json({ error: 'Все поля обязательны' });
    if (!phone) return res.status(400).json({ error: 'Номер телефона обязателен' });
    if (password.length < 6) return res.status(400).json({ error: 'Пароль должен быть не менее 6 символов' });
    if (!email.includes('@')) return res.status(400).json({ error: 'Неверный формат Email' });

    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) return res.status(400).json({ error: 'Email уже используется' });

    // Generate random 6-digit code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const hashedPassword = await bcrypt.hash(password, 10);

    // Save to pending store
    pendingRegistrations.set(email.toLowerCase(), {
      name,
      email,
      phone,
      password: hashedPassword,
      code,
      expires: Date.now() + 10 * 60 * 1000 // 10 minutes
    });

    // Send email
    await sendVerificationEmail(email, code);

    res.json({
      success: true,
      message: 'VERIFICATION_REQUIRED',
      email: email
    });
  } catch (e) {
    res.status(500).json({ error: 'Ошибка сервера при регистрации' });
  }
});

app.post('/auth/verify-code', async (req, res) => {
  try {
    const { email, code } = req.body;
    if (!email || !code) return res.status(400).json({ error: 'Email и код обязательны' });

    const pending = pendingRegistrations.get(email.toLowerCase());
    if (!pending) {
      return res.status(400).json({ error: 'Регистрационная сессия не найдена или истекла' });
    }

    if (Date.now() > pending.expires) {
      pendingRegistrations.delete(email.toLowerCase());
      return res.status(400).json({ error: 'Срок действия кода подтверждения истек' });
    }

    if (pending.code !== code) {
      return res.status(400).json({ error: 'Неверный код подтверждения' });
    }

    // Check again to be absolutely sure the email was not registered in the meantime
    const existingUser = await prisma.user.findUnique({ where: { email: pending.email } });
    if (existingUser) {
      pendingRegistrations.delete(email.toLowerCase());
      return res.status(400).json({ error: 'Email уже зарегистрирован' });
    }

    // Create user
    const user = await prisma.user.create({
      data: {
        email: pending.email,
        password: pending.password,
        name: pending.name,
        phone: pending.phone || null,
        role: 'user',
      },
    });

    // Remove from pending
    pendingRegistrations.delete(email.toLowerCase());

    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });

    // Create session record
    await prisma.session.create({
      data: {
        userId: user.id,
        token,
        ipAddress: req.ip || req.headers['x-forwarded-for'] || null,
        userAgent: req.headers['user-agent'] || null
      }
    }).catch(err => console.error('Failed to save session:', err.message));

    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        exp: user.exp,
        level: user.level,
        courseLives: 3,
        livesRestoredAt: null,
        achievements: []
      }
    });
  } catch (e) {
    res.status(500).json({ error: 'Ошибка сервера при проверке кода' });
  }
});

app.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await prisma.user.findUnique({
      where: { email },
      include: { achievements: true }
    });
    if (!user) return res.status(401).json({ error: 'Неверный Email или пароль' });
    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(401).json({ error: 'Неверный Email или пароль' });
    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });

    // Create session record
    await prisma.session.create({
      data: {
        userId: user.id,
        token,
        ipAddress: req.ip || req.headers['x-forwarded-for'] || null,
        userAgent: req.headers['user-agent'] || null
      }
    }).catch(err => console.error('Failed to save session:', err.message));

    const isSpecialRole = ['superadmin', 'admin', 'supersupport', 'support', 'superuser'].includes(user.role);
    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        exp: user.exp,
        level: user.level,
        courseLives: isSpecialRole ? 3 : user.courseLives,
        livesRestoredAt: user.livesRestoredAt,
        achievements: user.achievements.map(a => ({ achievementId: a.achievementId, unlockedAt: a.unlockedAt }))
      }
    });
  } catch (e) {
    res.status(500).json({ error: 'Ошибка сервера при авторизации' });
  }
});

app.post('/auth/google', async (req, res) => {
  try {
    const { email, name } = req.body;
    if (!email || !name) return res.status(400).json({ error: 'Email и имя обязательны' });

    let user = await prisma.user.findUnique({
      where: { email },
      include: { achievements: true }
    });

    if (!user) {
      const dummyPassword = await bcrypt.hash(Math.random().toString(36), 10);
      user = await prisma.user.create({
        data: {
          email,
          name,
          password: dummyPassword,
          role: 'user'
        },
        include: { achievements: true }
      });
    }

    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });

    // Create session record
    await prisma.session.create({
      data: {
        userId: user.id,
        token,
        ipAddress: req.ip || req.headers['x-forwarded-for'] || null,
        userAgent: req.headers['user-agent'] || null
      }
    }).catch(err => console.error('Failed to save session:', err.message));

    const isSpecialRole = ['superadmin', 'admin', 'supersupport', 'support', 'superuser'].includes(user.role);
    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        exp: user.exp,
        level: user.level,
        courseLives: isSpecialRole ? 3 : user.courseLives,
        livesRestoredAt: user.livesRestoredAt,
        achievements: user.achievements.map(a => ({ achievementId: a.achievementId, unlockedAt: a.unlockedAt }))
      }
    });
  } catch (e) {
    res.status(500).json({ error: 'Ошибка сервера при авторизации через Google' });
  }
});

app.post('/auth/google-real', async (req, res) => {
  try {
    const { idToken } = req.body;
    if (!idToken) return res.status(400).json({ error: 'idToken обязателен' });

    const ticket = await googleClient.verifyIdToken({
      idToken: idToken,
      audience: GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    const { email, name, picture } = payload;

    if (!email) {
      return res.status(400).json({ error: 'Не удалось получить email из Google аккаунта' });
    }

    let user = await prisma.user.findUnique({
      where: { email },
      include: { achievements: true }
    });

    if (!user) {
      const dummyPassword = await bcrypt.hash(Math.random().toString(36), 10);
      user = await prisma.user.create({
        data: {
          email,
          name: name || email.split('@')[0],
          avatar: picture || null,
          password: dummyPassword,
          role: 'user'
        },
        include: { achievements: true }
      });
    } else if (picture && user.avatar !== picture) {
      user = await prisma.user.update({
        where: { id: user.id },
        data: { avatar: picture },
        include: { achievements: true }
      });
    }

    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });

    // Create session record
    await prisma.session.create({
      data: {
        userId: user.id,
        token,
        ipAddress: req.ip || req.headers['x-forwarded-for'] || null,
        userAgent: req.headers['user-agent'] || null
      }
    }).catch(err => console.error('Failed to save session:', err.message));

    const isSpecialRole = ['superadmin', 'admin', 'supersupport', 'support', 'superuser'].includes(user.role);

    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        avatar: user.avatar,
        exp: user.exp,
        level: user.level,
        courseLives: isSpecialRole ? 3 : user.courseLives,
        livesRestoredAt: user.livesRestoredAt,
        achievements: user.achievements.map(a => ({ achievementId: a.achievementId, unlockedAt: a.unlockedAt }))
      }
    });
  } catch (error) {
    console.error('Ошибка верификации Google Token:', error);
    res.status(500).json({ error: 'Ошибка верификации токена авторизации Google' });
  }
});


app.get('/auth/me', authMiddleware, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        avatar: true,
        phone: true,
        language: true,
        createdAt: true,
        exp: true,
        level: true,
        courseLives: true,
        livesRestoredAt: true,
        achievements: { select: { achievementId: true, unlockedAt: true } },
        dob: true,
        country: true
      },
    });
    if (user && ['superadmin', 'admin', 'supersupport', 'support', 'superuser'].includes(user.role)) {
      user.courseLives = 3;
    }
    res.json(user);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/auth/me', authMiddleware, async (req, res) => {
  try {
    const { name, email, phone, language, avatar, dob, country } = req.body;
    if (email) {
      const existing = await prisma.user.findUnique({ where: { email } });
      if (existing && existing.id !== req.user.id) {
        return res.status(400).json({ error: 'Этот Email уже зарегистрирован другим пользователем' });
      }
    }
    const user = await prisma.user.update({
      where: { id: req.user.id },
      data: { name, email, phone, language, avatar, dob, country },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        avatar: true,
        phone: true,
        language: true,
        createdAt: true,
        exp: true,
        level: true,
        courseLives: true,
        livesRestoredAt: true,
        achievements: { select: { achievementId: true, unlockedAt: true } },
        dob: true,
        country: true
      },
    });
    if (user && ['superadmin', 'admin', 'supersupport', 'support', 'superuser'].includes(user.role)) {
      user.courseLives = 3;
    }
    res.json(user);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/auth/change-password', authMiddleware, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    if (!oldPassword || !newPassword) return res.status(400).json({ error: 'Все поля обязательны' });
    if (newPassword.length < 6) return res.status(400).json({ error: 'Новый пароль должен быть не менее 6 символов' });

    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    const valid = await bcrypt.compare(oldPassword, user.password);
    if (!valid) return res.status(400).json({ error: 'Неверный старый пароль' });

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({
      where: { id: req.user.id },
      data: { password: hashedPassword }
    });

    res.json({ success: true, message: 'Пароль успешно изменен' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// ADMIN SETTINGS
// ─────────────────────────────────────────────
app.get('/admin/settings', adminMiddleware, async (req, res) => {
  try {
    const screenshotBlockThreshold = await getSystemSetting('screenshotBlockThreshold', '5');
    const screenshotBlockDurationHours = await getSystemSetting('screenshotBlockDurationHours', '24');
    const telegramAdminChatId = await getSystemSetting('telegramAdminChatId', process.env.TELEGRAM_ADMIN_CHAT_ID || '');
    res.json({
      screenshotBlockThreshold: parseInt(screenshotBlockThreshold),
      screenshotBlockDurationHours: parseInt(screenshotBlockDurationHours),
      telegramAdminChatId
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/settings', adminMiddleware, async (req, res) => {
  try {
    const { screenshotBlockThreshold, screenshotBlockDurationHours, telegramAdminChatId } = req.body;
    if (screenshotBlockThreshold !== undefined) {
      await setSystemSetting('screenshotBlockThreshold', screenshotBlockThreshold);
    }
    if (screenshotBlockDurationHours !== undefined) {
      await setSystemSetting('screenshotBlockDurationHours', screenshotBlockDurationHours);
    }
    if (telegramAdminChatId !== undefined) {
      await setSystemSetting('telegramAdminChatId', telegramAdminChatId);
    }
    res.json({ success: true, message: 'Настройки успешно сохранены' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// ADMIN CERTIFICATE MANAGEMENT
// ─────────────────────────────────────────────
app.get('/admin/certificates', adminMiddleware, async (req, res) => {
  try {
    const completions = await prisma.courseCompletion.findMany({
      where: {
        certificateUuid: { not: null }
      },
      orderBy: { completedAt: 'desc' }
    });

    // We need user emails/names and course titles
    const users = await prisma.user.findMany({
      select: { id: true, name: true, email: true }
    });
    const courses = await prisma.course.findMany({
      select: { id: true, title: true }
    });

    const userMap = new Map(users.map(u => [u.id, u]));
    const courseMap = new Map(courses.map(c => [c.id, c]));

    const certificates = completions.map(c => {
      const u = userMap.get(c.userId);
      const crs = courseMap.get(c.courseId);
      return {
        id: c.id,
        userId: c.userId,
        userName: c.studentName || u?.name || 'Пилот',
        userEmail: u?.email || '',
        courseId: c.courseId,
        courseTitle: crs?.title || 'Unknown Course',
        completedAt: c.completedAt,
        certificateIssuedAt: c.certificateIssuedAt,
        certificateUuid: c.certificateUuid,
        finalScore: c.finalScore,
        lessonsCompletionPercent: c.lessonsCompletionPercent,
        isRevoked: c.isRevoked,
        revokedAt: c.revokedAt,
        revokedBy: c.revokedBy,
        revokeReason: c.revokeReason
      };
    });

    res.json(certificates);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/certificates/:uuid/revoke', adminMiddleware, async (req, res) => {
  try {
    const uuid = req.params.uuid;
    const { reason } = req.body;

    const completion = await prisma.courseCompletion.findUnique({
      where: { certificateUuid: uuid }
    });
    if (!completion) return res.status(404).json({ error: 'Сертификат не найден' });

    const updated = await prisma.courseCompletion.update({
      where: { certificateUuid: uuid },
      data: {
        isRevoked: true,
        revokedAt: new Date(),
        revokedBy: req.user.name,
        revokeReason: reason || 'Нарушение правил платформы'
      }
    });

    // Log action
    await prisma.adminAction.create({
      data: {
        adminId: req.user.id,
        actionType: 'revoke_certificate',
        targetUserId: completion.userId,
        details: `Отозван сертификат ${uuid}. Причина: ${reason}`
      }
    });

    res.json({ success: true, certificate: updated });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/certificates/:uuid/activate', adminMiddleware, async (req, res) => {
  try {
    const uuid = req.params.uuid;

    const completion = await prisma.courseCompletion.findUnique({
      where: { certificateUuid: uuid }
    });
    if (!completion) return res.status(404).json({ error: 'Сертификат не найден' });

    const updated = await prisma.courseCompletion.update({
      where: { certificateUuid: uuid },
      data: {
        isRevoked: false,
        revokedAt: null,
        revokedBy: null,
        revokeReason: null
      }
    });

    // Log action
    await prisma.adminAction.create({
      data: {
        adminId: req.user.id,
        actionType: 'activate_certificate',
        targetUserId: completion.userId,
        details: `Активирован отозванный сертификат ${uuid}`
      }
    });

    res.json({ success: true, certificate: updated });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// ADMIN — CREATE ADMIN / ROLE MANAGEMENT
// ─────────────────────────────────────────────
app.post('/admin/create-admin', superAdminMiddleware, async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    if (!name || !email || !password) return res.status(400).json({ error: 'Имя, email и пароль обязательны' });
    if (!['admin', 'superadmin'].includes(role)) return res.status(400).json({ error: 'Недопустимая роль. Допустимые: admin, superadmin' });
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return res.status(400).json({ error: 'Пользователь с таким email уже существует' });
    const hashedPass = await bcrypt.hash(password, 10);
    const admin = await prisma.user.create({
      data: { name, email, password: hashedPass, role },
    });
    // Log admin action
    await prisma.adminAction.create({
      data: { adminId: req.user.id, actionType: 'create_admin', targetUserId: admin.id, details: `Создан ${role}: ${email}` }
    });
    res.json({ success: true, user: { id: admin.id, name: admin.name, email: admin.email, role: admin.role } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.patch('/admin/users/:id/role', superAdminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const { role } = req.body;
    const allowed = ['user', 'moderator', 'admin', 'superadmin'];
    if (!allowed.includes(role)) return res.status(400).json({ error: `Недопустимая роль. Допустимые: ${allowed.join(', ')}` });
    // Cannot change own role
    if (userId === req.user.id) return res.status(400).json({ error: 'Нельзя изменить свою собственную роль' });
    const updated = await prisma.user.update({
      where: { id: userId },
      data: { role },
      select: { id: true, name: true, email: true, role: true }
    });
    await prisma.adminAction.create({
      data: { adminId: req.user.id, actionType: 'change_role', targetUserId: userId, details: `Роль изменена на: ${role}` }
    });
    res.json({ success: true, user: updated });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Order delivery address
app.post('/orders/:id/delivery', authMiddleware, async (req, res) => {
  try {
    const orderId = parseInt(req.params.id);
    const { deliveryAddress, deliveryCity, deliveryContact } = req.body;
    const order = await prisma.order.findUnique({ where: { id: orderId } });
    if (!order) return res.status(404).json({ error: 'Заказ не найден' });
    if (order.userId !== req.user.id) return res.status(403).json({ error: 'Нет доступа к этому заказу' });
    const updated = await prisma.order.update({
      where: { id: orderId },
      data: { deliveryAddress, deliveryCity, deliveryContact },
    });
    res.json({ success: true, order: updated });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// ORDERS — User's own orders
// ─────────────────────────────────────────────
app.get('/orders/my', authMiddleware, async (req, res) => {
  try {
    const orders = await prisma.order.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
    });
    res.json(orders);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// ZONES
// ─────────────────────────────────────────────
app.get('/zones', async (req, res) => {
  try {
    const zones = await prisma.zone.findMany();
    res.json(zones);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/zones', adminMiddleware, async (req, res) => {
  try {
    const { name, type, coordinates, maxAltitude } = req.body;
    const zone = await prisma.zone.create({ data: { name, type, coordinates, maxAltitude: parseInt(maxAltitude) } });
    res.json(zone);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/zones/:id', adminMiddleware, async (req, res) => {
  try {
    const { name, type, coordinates, maxAltitude } = req.body;
    const zone = await prisma.zone.update({
      where: { id: parseInt(req.params.id) },
      data: { name, type, coordinates, maxAltitude: parseInt(maxAltitude) },
    });
    res.json(zone);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/zones/:id', adminMiddleware, async (req, res) => {
  try {
    await prisma.zone.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// NEWS
// ─────────────────────────────────────────────
app.get('/news', async (req, res) => {
  try {
    const news = await prisma.news.findMany({ orderBy: { publishedAt: 'desc' } });
    res.json(news);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/news/:id', async (req, res) => {
  try {
    const item = await prisma.news.findUnique({ where: { id: parseInt(req.params.id) } });
    if (!item) return res.status(404).json({ error: 'Не найдено' });
    res.json(item);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/news', adminMiddleware, async (req, res) => {
  try {
    const { title, content, imageUrl, author } = req.body;
    const item = await prisma.news.create({ data: { title, content, imageUrl, author } });
    res.json(item);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/news/:id', adminMiddleware, async (req, res) => {
  try {
    const { title, content, imageUrl, author } = req.body;
    const item = await prisma.news.update({
      where: { id: parseInt(req.params.id) },
      data: { title, content, imageUrl, author },
    });
    res.json(item);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/news/:id', adminMiddleware, async (req, res) => {
  try {
    await prisma.news.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// COURSES
// ─────────────────────────────────────────────
const getUserIdFromToken = (req) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return null;
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    return decoded.id;
  } catch (e) {
    return null;
  }
};

app.get('/courses', async (req, res) => {
  try {
    const courses = await prisma.course.findMany({
      include: { steps: { orderBy: { order: 'asc' } } },
      orderBy: { id: 'asc' },
    });

    const userId = getUserIdFromToken(req);
    let userRole = 'user';
    let completedCourseIds = [];
    const progressMap = {};

    if (userId) {
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (user) {
        userRole = user.role;
      }
      const completions = await prisma.courseCompletion.findMany({
        where: { userId }
      });
      completedCourseIds = completions.map(c => c.courseId);

      const progresses = await prisma.userLessonProgress.findMany({
        where: { userId }
      });
      progresses.forEach(p => {
        progressMap[p.stepId] = p;
      });
    }

    const coursesWithLock = courses.map((course, index) => {
      let isLocked = false;
      if (index > 0) {
        const prevCourse = courses[index - 1];
        isLocked = !completedCourseIds.includes(prevCourse.id);
      }
      if (['superuser', 'superadmin', 'admin', 'supersupport', 'support'].includes(userRole)) {
        isLocked = false;
      }

      let prevStepCompleted = true;
      const stepsWithProgress = course.steps.map((step) => {
        let stepLocked = false;
        const progress = progressMap[step.id];

        if (['superuser', 'superadmin', 'admin', 'supersupport', 'support'].includes(userRole)) {
          stepLocked = false;
        } else {
          if (step.isFinalExam) {
            const otherSteps = course.steps.filter(s => s.id !== step.id);
            const anyIncomplete = otherSteps.some(s => {
              const prog = progressMap[s.id];
              return !prog || prog.status !== 'completed';
            });
            stepLocked = anyIncomplete;
          } else {
            stepLocked = !prevStepCompleted;
          }
        }

        prevStepCompleted = progress && progress.status === 'completed';

        return {
          ...step,
          userProgress: progress ? {
            id: progress.id,
            userId: progress.userId,
            stepId: progress.stepId,
            status: progress.status,
            scrollCompleted: progress.scrollCompleted,
            timeSpentSeconds: progress.timeSpentSeconds,
            lessonStartedAt: progress.lessonStartedAt,
            isTimerCompleted: progress.isTimerCompleted,
            quizAttempts: progress.quizAttempts,
            cooldownUntil: progress.cooldownUntil
          } : null,
          isLocked: stepLocked
        };
      });

      return {
        ...course,
        steps: stepsWithProgress,
        isLocked
      };
    });

    res.json(coursesWithLock);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/courses/completions/me', authMiddleware, async (req, res) => {
  try {
    const completions = await prisma.courseCompletion.findMany({
      where: { userId: req.user.id }
    });
    res.json(completions);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

const crypto = require('crypto');

// Helper to shuffle arrays
function shuffleArray(array) {
  const arr = [...array];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// Helper to verify step access sequence & course blocks
async function verifyStepAccessHelper(userId, step) {
  // Check if user has lives remaining (❤️ system)
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return;

  // Bypass everything for superusers and staff roles
  if (['superuser', 'superadmin', 'admin', 'supersupport', 'support'].includes(user.role)) {
    return;
  }

  if (user.courseLives <= 0) {
    const lastRestore = user.livesRestoredAt || user.createdAt;
    const nextRestoreMs = new Date(lastRestore).getTime() + 24 * 60 * 60 * 1000;
    const hoursLeft = Math.max(0, Math.ceil((nextRestoreMs - Date.now()) / 1000 / 60 / 60));
    throw new Error(`У вас закончились попытки (❤️ 0). Новая попытка через ${hoursLeft} ч. Обратитесь к администратору для получения дополнительных попыток.`);
  }

  // Check if course block exists
  const courseBlock = await prisma.userCourseBlock.findFirst({
    where: {
      userId,
      courseId: step.courseId,
      blockedUntil: { gt: new Date() }
    }
  });
  if (courseBlock) {
    const hoursLeft = Math.ceil((courseBlock.blockedUntil.getTime() - Date.now()) / 1000 / 60 / 60);
    throw new Error(`Доступ к курсу временно заблокирован на 24 часа из-за нарушений политики безопасности (скриншоты/запись экрана). Осталось: ${hoursLeft} ч.`);
  }

  // Get steps in order
  const allSteps = await prisma.courseStep.findMany({
    where: { courseId: step.courseId },
    orderBy: { order: 'asc' }
  });

  const stepIndex = allSteps.findIndex(s => s.id === step.id);

  if (step.isFinalExam) {
    // Cannot start final exam unless all other lessons in this course are completed
    const incompleteSteps = [];
    for (const s of allSteps) {
      if (s.id !== step.id && !s.isFinalExam) {
        const progress = await prisma.userLessonProgress.findUnique({
          where: { userId_stepId: { userId, stepId: s.id } }
        });
        if (!progress || progress.status !== 'completed') {
          incompleteSteps.push(`"${s.title}"`);
        }
      }
    }
    if (incompleteSteps.length > 0) {
      throw new Error(`Нельзя начать финальный тест не завершив все уроки модуля. Не пройдены: ${incompleteSteps.join(', ')}`);
    }
  } else if (stepIndex > 0) {
    // Normal step needs the immediate previous step to be completed
    const prevStep = allSteps[stepIndex - 1];
    const prevProgress = await prisma.userLessonProgress.findUnique({
      where: { userId_stepId: { userId, stepId: prevStep.id } }
    });
    if (!prevProgress || prevProgress.status !== 'completed') {
      throw new Error(`Нельзя перейти к следующему уроку не завершив текущий: "${prevStep.title}"`);
    }
  }

  // Course sequence checks (cannot start step if previous course is not completed)
  const allCourses = await prisma.course.findMany({ orderBy: { id: 'asc' } });
  const courseIndex = allCourses.findIndex(c => c.id === step.courseId);
  if (courseIndex > 0) {
    const prevCourse = allCourses[courseIndex - 1];
    const prevCompleted = await prisma.courseCompletion.findFirst({
      where: { userId, courseId: prevCourse.id }
    });
    if (!prevCompleted) {
      throw new Error('Этот курс еще заблокирован. Пройдите сначала предыдущий курс!');
    }
  }
}

// Helper to evaluate certificate conditions and issue if met
async function evaluateAndIssueCertificate(userId, courseId) {
  const existingCompletion = await prisma.courseCompletion.findFirst({
    where: { userId, courseId }
  });

  if (existingCompletion && existingCompletion.certificateUuid) {
    return { issued: true, uuid: existingCompletion.certificateUuid };
  }

  const courseSteps = await prisma.courseStep.findMany({
    where: { courseId },
    orderBy: { order: 'asc' }
  });

  const progresses = await prisma.userLessonProgress.findMany({
    where: { userId, stepId: { in: courseSteps.map(s => s.id) } }
  });

  const progressesMap = new Map(progresses.map(p => [p.stepId, p]));

  // 1. All lessons of the course must be completed
  for (const step of courseSteps) {
    const prog = progressesMap.get(step.id);
    if (!prog || prog.status !== 'completed') {
      throw new Error(`Не все шаги курса завершены. Не завершен: "${step.title}"`);
    }
  }

  // 2. Video timers completed on 90% or more video lessons
  const videoSteps = courseSteps.filter(s => s.type === 'video');
  let completedVideoTimersCount = 0;
  videoSteps.forEach(step => {
    const prog = progressesMap.get(step.id);
    if (prog && prog.isTimerCompleted) {
      completedVideoTimersCount++;
    }
  });
  const videoCompletionPercent = videoSteps.length > 0 ? (completedVideoTimersCount / videoSteps.length) * 100 : 100;
  if (videoCompletionPercent < 90) {
    throw new Error(`Просмотрено менее 90% видео уроков по таймеру (У вас: ${videoCompletionPercent.toFixed(1)}%)`);
  }

  // 3. All intermediate quiz scores >= 80%
  // 4. Final exam score >= 95%
  // 5. Total average score across all tests in course >= 95%
  const quizSteps = courseSteps.filter(s => s.type === 'quiz');
  let totalScore = 0;

  for (const step of quizSteps) {
    const prog = progressesMap.get(step.id);
    const score = prog ? prog.timeSpentSeconds : 0; // Stored quiz score in timeSpentSeconds
    totalScore += score;

    if (step.isFinalExam) {
      if (score < 95) {
        throw new Error(`Балл за финальный экзамен ниже 95% (У вас: ${score}%)`);
      }
    } else {
      if (score < 80) {
        throw new Error(`Промежуточный тест "${step.title}" сдан с баллом менее 80% (У вас: ${score}%)`);
      }
    }
  }

  const averageScore = quizSteps.length > 0 ? totalScore / quizSteps.length : 100;
  if (averageScore < 95) {
    throw new Error(`Средний балл по тестам курса ниже 95% (Ваш средний балл: ${averageScore.toFixed(1)}%)`);
  }

  // Issue certificate
  const uuid = crypto.randomUUID();
  const user = await prisma.user.findUnique({ where: { id: userId } });
  
  const lessonsCompletionPercent = (progresses.filter(p => p.status === 'completed').length / courseSteps.length) * 100;

  await prisma.courseCompletion.upsert({
    where: { userId_courseId: { userId, courseId } },
    update: {
      certificateIssuedAt: new Date(),
      certificateUuid: uuid,
      finalScore: averageScore,
      lessonsCompletionPercent,
      studentName: user.name
    },
    create: {
      userId,
      courseId,
      certificateIssuedAt: new Date(),
      certificateUuid: uuid,
      finalScore: averageScore,
      lessonsCompletionPercent,
      studentName: user.name
    }
  });

  return { issued: true, uuid };
}

async function checkAndCompleteCourse(userId, courseId) {
  try {
    const steps = await prisma.courseStep.findMany({
      where: { courseId }
    });
    if (steps.length === 0) return;

    const progresses = await prisma.userLessonProgress.findMany({
      where: {
        userId,
        stepId: { in: steps.map(s => s.id) },
        status: 'completed'
      }
    });

    if (progresses.length === steps.length) {
      const existingCompletion = await prisma.courseCompletion.findUnique({
        where: { userId_courseId: { userId, courseId } }
      });

      let certificateUuid = existingCompletion?.certificateUuid || null;

      if (!certificateUuid) {
        try {
          const certResult = await evaluateAndIssueCertificate(userId, courseId);
          certificateUuid = certResult.uuid;
        } catch (err) {
          console.log(`User ${userId} completed course ${courseId} but did not qualify for certificate yet: ${err.message}`);
        }
      }

      await prisma.courseCompletion.upsert({
        where: { userId_courseId: { userId, courseId } },
        update: {
          lessonsCompletionPercent: 100.0,
          certificateUuid: certificateUuid || undefined,
          certificateIssuedAt: certificateUuid ? new Date() : undefined
        },
        create: {
          userId,
          courseId,
          lessonsCompletionPercent: 100.0,
          certificateUuid,
          certificateIssuedAt: certificateUuid ? new Date() : null,
          completedAt: new Date()
        }
      });

      if (!existingCompletion) {
        await grantUserExpAndCheckAchievements(userId, 200, 'course_completed', prisma);
      }
    }
  } catch (err) {
    console.error(`Error in checkAndCompleteCourse for user ${userId}, course ${courseId}:`, err);
  }
}

app.post('/courses/:id/complete', authMiddleware, async (req, res) => {
  try {
    const courseId = parseInt(req.params.id);

    const course = await prisma.course.findUnique({ where: { id: courseId } });
    if (!course) return res.status(404).json({ error: 'Курс не найден' });

    // Evaluate certificate and progression constraints
    const certResult = await evaluateAndIssueCertificate(req.user.id, courseId);

    // Award +200 EXP on completing course
    const result = await grantUserExpAndCheckAchievements(req.user.id, 200, 'course_completed', prisma);

    res.json({
      message: 'Курс успешно завершен и сертификат выдан!',
      certificateUuid: certResult.uuid,
      expGained: 200,
      currentExp: result?.exp,
      currentLevel: result?.level,
      newlyUnlocked: result?.newlyUnlocked
    });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/courses/steps/:stepId/start', authMiddleware, async (req, res) => {
  try {
    const stepId = parseInt(req.params.stepId);
    const step = await prisma.courseStep.findUnique({
      where: { id: stepId }
    });
    if (!step) return res.status(404).json({ error: 'Шаг не найден' });

    // Verify progression and blocks
    try {
      await verifyStepAccessHelper(req.user.id, step);
    } catch (err) {
      return res.status(403).json({ error: err.message });
    }

    let progress = await prisma.userLessonProgress.findUnique({
      where: { userId_stepId: { userId: req.user.id, stepId } }
    });

    if (!progress) {
      progress = await prisma.userLessonProgress.create({
        data: {
          userId: req.user.id,
          stepId,
          status: 'in_progress',
          lessonStartedAt: new Date()
        }
      });
    } else if (progress.status === 'not_started') {
      progress = await prisma.userLessonProgress.update({
        where: { id: progress.id },
        data: {
          status: 'in_progress',
          lessonStartedAt: new Date()
        }
      });
    } else if (!progress.lessonStartedAt) {
      progress = await prisma.userLessonProgress.update({
        where: { id: progress.id },
        data: {
          lessonStartedAt: new Date()
        }
      });
    }

    // Calculate word count and estimated read time if it's text
    let estimatedReadTimeSeconds = 0;
    if (step.type === 'text' && step.content) {
      const wordCount = step.content.split(/\s+/).filter(Boolean).length;
      estimatedReadTimeSeconds = Math.ceil((wordCount / 200) * 60);
    }

    res.json({
      progress,
      estimatedReadTimeSeconds,
      videoDurationSeconds: step.videoDurationSeconds
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/courses/steps/:stepId/complete', authMiddleware, async (req, res) => {
  try {
    const stepId = parseInt(req.params.stepId);
    const { scrollCompleted, timeSpentSeconds } = req.body;

    const step = await prisma.courseStep.findUnique({
      where: { id: stepId },
      include: { course: true }
    });
    if (!step) return res.status(404).json({ error: 'Шаг не найден' });

    // Check course lock and blocks
    try {
      await verifyStepAccessHelper(req.user.id, step);
    } catch (err) {
      return res.status(403).json({ error: err.message });
    }

    // Get current progress
    let progress = await prisma.userLessonProgress.findUnique({
      where: { userId_stepId: { userId: req.user.id, stepId } }
    });
    if (!progress) {
      return res.status(400).json({ error: 'Урок не был запущен. Сначала откройте урок.' });
    }

    const now = new Date();
    const elapsedSeconds = progress.lessonStartedAt ? Math.floor((now.getTime() - progress.lessonStartedAt.getTime()) / 1000) : 0;

    if (step.type === 'text') {
      const wordCount = step.content ? step.content.split(/\s+/).filter(Boolean).length : 0;
      const estimatedReadTime = Math.ceil((wordCount / 200) * 60);

      // Verify scroll Completed
      if (!scrollCompleted) {
        return res.status(400).json({ error: 'Необходимо прокрутить страницу до конца.' });
      }

      // Verify time spent (use max of server-side elapsed time and client-side time)
      const actualTimeSpent = Math.max(elapsedSeconds, timeSpentSeconds || 0);
      if (actualTimeSpent < estimatedReadTime) {
        return res.status(400).json({
          error: `Вы провели слишком мало времени на странице. Минимальное время чтения: ${estimatedReadTime} сек. (Прошло: ${actualTimeSpent} сек.)`
        });
      }

      progress = await prisma.userLessonProgress.update({
        where: { id: progress.id },
        data: {
          status: 'completed',
          scrollCompleted: true,
          timeSpentSeconds: actualTimeSpent
        }
      });
    } else if (step.type === 'video') {
      const duration = step.videoDurationSeconds || 0;
      const actualTimeSpent = Math.max(elapsedSeconds, timeSpentSeconds || 0);

      if (actualTimeSpent < duration) {
        const remaining = duration - actualTimeSpent;
        return res.status(400).json({
          error: `Видео еще не просмотрено. До завершения осталось ${remaining} секунд.`
        });
      }

      progress = await prisma.userLessonProgress.update({
        where: { id: progress.id },
        data: {
          status: 'completed',
          isTimerCompleted: true,
          timeSpentSeconds: actualTimeSpent
        }
      });
    } else if (step.type === 'quiz') {
      return res.status(400).json({ error: 'Тесты необходимо сдавать через специальную отправку.' });
    }

    // Award +50 EXP on completing step
    const result = await grantUserExpAndCheckAchievements(req.user.id, 50, 'course_step', prisma);

    // Auto complete course check
    await checkAndCompleteCourse(req.user.id, step.courseId);

    res.json({
      progress,
      message: 'Шаг успешно пройден!',
      expGained: 50,
      currentExp: result?.exp,
      currentLevel: result?.level,
      newlyUnlocked: result?.newlyUnlocked
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/courses/steps/:stepId/quiz', authMiddleware, async (req, res) => {
  try {
    const stepId = parseInt(req.params.stepId);
    const step = await prisma.courseStep.findUnique({
      where: { id: stepId }
    });
    if (!step) return res.status(404).json({ error: 'Шаг не найден' });
    if (step.type !== 'quiz') return res.status(400).json({ error: 'Этот шаг не является квизом' });

    // Verify progression and blocks
    try {
      await verifyStepAccessHelper(req.user.id, step);
    } catch (err) {
      return res.status(403).json({ error: err.message });
    }

    // Get progress and check attempts & cooldowns
    const progress = await prisma.userLessonProgress.findUnique({
      where: { userId_stepId: { userId: req.user.id, stepId } }
    });

    if (progress) {
      if (progress.cooldownUntil && progress.cooldownUntil > new Date()) {
        const remainingMs = progress.cooldownUntil.getTime() - Date.now();
        const remainingMinutes = Math.ceil(remainingMs / 1000 / 60);
        return res.status(403).json({
          error: `Повторная попытка временно заблокирована. Пожалуйста, подождите ${remainingMinutes} мин.`,
          cooldownUntil: progress.cooldownUntil
        });
      }
      if (progress.quizAttempts >= 5) {
        return res.status(403).json({
          error: 'Вы исчерпали все 5 попыток прохождения этого теста. Пожалуйста, обратитесь к администратору для сброса ограничений.'
        });
      }
    }

    // Parse questions
    let questions = [];
    if (typeof step.questions === 'string') {
      questions = JSON.parse(step.questions);
    } else if (Array.isArray(step.questions)) {
      questions = step.questions;
    }

    // Shuffle questions and their options, delete answers
    const shuffledQuestions = shuffleArray(JSON.parse(JSON.stringify(questions))).map(q => {
      q.options = shuffleArray(q.options);
      delete q.answer; // Secure! Never send answer indices to client.
      return q;
    });

    res.json({
      stepId: step.id,
      title: step.title,
      questions: shuffledQuestions,
      attemptsUsed: progress ? progress.quizAttempts : 0
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/courses/steps/:stepId/quiz-submit', authMiddleware, async (req, res) => {
  try {
    const stepId = parseInt(req.params.stepId);
    const { answers } = req.body; // Array of { question, selectedOption }

    if (!answers || !Array.isArray(answers)) {
      return res.status(400).json({ error: 'Некорректный формат ответов' });
    }

    const step = await prisma.courseStep.findUnique({
      where: { id: stepId },
      include: { course: true }
    });
    if (!step) return res.status(404).json({ error: 'Шаг не найден' });
    if (step.type !== 'quiz') return res.status(400).json({ error: 'Этот шаг не является квизом' });

    // Verify progression and blocks
    try {
      await verifyStepAccessHelper(req.user.id, step);
    } catch (err) {
      return res.status(403).json({ error: err.message });
    }

    // Get progress
    let progress = await prisma.userLessonProgress.findUnique({
      where: { userId_stepId: { userId: req.user.id, stepId } }
    });

    if (progress) {
      if (progress.cooldownUntil && progress.cooldownUntil > new Date()) {
        return res.status(403).json({ error: 'Квиз находится на кулдауне.' });
      }
      if (progress.quizAttempts >= 5) {
        return res.status(403).json({ error: 'Все попытки исчерпаны.' });
      }
    }

    // Parse original questions from DB
    let originalQuestions = [];
    if (typeof step.questions === 'string') {
      originalQuestions = JSON.parse(step.questions);
    } else if (Array.isArray(step.questions)) {
      originalQuestions = step.questions;
    }

    let correctCount = 0;
    const failedTopics = new Set();

    originalQuestions.forEach(q => {
      // Find user answer for this question
      const userAnswer = answers.find(a => a.question === q.question);
      const correctAnswerText = q.options[q.answer];

      if (userAnswer && userAnswer.selectedOption === correctAnswerText) {
        correctCount++;
      } else {
        if (q.topic) {
          failedTopics.add(q.topic);
        } else {
          failedTopics.add('Общая тема');
        }
      }
    });

    const scorePercent = originalQuestions.length > 0 ? (correctCount / originalQuestions.length) * 100 : 100;
    
    // Passing threshold: 95% for final exam, 80% for other quizzes
    const passingScore = step.isFinalExam ? 95 : 80;
    const passed = scorePercent >= passingScore;

    let updatedLives = req.user.courseLives;
    const isRegularUser = !['superadmin', 'admin', 'supersupport', 'support', 'superuser'].includes(req.user.role);
    if (!passed && isRegularUser) {
      updatedLives = Math.max(0, req.user.courseLives - 1);
      await prisma.user.update({
        where: { id: req.user.id },
        data: {
          courseLives: updatedLives,
          livesRestoredAt: req.user.courseLives === 3 ? new Date() : req.user.livesRestoredAt
        }
      });
      req.user.courseLives = updatedLives;
    }

    const newAttempts = (progress ? progress.quizAttempts : 0) + 1;
    let cooldownUntil = null;

    if (!passed) {
      if (newAttempts === 2) {
        cooldownUntil = new Date(Date.now() + 30 * 60 * 1000); // 30 mins
      } else if (newAttempts === 4) {
        cooldownUntil = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
      }
    }

    // Save progress
    if (!progress) {
      progress = await prisma.userLessonProgress.create({
        data: {
          userId: req.user.id,
          stepId,
          status: passed ? 'completed' : 'in_progress',
          timeSpentSeconds: passed ? Math.round(scorePercent) : 0, // Storing quiz score in timeSpentSeconds
          quizAttempts: newAttempts,
          cooldownUntil
        }
      });
    } else {
      progress = await prisma.userLessonProgress.update({
        where: { id: progress.id },
        data: {
          status: passed ? 'completed' : progress.status,
          timeSpentSeconds: passed ? Math.round(scorePercent) : progress.timeSpentSeconds,
          quizAttempts: newAttempts,
          cooldownUntil: cooldownUntil || (passed ? null : progress.cooldownUntil)
        }
      });
    }

    // Calculate details for certificate check
    let certificateIssued = false;
    let certificateUuid = null;
    let errorIssuingCertificate = null;

    if (passed) {
      await checkAndCompleteCourse(req.user.id, step.courseId);

      if (step.isFinalExam) {
        const completion = await prisma.courseCompletion.findUnique({
          where: { userId_courseId: { userId: req.user.id, courseId: step.courseId } }
        });
        if (completion && completion.certificateUuid) {
          certificateIssued = true;
          certificateUuid = completion.certificateUuid;
        } else {
          try {
            await evaluateAndIssueCertificate(req.user.id, step.courseId);
          } catch (err) {
            errorIssuingCertificate = err.message;
          }
        }
      }
    }

    // Grant EXP if passed
    let expGained = 0;
    let levelResult = null;
    if (passed) {
      expGained = step.isFinalExam ? 150 : 80; // More exp for final exam
      levelResult = await grantUserExpAndCheckAchievements(req.user.id, expGained, 'course_step', prisma);
    }

    res.json({
      success: passed,
      score: scorePercent,
      correctCount,
      totalCount: originalQuestions.length,
      attemptsUsed: newAttempts,
      cooldownUntil,
      failedTopics: passed ? [] : Array.from(failedTopics),
      expGained,
      currentExp: levelResult?.exp,
      currentLevel: levelResult?.level,
      certificateIssued,
      certificateUuid,
      errorIssuingCertificate,
      courseLives: updatedLives
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/courses/steps/:stepId/violation', authMiddleware, async (req, res) => {
  try {
    const stepId = parseInt(req.params.stepId);
    const step = await prisma.courseStep.findUnique({
      where: { id: stepId }
    });
    if (!step) return res.status(404).json({ error: 'Шаг не найден' });

    // Save violation log
    const violation = await prisma.screenshotViolation.create({
      data: {
        userId: req.user.id,
        stepId
      }
    });

    // Count violations in this course
    const courseViolationsCount = await prisma.screenshotViolation.count({
      where: {
        userId: req.user.id,
        step: {
          courseId: step.courseId
        }
      }
    });

    const thresholdSetting = await getSystemSetting('screenshotBlockThreshold', '5');
    const threshold = parseInt(thresholdSetting) || 5;

    const durationSetting = await getSystemSetting('screenshotBlockDurationHours', '24');
    const durationHours = parseInt(durationSetting) || 24;

    let blocked = false;
    let blockedUntil = null;

    if (courseViolationsCount >= threshold) {
      blocked = true;
      blockedUntil = new Date(Date.now() + durationHours * 60 * 60 * 1000);
      await prisma.userCourseBlock.upsert({
        where: {
          userId_courseId: {
            userId: req.user.id,
            courseId: step.courseId
          }
        },
        update: {
          blockedAt: new Date(),
          blockedUntil
        },
        create: {
          userId: req.user.id,
          courseId: step.courseId,
          blockedAt: new Date(),
          blockedUntil
        }
      });

      // Send telegram notification to admins
      try {
        const botToken = process.env.TELEGRAM_BOT_TOKEN;
        const telegramAdminChatId = await getSystemSetting('telegramAdminChatId', process.env.TELEGRAM_ADMIN_CHAT_ID || '');
        if (botToken && telegramAdminChatId) {
          const course = await prisma.course.findUnique({ where: { id: step.courseId } });
          const user = req.user;
          const msg = `⚠️ [Нарушение] Пользователь ${user.name} (${user.email}, ID: ${user.id}) автоматически заблокирован в курсе "${course?.title || 'Unknown'}" на ${durationHours} ч. из-за превышения порога скриншотов (${courseViolationsCount}/${threshold}).`;
          
          const chatIds = telegramAdminChatId.split(',').map(id => id.trim()).filter(Boolean);
          for (const chatId of chatIds) {
            await sendTelegramMessage(botToken, chatId, msg).catch(err => {
              console.error(`Error sending message to chatId ${chatId}:`, err.message);
            });
          }
        }
      } catch (err) {
        console.error('Error sending screenshot block telegram notification:', err.message);
      }
    }

    res.json({
      success: true,
      violationCount: courseViolationsCount,
      blocked,
      blockedUntil
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/courses/:id', async (req, res) => {
  try {
    const course = await prisma.course.findUnique({
      where: { id: parseInt(req.params.id) },
      include: { steps: { orderBy: { order: 'asc' } } },
    });
    if (!course) return res.status(404).json({ error: 'Не найдено' });

    const userId = getUserIdFromToken(req);
    let userRole = 'user';
    let completedCourseIds = [];
    const progressMap = {};

    if (userId) {
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (user) {
        userRole = user.role;
      }
      const completions = await prisma.courseCompletion.findMany({
        where: { userId }
      });
      completedCourseIds = completions.map(c => c.courseId);

      const progresses = await prisma.userLessonProgress.findMany({
        where: { userId }
      });
      progresses.forEach(p => {
        progressMap[p.stepId] = p;
      });
    }

    let isLocked = false;
    const allCourses = await prisma.course.findMany({ orderBy: { id: 'asc' } });
    const index = allCourses.findIndex(c => c.id === course.id);
    if (index > 0) {
      const prevCourse = allCourses[index - 1];
      isLocked = !completedCourseIds.includes(prevCourse.id);
    }
    if (['superuser', 'superadmin', 'admin', 'supersupport', 'support'].includes(userRole)) {
      isLocked = false;
    }

    let prevStepCompleted = true;
    const stepsWithProgress = course.steps.map((step) => {
      let stepLocked = false;
      const progress = progressMap[step.id];

      if (['superuser', 'superadmin', 'admin', 'supersupport', 'support'].includes(userRole)) {
        stepLocked = false;
      } else {
        if (step.isFinalExam) {
          const otherSteps = course.steps.filter(s => s.id !== step.id);
          const anyIncomplete = otherSteps.some(s => {
            const prog = progressMap[s.id];
            return !prog || prog.status !== 'completed';
          });
          stepLocked = anyIncomplete;
        } else {
          stepLocked = !prevStepCompleted;
        }
      }

      prevStepCompleted = progress && progress.status === 'completed';

      return {
        ...step,
        userProgress: progress ? {
          id: progress.id,
          userId: progress.userId,
          stepId: progress.stepId,
          status: progress.status,
          scrollCompleted: progress.scrollCompleted,
          timeSpentSeconds: progress.timeSpentSeconds,
          lessonStartedAt: progress.lessonStartedAt,
          isTimerCompleted: progress.isTimerCompleted,
          quizAttempts: progress.quizAttempts,
          cooldownUntil: progress.cooldownUntil
        } : null,
        isLocked: stepLocked
      };
    });

    res.json({
      ...course,
      steps: stepsWithProgress,
      isLocked
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/users/action/trigger-weather', authMiddleware, async (req, res) => {
  try {
    const result = await grantUserExpAndCheckAchievements(req.user.id, 100, 'weather_check', prisma);
    res.json({
      message: 'Погода успешно проверена!',
      expGained: 100,
      currentExp: result?.exp,
      currentLevel: result?.level,
      newlyUnlocked: result?.newlyUnlocked
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/courses', adminMiddleware, async (req, res) => {
  try {
    const { title, description, iconType, color, miniDescription, authorName } = req.body;
    const course = await prisma.course.create({
      data: {
        title,
        description,
        iconType,
        color,
        miniDescription: miniDescription || '',
        authorName: authorName || ''
      }
    });
    res.json(course);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/courses/:id', adminMiddleware, async (req, res) => {
  try {
    const { title, description, iconType, color, miniDescription, authorName } = req.body;
    const course = await prisma.course.update({
      where: { id: parseInt(req.params.id) },
      data: {
        title,
        description,
        iconType,
        color,
        miniDescription: miniDescription ?? '',
        authorName: authorName ?? ''
      },
    });
    res.json(course);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/courses/:id', adminMiddleware, async (req, res) => {
  try {
    await prisma.course.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Course Steps
app.post('/courses/:id/steps', adminMiddleware, async (req, res) => {
  try {
    const { type, title, content, questions, order, imageUrl } = req.body;
    const step = await prisma.courseStep.create({
      data: { courseId: parseInt(req.params.id), type, title, content, questions, order: parseInt(order), imageUrl },
    });
    res.json(step);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/courses/:courseId/steps/:stepId', adminMiddleware, async (req, res) => {
  try {
    const { type, title, content, questions, order, imageUrl } = req.body;
    const step = await prisma.courseStep.update({
      where: { id: parseInt(req.params.stepId) },
      data: { type, title, content, questions, order: parseInt(order), imageUrl },
    });
    res.json(step);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/courses/:courseId/steps/:stepId', adminMiddleware, async (req, res) => {
  try {
    await prisma.courseStep.delete({ where: { id: parseInt(req.params.stepId) } });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// ADMIN — USERS & STATS
// ─────────────────────────────────────────────
app.get('/admin/users', adminMiddleware, async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      select: { id: true, email: true, name: true, role: true, isBlocked: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json(users);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/admin/users-dashboard', adminMiddleware, async (req, res) => {
  try {
    const { search, sort, order } = req.query; // sort: "startDate" | "progress" | "lastActivity"; order: "asc" | "desc"
    
    // Fetch all courses to know step counts
    const courses = await prisma.course.findMany({
      include: { steps: true }
    });
    const courseStepCounts = {};
    courses.forEach(c => {
      courseStepCounts[c.id] = c.steps.length;
    });

    // Fetch all users with their lesson progress
    const users = await prisma.user.findMany({
      include: {
        lessonProgress: {
          include: { step: true }
        }
      }
    });

    const dashboardData = [];

    for (const user of users) {
      // Group progress by courseId
      const courseGroups = {};
      user.lessonProgress.forEach(lp => {
        const cId = lp.step.courseId;
        if (!courseGroups[cId]) courseGroups[cId] = [];
        courseGroups[cId].push(lp);
      });

      for (const cId in courseGroups) {
        const progressList = courseGroups[cId];
        const courseId = parseInt(cId);
        const course = courses.find(c => c.id === courseId);
        if (!course) continue;

        const completedCount = progressList.filter(lp => lp.status === 'completed').length;
        const totalSteps = courseStepCounts[courseId] || 1;
        const progressPercent = Math.round((completedCount / totalSteps) * 100);

        const startTimes = progressList.map(lp => lp.lessonStartedAt).filter(Boolean);
        const updateTimes = progressList.map(lp => lp.updatedAt).filter(Boolean);

        const startDate = startTimes.length > 0 ? new Date(Math.min(...startTimes.map(d => d.getTime()))) : new Date();
        const lastActivity = updateTimes.length > 0 ? new Date(Math.max(...updateTimes.map(d => d.getTime()))) : new Date();

        dashboardData.push({
          userId: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          isBlocked: user.isBlocked,
          courseId,
          courseTitle: course.title,
          startDate,
          lastActivity,
          progressPercent
        });
      }
    }

    // Filter by search
    let filtered = dashboardData;
    if (search) {
      const s = search.toLowerCase();
      filtered = filtered.filter(row => row.name.toLowerCase().includes(s) || row.email.toLowerCase().includes(s));
    }

    // Sort
    if (sort) {
      const ord = order === 'desc' ? -1 : 1;
      filtered.sort((a, b) => {
        if (sort === 'startDate') {
          return (a.startDate.getTime() - b.startDate.getTime()) * ord;
        } else if (sort === 'progress') {
          return (a.progressPercent - b.progressPercent) * ord;
        } else if (sort === 'lastActivity') {
          return (a.lastActivity.getTime() - b.lastActivity.getTime()) * ord;
        }
        return 0;
      });
    } else {
      // Default sort by last activity desc
      filtered.sort((a, b) => b.lastActivity.getTime() - a.lastActivity.getTime());
    }

    res.json(filtered);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// USER SESSION MANAGEMENT
// ─────────────────────────────────────────────
app.get('/admin/users/:id/sessions', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const sessions = await prisma.session.findMany({
      where: { userId, isRevoked: false },
      orderBy: { lastActive: 'desc' }
    });
    res.json(sessions);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/users/:id/sessions/revoke-all', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    await prisma.session.updateMany({
      where: { userId, isRevoked: false },
      data: { isRevoked: true }
    });

    // Log action
    await prisma.adminAction.create({
      data: {
        adminId: req.user.id,
        actionType: 'revoke_all_sessions',
        targetUserId: userId,
        details: 'Сброшены все активные сессии пользователя'
      }
    });

    res.json({ success: true, message: 'Все сессии пользователя успешно завершены' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/sessions/:sessionId/revoke', adminMiddleware, async (req, res) => {
  try {
    const sessionId = parseInt(req.params.sessionId);
    const session = await prisma.session.findUnique({ where: { id: sessionId } });
    if (!session) return res.status(404).json({ error: 'Сессия не найдена' });

    await prisma.session.update({
      where: { id: sessionId },
      data: { isRevoked: true }
    });

    // Log action
    await prisma.adminAction.create({
      data: {
        adminId: req.user.id,
        actionType: 'revoke_session',
        targetUserId: session.userId,
        details: `Сброшена сессия ID: ${sessionId} (IP: ${session.ipAddress || '—'})`
      }
    });

    res.json({ success: true, message: 'Сессия успешно завершена' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/admin/users/:id/detail', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        isBlocked: true,
        blockedAt: true,
        blockedBy: true,
        blockReason: true,
        courseLives: true,
        livesRestoredAt: true,
        phone: true,
        dob: true,
        country: true,
        level: true,
        exp: true,
        createdAt: true,
        avatar: true,
        language: true
      }
    });
    if (!user) return res.status(404).json({ error: 'Пользователь не найден' });

    // Fetch all courses and steps
    const courses = await prisma.course.findMany({
      include: {
        steps: {
          orderBy: { order: 'asc' }
        }
      },
      orderBy: { id: 'asc' }
    });

    // Fetch user progress for this user
    const progresses = await prisma.userLessonProgress.findMany({
      where: { userId },
      include: { step: true }
    });
    const progressMap = new Map(progresses.map(p => [p.stepId, p]));

    // Build courses details
    const courseDetails = courses.map(course => {
      let completedCount = 0;
      const steps = course.steps.map(step => {
        const prog = progressMap.get(step.id);
        const status = prog ? prog.status : 'not_started';
        if (status === 'completed') completedCount++;

        return {
          id: step.id,
          title: step.title,
          type: step.type,
          isFinalExam: step.isFinalExam,
          status,
          lessonStartedAt: prog ? prog.lessonStartedAt : null,
          timeSpentSeconds: prog ? prog.timeSpentSeconds : 0,
          isTimerCompleted: prog ? prog.isTimerCompleted : false,
          quizAttempts: prog ? prog.quizAttempts : 0,
          cooldownUntil: prog ? prog.cooldownUntil : null,
          updatedAt: prog ? prog.updatedAt : null
        };
      });

      const totalSteps = course.steps.length || 1;
      const progressPercent = Math.round((completedCount / totalSteps) * 100);

      return {
        courseId: course.id,
        courseTitle: course.title,
        progressPercent,
        steps
      };
    });

    // Fetch timeline of user activity:
    const violations = await prisma.screenshotViolation.findMany({
      where: { userId },
      include: { step: true },
      orderBy: { timestamp: 'desc' }
    });

    const timeline = [];
    progresses.forEach(p => {
      timeline.push({
        type: 'progress_update',
        timestamp: p.updatedAt,
        message: `Урок "${p.step.title}": статус изменен на "${p.status}"`
      });
      if (p.lessonStartedAt) {
        timeline.push({
          type: 'lesson_started',
          timestamp: p.lessonStartedAt,
          message: `Начато изучение урока "${p.step.title}"`
        });
      }
    });

    violations.forEach(v => {
      timeline.push({
        type: 'violation',
        timestamp: v.timestamp,
        message: `Нарушение политики скриншотов на уроке "${v.step.title}"`
      });
    });

    // Sort timeline desc by timestamp
    timeline.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    // Admin notifications flags
    const exhaustedAttempts = progresses.some(p => p.quizAttempts >= 5);
    
    // Check if blocked by screenshots in UserCourseBlock
    const courseBlock = await prisma.userCourseBlock.findFirst({
      where: { userId, blockedUntil: { gt: new Date() } }
    });
    const screenshotBlocked = !!courseBlock;

    // Check inactivity: last progress update older than 7 days, and at least one course is started but not 100% complete
    let inactiveAlert = false;
    if (progresses.length > 0) {
      const lastUpdate = new Date(Math.max(...progresses.map(p => p.updatedAt.getTime())));
      const daysInactive = (Date.now() - lastUpdate.getTime()) / 1000 / 60 / 60 / 24;
      
      const incompleteCourseExists = courseDetails.some(cd => cd.progressPercent > 0 && cd.progressPercent < 100);
      if (daysInactive > 7 && incompleteCourseExists) {
        inactiveAlert = true;
      }
    }

    if (user && ['superadmin', 'admin', 'supersupport', 'support', 'superuser'].includes(user.role)) {
      user.courseLives = 3;
    }

    // Fetch user's orders, support requests, and achievements
    const orders = await prisma.order.findMany({
      where: { userId },
      include: {
        items: {
          include: { product: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    const supportRequests = await prisma.supportRequest.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' }
    });

    const achievements = await prisma.userAchievement.findMany({
      where: { userId },
      orderBy: { unlockedAt: 'desc' }
    });

    const sessions = await prisma.session.findMany({
      where: { userId, isRevoked: false },
      orderBy: { lastActive: 'desc' }
    });

    res.json({
      user,
      courses: courseDetails,
      timeline: timeline.slice(0, 50),
      orders,
      supportRequests,
      achievements,
      sessions,
      notifications: {
        exhaustedAttempts,
        screenshotBlocked,
        inactiveAlert
      }
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/users/:id/block', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const { reason } = req.body;

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return res.status(404).json({ error: 'Пользователь не найден' });

    await prisma.$transaction([
      prisma.user.update({
        where: { id: userId },
        data: {
          isBlocked: true,
          blockedAt: new Date(),
          blockedBy: req.user.name,
          blockReason: reason
        }
      }),
      prisma.userBlock.create({
        data: {
          userId,
          blockedBy: req.user.name,
          reason
        }
      }),
      prisma.adminAction.create({
        data: {
          adminId: req.user.id,
          actionType: 'BLOCK_USER',
          targetUserId: userId,
          details: reason
        }
      })
    ]);

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/users/:id/unblock', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return res.status(404).json({ error: 'Пользователь не найден' });

    const activeBlock = await prisma.userBlock.findFirst({
      where: { userId, unblockedAt: null },
      orderBy: { blockedAt: 'desc' }
    });

    await prisma.$transaction([
      prisma.user.update({
        where: { id: userId },
        data: {
          isBlocked: false,
          blockedAt: null,
          blockedBy: null,
          blockReason: null
        }
      }),
      ...(activeBlock ? [
        prisma.userBlock.update({
          where: { id: activeBlock.id },
          data: { unblockedAt: new Date() }
        })
      ] : []),
      prisma.adminAction.create({
        data: {
          adminId: req.user.id,
          actionType: 'UNBLOCK_USER',
          targetUserId: userId
        }
      })
    ]);

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/users/:id/reset-quiz', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const { stepId } = req.body;

    const progress = await prisma.userLessonProgress.findUnique({
      where: { userId_stepId: { userId, stepId: parseInt(stepId) } }
    });

    if (!progress) {
      return res.status(404).json({ error: 'Прогресс по данному шагу не найден' });
    }

    await prisma.$transaction([
      prisma.userLessonProgress.update({
        where: { id: progress.id },
        data: {
          status: 'not_started',
          quizAttempts: 0,
          cooldownUntil: null,
          timeSpentSeconds: 0
        }
      }),
      prisma.adminAction.create({
        data: {
          adminId: req.user.id,
          actionType: 'RESET_QUIZ_ATTEMPTS',
          targetUserId: userId,
          details: `Step ID: ${stepId}`
        }
      })
    ]);

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/users/:id/reset-timer', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const { stepId } = req.body;

    const progress = await prisma.userLessonProgress.findUnique({
      where: { userId_stepId: { userId, stepId: parseInt(stepId) } }
    });

    if (!progress) {
      return res.status(404).json({ error: 'Прогресс по данному шагу не найден' });
    }

    await prisma.$transaction([
      prisma.userLessonProgress.update({
        where: { id: progress.id },
        data: {
          status: 'not_started',
          lessonStartedAt: null,
          isTimerCompleted: false,
          timeSpentSeconds: 0
        }
      }),
      prisma.userCourseBlock.deleteMany({
        where: { userId }
      }),
      prisma.adminAction.create({
        data: {
          adminId: req.user.id,
          actionType: 'RESET_LESSON_TIMER',
          targetUserId: userId,
          details: `Step ID: ${stepId}`
        }
      })
    ]);

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/admin/users/:id/role', adminMiddleware, async (req, res) => {
  try {
    const { role } = req.body;
    const user = await prisma.user.update({
      where: { id: parseInt(req.params.id) },
      data: { role },
      select: { id: true, email: true, name: true, role: true, createdAt: true },
    });
    res.json(user);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/admin/users/:id', adminMiddleware, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const ordersCount = await prisma.order.count({ where: { userId: id } });
    if (ordersCount > 0) {
      return res.status(400).json({ error: 'Невозможно удалить пользователя, так как у него есть связанные заказы' });
    }
    await prisma.user.delete({ where: { id } });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// New Lives/Course admin management routes
app.post('/admin/users/:id/add-lives', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const { amount } = req.body;
    const addAmount = parseInt(amount) || 1;

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return res.status(404).json({ error: 'Пользователь не найден' });

    const newLives = Math.min(3, user.courseLives + addAmount);

    const updated = await prisma.user.update({
      where: { id: userId },
      data: {
        courseLives: newLives,
        livesRestoredAt: newLives === 3 ? null : user.livesRestoredAt
      }
    });

    await prisma.adminAction.create({
      data: {
        adminId: req.user.id,
        actionType: 'ADD_LIVES',
        targetUserId: userId,
        details: `Добавлено жизней: ${addAmount}. Текущее кол-во: ${newLives}`
      }
    });

    res.json({ success: true, courseLives: updated.courseLives });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/users/:id/complete-course', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const { courseId } = req.body;

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return res.status(404).json({ error: 'Пользователь не найден' });

    const course = await prisma.course.findUnique({
      where: { id: parseInt(courseId) },
      include: { steps: true }
    });
    if (!course) return res.status(404).json({ error: 'Курс не найден' });

    const queries = [];
    for (const step of course.steps) {
      queries.push(
        prisma.userLessonProgress.upsert({
          where: { userId_stepId: { userId, stepId: step.id } },
          update: {
            status: 'completed',
            isTimerCompleted: step.type === 'video',
            scrollCompleted: step.type === 'text',
            timeSpentSeconds: step.type === 'quiz' ? 100 : (step.videoDurationSeconds || 60),
            updatedAt: new Date()
          },
          create: {
            userId,
            stepId: step.id,
            status: 'completed',
            isTimerCompleted: step.type === 'video',
            scrollCompleted: step.type === 'text',
            timeSpentSeconds: step.type === 'quiz' ? 100 : (step.videoDurationSeconds || 60),
            lessonStartedAt: new Date()
          }
        })
      );
    }

    queries.push(
      prisma.courseCompletion.upsert({
        where: { userId_courseId: { userId, courseId: course.id } },
        update: {
          lessonsCompletionPercent: 100,
          finalScore: 100,
          studentName: user.name,
          certificateIssuedAt: new Date(),
          certificateUuid: crypto.randomUUID()
        },
        create: {
          userId,
          courseId: course.id,
          lessonsCompletionPercent: 100,
          finalScore: 100,
          studentName: user.name,
          certificateIssuedAt: new Date(),
          certificateUuid: crypto.randomUUID()
        }
      })
    );

    queries.push(
      prisma.userCourseBlock.deleteMany({
        where: { userId, courseId: course.id }
      })
    );

    queries.push(
      prisma.adminAction.create({
        data: {
          adminId: req.user.id,
          actionType: 'COMPLETE_COURSE',
          targetUserId: userId,
          details: `Курс: ${course.title}`
        }
      })
    );

    await prisma.$transaction(queries);

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/users/:id/reset-course', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const { courseId } = req.body;

    const course = await prisma.course.findUnique({
      where: { id: parseInt(courseId) },
      include: { steps: true }
    });
    if (!course) return res.status(404).json({ error: 'Курс не найден' });

    const stepIds = course.steps.map(s => s.id);

    await prisma.$transaction([
      prisma.userLessonProgress.deleteMany({
        where: { userId, stepId: { in: stepIds } }
      }),
      prisma.courseCompletion.deleteMany({
        where: { userId, courseId: course.id }
      }),
      prisma.userCourseBlock.deleteMany({
        where: { userId, courseId: course.id }
      }),
      prisma.adminAction.create({
        data: {
          adminId: req.user.id,
          actionType: 'RESET_COURSE',
          targetUserId: userId,
          details: `Курс: ${course.title}`
        }
      })
    ]);

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/users/:id/complete-all-courses', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return res.status(404).json({ error: 'Пользователь не найден' });

    const courses = await prisma.course.findMany({
      include: { steps: true }
    });

    const queries = [];
    for (const course of courses) {
      for (const step of course.steps) {
        queries.push(
          prisma.userLessonProgress.upsert({
            where: { userId_stepId: { userId, stepId: step.id } },
            update: {
              status: 'completed',
              isTimerCompleted: step.type === 'video',
              scrollCompleted: step.type === 'text',
              timeSpentSeconds: step.type === 'quiz' ? 100 : (step.videoDurationSeconds || 60),
              updatedAt: new Date()
            },
            create: {
              userId,
              stepId: step.id,
              status: 'completed',
              isTimerCompleted: step.type === 'video',
              scrollCompleted: step.type === 'text',
              timeSpentSeconds: step.type === 'quiz' ? 100 : (step.videoDurationSeconds || 60),
              lessonStartedAt: new Date()
            }
          })
        );
      }

      queries.push(
        prisma.courseCompletion.upsert({
          where: { userId_courseId: { userId, courseId: course.id } },
          update: {
            lessonsCompletionPercent: 100,
            finalScore: 100,
            studentName: user.name,
            certificateIssuedAt: new Date(),
            certificateUuid: crypto.randomUUID()
          },
          create: {
            userId,
            courseId: course.id,
            lessonsCompletionPercent: 100,
            finalScore: 100,
            studentName: user.name,
            certificateIssuedAt: new Date(),
            certificateUuid: crypto.randomUUID()
          }
        })
      );
    }

    queries.push(
      prisma.userCourseBlock.deleteMany({
        where: { userId }
      })
    );

    queries.push(
      prisma.adminAction.create({
        data: {
          adminId: req.user.id,
          actionType: 'COMPLETE_ALL_COURSES',
          targetUserId: userId
        }
      })
    );

    await prisma.$transaction(queries);

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/create-superuser', superAdminMiddleware, async (req, res) => {
  try {
    const { name, email, password } = req.body;
    if (!name || !email || !password) return res.status(400).json({ error: 'Все поля обязательны' });

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return res.status(400).json({ error: 'Пользователь с таким email уже существует' });

    const hashedPassword = await bcrypt.hash(password, 10);

    const superuser = await prisma.user.create({
      data: {
        name,
        email,
        password: hashedPassword,
        role: 'superuser',
        courseLives: 3
      }
    });

    await prisma.adminAction.create({
      data: {
        adminId: req.user.id,
        actionType: 'CREATE_SUPERUSER',
        targetUserId: superuser.id,
        details: `Создан суперюзер: ${email}`
      }
    });

    res.json({ success: true, user: { id: superuser.id, name: superuser.name, email: superuser.email, role: superuser.role } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/create-user', adminMiddleware, async (req, res) => {
  try {
    const { name, email, password } = req.body;
    if (!name || !email || !password) return res.status(400).json({ error: 'Все поля обязательны' });

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return res.status(400).json({ error: 'Пользователь с таким email уже существует' });

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        name,
        email,
        password: hashedPassword,
        role: 'user',
        courseLives: 3
      }
    });

    await prisma.adminAction.create({
      data: {
        adminId: req.user.id,
        actionType: 'CREATE_USER',
        targetUserId: user.id,
        details: `Создан обычный пользователь: ${email}`
      }
    });

    res.json({ success: true, user: { id: user.id, name: user.name, email: user.email, role: user.role } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});


app.get('/admin/stats', adminMiddleware, async (req, res) => {
  try {
    const [users, news, courses, zones, products, orders, completedOrders] = await Promise.all([
      prisma.user.count(),
      prisma.news.count(),
      prisma.course.count(),
      prisma.zone.count(),
      prisma.product.count(),
      prisma.order.count(),
      prisma.order.findMany({ where: { status: 'COMPLETED' }, select: { totalAmount: true } }),
    ]);
    const revenue = completedOrders.reduce((sum, order) => sum + order.totalAmount, 0);
    res.json({ users, news, courses, zones, products, orders, revenue });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// SHOP (PRODUCTS & ORDERS)
// ─────────────────────────────────────────────
app.get('/products', async (req, res) => {
  try {
    const products = await prisma.product.findMany({
      where: { isDeleted: false },
      orderBy: { createdAt: 'desc' }
    });
    res.json(products);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/products/:id', async (req, res) => {
  try {
    const product = await prisma.product.findUnique({
      where: { id: parseInt(req.params.id) },
      include: {
        reviews: {
          include: { user: { select: { name: true, avatar: true } } },
          orderBy: { createdAt: 'desc' }
        }
      }
    });
    if (!product || product.isDeleted) return res.status(404).json({ error: 'Товар не найден' });
    res.json(product);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/products/:id/reviews', authMiddleware, async (req, res) => {
  try {
    const { rating, comment } = req.body;
    if (!rating || !comment) return res.status(400).json({ error: 'Заполните рейтинг и комментарий' });
    const review = await prisma.review.create({
      data: {
        productId: parseInt(req.params.id),
        userId: req.user.id,
        rating: parseInt(rating),
        comment
      },
      include: { user: { select: { name: true, avatar: true } } }
    });
    res.json(review);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/products', adminMiddleware, async (req, res) => {
  try {
    const { title, description, price, imageUrl, images, stock } = req.body;
    const priceVal = parseFloat(price);
    const stockVal = parseInt(stock) || 0;
    if (isNaN(priceVal) || priceVal < 0) {
      return res.status(400).json({ error: 'Цена товара не может быть отрицательной или пустой' });
    }
    if (isNaN(stockVal) || stockVal < 0) {
      return res.status(400).json({ error: 'Остаток товара на складе не может быть отрицательным' });
    }
    const product = await prisma.product.create({
      data: { title, description, price: priceVal, imageUrl, images: images||[], stock: stockVal }
    });
    res.json(product);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/admin/products/:id', adminMiddleware, async (req, res) => {
  try {
    const { title, description, price, imageUrl, images, stock } = req.body;
    const priceVal = parseFloat(price);
    const stockVal = parseInt(stock) || 0;
    if (isNaN(priceVal) || priceVal < 0) {
      return res.status(400).json({ error: 'Цена товара не может быть отрицательной' });
    }
    if (isNaN(stockVal) || stockVal < 0) {
      return res.status(400).json({ error: 'Остаток товара на складе не может быть отрицательным' });
    }
    const product = await prisma.product.update({
      where: { id: parseInt(req.params.id) },
      data: { title, description, price: priceVal, imageUrl, images: images||[], stock: stockVal }
    });
    res.json(product);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/admin/products/:id', adminMiddleware, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    await prisma.product.update({
      where: { id },
      data: { isDeleted: true }
    });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/orders', authMiddleware, async (req, res) => {
  try {
    const { items } = req.body; // [{ productId, quantity }]
    if (!items || !items.length) return res.status(400).json({ error: 'Корзина пуста' });

    const order = await prisma.$transaction(async (tx) => {
      let totalAmount = 0;
      const orderItemsData = [];

      for (const item of items) {
        const product = await tx.product.findUnique({ where: { id: parseInt(item.productId) } });
        if (!product || product.isDeleted) throw new Error(`Товар ID ${item.productId} не найден`);
        if (product.stock < item.quantity) {
          throw new Error(`Недостаточно товара "${product.title}" на складе`);
        }
        
        totalAmount += product.price * item.quantity;
        orderItemsData.push({
          productId: product.id,
          quantity: parseInt(item.quantity),
          price: product.price
        });
      }

      return await tx.order.create({
        data: {
          userId: req.user.id,
          totalAmount,
          status: 'PENDING',
          items: { create: orderItemsData }
        },
        include: { items: true }
      });
    });

    res.json(order);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/orders/:id/pay', authMiddleware, async (req, res) => {
  try {
    const orderId = parseInt(req.params.id);
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: { items: true }
    });
    if (!order) return res.status(404).json({ error: 'Заказ не найден' });
    if (order.userId !== req.user.id) return res.status(403).json({ error: 'Доступ запрещен' });
    if (order.status !== 'PENDING') return res.status(400).json({ error: 'Заказ уже оплачен или отменен' });

    // Decrement stock in transaction and complete order
    await prisma.$transaction(async (tx) => {
      for (const item of order.items) {
        const product = await tx.product.findUnique({ where: { id: item.productId } });
        if (!product) throw new Error(`Товар ID ${item.productId} не найден`);
        if (product.stock < item.quantity) {
          throw new Error(`Недостаточно товара "${product.title}" на складе`);
        }
        await tx.product.update({
          where: { id: item.productId },
          data: { stock: { decrement: item.quantity } }
        });
      }

      await tx.order.update({
        where: { id: orderId },
        data: { status: 'COMPLETED' }
      });
    });

    // Award +250 EXP on shopping purchase
    const result = await grantUserExpAndCheckAchievements(req.user.id, 250, 'shop_purchase', prisma);

    res.json({
      message: 'Оплата успешно произведена',
      status: 'COMPLETED',
      expGained: 250,
      currentExp: result?.exp,
      currentLevel: result?.level,
      newlyUnlocked: result?.newlyUnlocked
    });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.get('/orders/me', authMiddleware, async (req, res) => {
  try {
    const orders = await prisma.order.findMany({
      where: { userId: req.user.id },
      include: { items: { include: { product: true } } },
      orderBy: { createdAt: 'desc' }
    });
    res.json(orders);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/admin/orders', adminMiddleware, async (req, res) => {
  try {
    const orders = await prisma.order.findMany({
      include: { user: { select: { name: true, email: true } }, items: { include: { product: true } } },
      orderBy: { createdAt: 'desc' }
    });
    res.json(orders);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/admin/orders/:id/status', adminMiddleware, async (req, res) => {
  try {
    const { status } = req.body;
    const orderId = parseInt(req.params.id);
    
    const order = await prisma.order.findUnique({ where: { id: orderId }, include: { items: true } });
    if (!order) return res.status(404).json({ error: 'Заказ не найден' });
    
    const prevStatus = order.status;
    
    // If status changes to COMPLETED (and it wasn't COMPLETED before) -> decrement stock
    if (status === 'COMPLETED' && prevStatus !== 'COMPLETED') {
      try {
        await prisma.$transaction(async (tx) => {
          for (const item of order.items) {
            const product = await tx.product.findUnique({ where: { id: item.productId } });
            if (!product) throw new Error(`Товар ID ${item.productId} не найден`);
            if (product.stock < item.quantity) {
              throw new Error(`Недостаточно товара "${product.title}" на складе для завершения заказа`);
            }
            await tx.product.update({
              where: { id: item.productId },
              data: { stock: { decrement: item.quantity } }
            });
          }
        });
      } catch (err) {
        return res.status(400).json({ error: err.message });
      }
    }
    
    // If status changes from COMPLETED to something else (e.g. CANCELLED or PENDING) -> increment stock back
    if (prevStatus === 'COMPLETED' && status !== 'COMPLETED') {
      for (const item of order.items) {
        await prisma.product.update({
          where: { id: item.productId },
          data: { stock: { increment: item.quantity } }
        });
      }
    }

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: { status }
    });
    res.json(updatedOrder);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// SUPPORT SYSTEM
// ─────────────────────────────────────────────
app.post('/support', async (req, res) => {
  try {
    const { message } = req.body;
    if (!message) return res.status(400).json({ error: 'Сообщение не может быть пустым' });

    let userId = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        const decoded = jwt.verify(token, JWT_SECRET);
        userId = decoded.id;
      } catch (e) {}
    }

    const request = await prisma.supportRequest.create({
      data: {
        message,
        userId
      }
    });

    res.json({ success: true, request });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/admin/support', adminMiddleware, async (req, res) => {
  try {
    const requests = await prisma.supportRequest.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }
      }
    });
    res.json(requests);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/admin/support/:id/status', adminMiddleware, async (req, res) => {
  try {
    const { status } = req.body;
    const updated = await prisma.supportRequest.update({
      where: { id: parseInt(req.params.id) },
      data: { status }
    });
    res.json(updated);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────
// ABOUT US SECTIONS
// ─────────────────────────────────────────────
app.get('/about', async (req, res) => {
  try {
    const sections = await prisma.aboutSection.findMany({
      orderBy: { order: 'asc' }
    });
    res.json(sections);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/admin/about/:id', adminMiddleware, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const { titleRu, titleUz, titleEn, descRu, descUz, descEn, imageUrl, mapIframe } = req.body;
    const updated = await prisma.aboutSection.update({
      where: { id },
      data: { titleRu, titleUz, titleEn, descRu, descUz, descEn, imageUrl, mapIframe }
    });
    res.json(updated);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/verify/:uuid', async (req, res) => {
  res.redirect(`/verify-certificate/${req.params.uuid}`);
});

app.get('/verify-certificate/:uuid', async (req, res) => {
  try {
    const uuid = req.params.uuid;
    const completion = await prisma.courseCompletion.findUnique({
      where: { certificateUuid: uuid }
    });

    if (!completion || !completion.certificateIssuedAt) {
      return res.status(404).send(`
        <!DOCTYPE html>
        <html lang="ru">
        <head>
          <meta charset="UTF-8">
          <title>Проверка сертификата - Ошибка</title>
          <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&display=swap" rel="stylesheet">
          <style>
            body {
              background-color: #050814;
              color: #ffffff;
              font-family: 'Outfit', sans-serif;
              display: flex;
              align-items: center;
              justify-content: center;
              height: 100vh;
              margin: 0;
            }
            .card {
              background: rgba(10, 13, 26, 0.8);
              border: 1px solid #ff4a4a;
              border-radius: 16px;
              padding: 40px;
              text-align: center;
              max-width: 450px;
              box-shadow: 0 8px 32px rgba(255, 74, 74, 0.1);
              backdrop-filter: blur(10px);
            }
            h1 { color: #ff4a4a; margin-top: 0; font-size: 24px; }
            p { color: #94a3b8; font-size: 16px; line-height: 1.6; }
            .btn {
              display: inline-block;
              margin-top: 25px;
              background: #ff4a4a;
              color: white;
              text-decoration: none;
              padding: 12px 24px;
              border-radius: 8px;
              font-weight: 600;
              transition: transform 0.2s;
            }
            .btn:hover { transform: scale(1.05); }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>Сертификат не найден</h1>
            <p>Указанный уникальный идентификатор сертификата не зарегистрирован в системе UZDF Uzbekistan. Пожалуйста, проверьте правильность ссылки.</p>
            <a href="/" class="btn">На главную</a>
          </div>
        </body>
        </html>
      `);
    }

    if (completion.isRevoked) {
      const user = await prisma.user.findUnique({ where: { id: completion.userId } });
      const course = await prisma.course.findUnique({ where: { id: completion.courseId } });
      const formattedDate = new Date(completion.certificateIssuedAt).toLocaleDateString('ru-RU', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      });
      const formattedRevokeDate = completion.revokedAt ? new Date(completion.revokedAt).toLocaleDateString('ru-RU', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      }) : '';

      return res.send(`
        <!DOCTYPE html>
        <html lang="ru">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Сертификат Отозван - UZDF</title>
          <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&display=swap" rel="stylesheet">
          <style>
            body {
              background-color: #030712;
              color: #f3f4f6;
              font-family: 'Outfit', sans-serif;
              display: flex;
              align-items: center;
              justify-content: center;
              min-height: 100vh;
              margin: 0;
              background-image: 
                radial-gradient(at 0% 0%, hsla(350,100%,50%,0.08) 0, transparent 50%),
                radial-gradient(at 100% 100%, hsla(0,100%,50%,0.08) 0, transparent 50%);
            }
            .container {
              max-width: 600px;
              width: 90%;
              background: rgba(17, 24, 39, 0.7);
              border: 1px solid rgba(239, 68, 68, 0.3);
              border-radius: 24px;
              padding: 48px;
              text-align: center;
              box-shadow: 0 20px 50px rgba(0, 0, 0, 0.3);
              backdrop-filter: blur(16px);
            }
            .badge {
              background: linear-gradient(135deg, #EF4444 0%, #991B1B 100%);
              width: 80px;
              height: 80px;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              margin: 0 auto 24px auto;
              box-shadow: 0 0 20px rgba(239, 68, 68, 0.3);
            }
            .badge svg {
              width: 40px;
              height: 40px;
              fill: none;
              stroke: #ffffff;
              stroke-width: 2.5;
              stroke-linecap: round;
              stroke-linejoin: round;
            }
            h1 {
              font-size: 28px;
              font-weight: 700;
              margin: 0 0 8px 0;
              color: #EF4444;
            }
            .subtitle {
              color: #9ca3af;
              text-transform: uppercase;
              font-size: 12px;
              letter-spacing: 3px;
              font-weight: 700;
              margin-bottom: 32px;
            }
            .info-grid {
              display: grid;
              grid-template-columns: 1fr;
              gap: 20px;
              text-align: left;
              margin-bottom: 32px;
            }
            @media(min-width: 480px) {
              .info-grid {
                grid-template-columns: 1fr 1fr;
              }
            }
            .info-item {
              background: rgba(31, 41, 55, 0.4);
              padding: 16px 20px;
              border-radius: 12px;
              border: 1px solid rgba(255, 255, 255, 0.05);
            }
            .info-label {
              color: #9ca3af;
              font-size: 12px;
              text-transform: uppercase;
              letter-spacing: 1px;
              margin-bottom: 6px;
            }
            .info-value {
              color: #ffffff;
              font-size: 16px;
              font-weight: 600;
            }
            .revoke-box {
              background: rgba(239, 68, 68, 0.08);
              border: 1px solid rgba(239, 68, 68, 0.2);
              border-radius: 12px;
              padding: 20px;
              text-align: left;
              margin-bottom: 32px;
            }
            .uuid-box {
              font-family: monospace;
              background: #0b0f19;
              border: 1px dashed rgba(239, 68, 68, 0.2);
              color: #9ca3af;
              padding: 12px;
              border-radius: 8px;
              font-size: 13px;
              margin-top: 24px;
              word-break: break-all;
            }
            .btn-home {
              display: inline-block;
              margin-top: 32px;
              background: rgba(255, 255, 255, 0.05);
              border: 1px solid rgba(255, 255, 255, 0.1);
              color: #ffffff;
              text-decoration: none;
              padding: 12px 32px;
              border-radius: 12px;
              font-weight: 600;
              transition: all 0.3s ease;
            }
            .btn-home:hover {
              background: #EF4444;
              color: #ffffff;
              border-color: #EF4444;
              box-shadow: 0 0 15px rgba(239, 68, 68, 0.3);
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="badge">
              <svg viewBox="0 0 24 24">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </div>
            <h1>Сертификат Аннулирован</h1>
            <div class="subtitle">Данный сертификат был отозван администрацией</div>
            
            <div class="revoke-box">
              <div style="font-weight: bold; color: #EF4444; margin-bottom: 6px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px;">Информация об отзыве:</div>
              <div style="color: #f3f4f6; font-size: 15px; margin-bottom: 8px; line-height: 1.5;"><strong>Причина:</strong> ${completion.revokeReason || 'Нарушение правил использования платформы'}</div>
              <div style="color: #9ca3af; font-size: 13px;"><strong>Дата отзыва:</strong> ${formattedRevokeDate}</div>
              <div style="color: #9ca3af; font-size: 13px; margin-top: 4px;"><strong>Модератор:</strong> ${completion.revokedBy || 'Администрация'}</div>
            </div>

            <div class="info-grid">
              <div class="info-item" style="grid-column: span 2">
                <div class="info-label">Бывший владелец</div>
                <div class="info-value" style="font-size: 18px; color: #9ca3af; text-decoration: line-through;">${completion.studentName || user?.name}</div>
              </div>
              <div class="info-item" style="grid-column: span 2">
                <div class="info-label">Курс</div>
                <div class="info-value">${course?.title}</div>
              </div>
              <div class="info-item">
                <div class="info-label">Дата Выдачи</div>
                <div class="info-value">${formattedDate}</div>
              </div>
              <div class="info-item">
                <div class="info-label">Итоговый Балл</div>
                <div class="info-value">${completion.finalScore ? completion.finalScore.toFixed(1) : '95'}%</div>
              </div>
            </div>

            <div class="uuid-box">
              UUID: ${completion.certificateUuid}
            </div>

            <a href="/" class="btn-home">Вернуться на сайт</a>
          </div>
        </body>
        </html>
      `);
    }

    const user = await prisma.user.findUnique({ where: { id: completion.userId } });
    const course = await prisma.course.findUnique({ where: { id: completion.courseId } });

    const formattedDate = new Date(completion.certificateIssuedAt).toLocaleDateString('ru-RU', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });

    res.send(`
      <!DOCTYPE html>
      <html lang="ru">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Подлинность сертификата - UZDF</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&display=swap" rel="stylesheet">
        <style>
          body {
            background-color: #030712;
            color: #f3f4f6;
            font-family: 'Outfit', sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            background-image: 
              radial-gradient(at 0% 0%, hsla(244,100%,50%,0.1) 0, transparent 50%),
              radial-gradient(at 100% 100%, hsla(186,100%,50%,0.1) 0, transparent 50%);
          }
          .container {
            max-width: 600px;
            width: 90%;
            background: rgba(17, 24, 39, 0.7);
            border: 1px solid rgba(0, 229, 255, 0.2);
            border-radius: 24px;
            padding: 48px;
            text-align: center;
            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(16px);
          }
          .badge {
            background: linear-gradient(135deg, #00E5FF 0%, #0066FF 100%);
            width: 80px;
            height: 80px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px auto;
            box-shadow: 0 0 20px rgba(0, 229, 255, 0.4);
          }
          .badge svg {
            width: 40px;
            height: 40px;
            fill: none;
            stroke: #030712;
            stroke-width: 2.5;
            stroke-linecap: round;
            stroke-linejoin: round;
          }
          h1 {
            font-size: 28px;
            font-weight: 700;
            margin: 0 0 8px 0;
            letter-spacing: -0.5px;
            background: linear-gradient(to right, #ffffff, #9ca3af);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
          }
          .subtitle {
            color: #00E5FF;
            text-transform: uppercase;
            font-size: 12px;
            letter-spacing: 3px;
            font-weight: 700;
            margin-bottom: 32px;
          }
          .divider {
            height: 1px;
            background: linear-gradient(to right, transparent, rgba(0, 229, 255, 0.2), transparent);
            margin: 24px 0;
          }
          .info-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 20px;
            text-align: left;
            margin-bottom: 32px;
          }
          @media(min-width: 480px) {
            .info-grid {
              grid-template-columns: 1fr 1fr;
            }
          }
          .info-item {
            background: rgba(31, 41, 55, 0.4);
            padding: 16px 20px;
            border-radius: 12px;
            border: 1px solid rgba(255, 255, 255, 0.05);
          }
          .info-label {
            color: #9ca3af;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 6px;
          }
          .info-value {
            color: #ffffff;
            font-size: 16px;
            font-weight: 600;
          }
          .uuid-box {
            font-family: monospace;
            background: #0b0f19;
            border: 1px dashed rgba(0, 229, 255, 0.3);
            color: #9ca3af;
            padding: 12px;
            border-radius: 8px;
            font-size: 13px;
            margin-top: 24px;
            word-break: break-all;
          }
          .btn-home {
            display: inline-block;
            margin-top: 32px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.1);
            color: #ffffff;
            text-decoration: none;
            padding: 12px 32px;
            border-radius: 12px;
            font-weight: 600;
            transition: all 0.3s ease;
          }
          .btn-home:hover {
            background: #00E5FF;
            color: #030712;
            border-color: #00E5FF;
            box-shadow: 0 0 15px rgba(0, 229, 255, 0.3);
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="badge">
            <svg viewBox="0 0 24 24">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
              <polyline points="22 4 12 14.01 9 11.01"></polyline>
            </svg>
          </div>
          <h1>Сертификат Подтвержден</h1>
          <div class="subtitle">UZDF Uzbekistan</div>
          
          <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin-bottom: 32px;">
            Данный веб-интерфейс подтверждает, что указанный ниже выпускник успешно завершил специализированный учебный курс и сдал квалификационные экзамены.
          </p>

          <div class="info-grid">
            <div class="info-item" style="grid-column: span 2">
              <div class="info-label">Выпускник</div>
              <div class="info-value" style="font-size: 18px; color: #00E5FF;">${completion.studentName || user?.name}</div>
            </div>
            <div class="info-item" style="grid-column: span 2">
              <div class="info-label">Курс</div>
              <div class="info-value">${course?.title}</div>
            </div>
            <div class="info-item">
              <div class="info-label">Дата Выдачи</div>
              <div class="info-value">${formattedDate}</div>
            </div>
            <div class="info-item">
              <div class="info-label">Итоговый Балл</div>
              <div class="info-value" style="color: #10B981;">${completion.finalScore ? completion.finalScore.toFixed(1) : '95'}%</div>
            </div>
          </div>

          <div class="uuid-box">
            UUID: ${completion.certificateUuid}
          </div>

          <a href="/" class="btn-home">Вернуться на сайт</a>
        </div>
      </body>
      </html>
    `);
  } catch (e) {
    res.status(500).send('Ошибка сервера при валидации сертификата');
  }
});

// ─────────────────────────────────────────────
// TELEGRAM BOT HELPERS & ENDPOINTS
// ─────────────────────────────────────────────

function sendTelegramMessage(token, chatId, text) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      chat_id: chatId.toString(),
      text: text
    });

    const options = {
      hostname: 'api.telegram.org',
      port: 443,
      path: `/bot${token}/sendMessage`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Length': Buffer.byteLength(data, 'utf8')
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (parsed.ok) {
            resolve(parsed.result);
          } else {
            reject(new Error(parsed.description || 'Failed to send message'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', (e) => reject(e));
    req.write(data);
    req.end();
  });
}

let botProcess = null;

function startTelegramBot() {
  if (process.env.DISABLE_BOT_SPAWN === 'true') {
    console.log('🤖 [Bot Manager] Автозапуск Telegram Bot отключен (DISABLE_BOT_SPAWN=true).');
    return;
  }
  const botPath = path.join(__dirname, '../telegram_bot/main.py');
  if (!fs.existsSync(botPath)) {
    console.log(`⚠️ [Bot Manager] Telegram Bot не найден по пути: ${botPath}. Пропускаем автозапуск.`);
    return;
  }

  // If already running, kill the old process
  if (botProcess) {
    try {
      console.log('🤖 [Bot Manager] Завершение предыдущего процесса Telegram Bot...');
      botProcess.kill();
    } catch (e) {
      console.error('Ошибка при завершении старого бота:', e.message);
    }
    botProcess = null;
  }

  // Detect virtual environment executable if it exists
  let pythonCmd = 'python';
  const venvPythonWin = path.join(__dirname, '../telegram_bot/venv/Scripts/python.exe');
  const venvPythonUnix = path.join(__dirname, '../telegram_bot/venv/bin/python');

  if (fs.existsSync(venvPythonWin)) {
    pythonCmd = venvPythonWin;
  } else if (fs.existsSync(venvPythonUnix)) {
    pythonCmd = venvPythonUnix;
  }

  console.log(`🤖 [Bot Manager] Запуск Telegram Bot: ${pythonCmd} ${botPath}`);
  botProcess = spawn(pythonCmd, [botPath], {
    stdio: 'inherit',
    env: process.env
  });

  botProcess.on('error', (err) => {
    console.error('❌ [Bot Manager] Не удалось запустить Telegram Bot:', err.message);
  });

  process.on('exit', () => {
    if (botProcess) botProcess.kill();
  });
}

// ─────────────────────────────────────────────
// SYSTEM HEALTH & BOT RESTART
// ─────────────────────────────────────────────
app.get('/admin/system-status', adminMiddleware, async (req, res) => {
  try {
    // 1. OS CPU load estimation
    const cpus = os.cpus();
    let cpuUser = 0;
    let cpuSys = 0;
    let cpuIdle = 0;
    cpus.forEach(cpu => {
      cpuUser += cpu.times.user;
      cpuSys += cpu.times.sys;
      cpuIdle += cpu.times.idle;
    });
    const totalCpuTime = cpuUser + cpuSys + cpuIdle;
    const cpuLoadPercent = totalCpuTime > 0 ? Math.round(((cpuUser + cpuSys) / totalCpuTime) * 100) : 0;

    // 2. OS RAM usage
    const totalMem = os.totalmem();
    const freeMem = os.freemem();
    const usedMem = totalMem - freeMem;
    const ramUsagePercent = Math.round((usedMem / totalMem) * 100);

    // 3. Uptime
    const sysUptimeSeconds = os.uptime();
    const nodeUptimeSeconds = process.uptime();

    // 4. Node.js Memory usage
    const memoryUsage = process.memoryUsage(); // heapUsed, heapTotal, rss, external

    // 5. Database Latency Check
    const dbStart = Date.now();
    await prisma.$queryRaw`SELECT 1`;
    const dbLatencyMs = Date.now() - dbStart;

    // 6. Telegram Bot Process status
    const isBotRunning = botProcess !== null && botProcess.exitCode === null;

    res.json({
      cpuLoadPercent,
      ramUsagePercent,
      totalMemBytes: totalMem,
      usedMemBytes: usedMem,
      freeMemBytes: freeMem,
      sysUptimeSeconds,
      nodeUptimeSeconds,
      nodeMemory: {
        rssBytes: memoryUsage.rss,
        heapTotalBytes: memoryUsage.heapTotal,
        heapUsedBytes: memoryUsage.heapUsed,
        externalBytes: memoryUsage.external
      },
      dbLatencyMs,
      isBotRunning,
      platform: os.platform(),
      release: os.release()
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/bot/restart', adminMiddleware, async (req, res) => {
  try {
    console.log('🤖 [Bot Manager] Запрос на перезапуск бота от администратора:', req.user.email);
    startTelegramBot();
    res.json({ success: true, message: 'Процесс Telegram бота перезапущен' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 1. Get Bot Stats
app.get('/admin/bot/stats', adminMiddleware, async (req, res) => {
  try {
    const totalUsers = await prisma.telegramUser.count();
    const totalMessages = await prisma.telegramMessage.count();
    const unansweredChats = await prisma.telegramUser.count({
      where: {
        messages: {
          some: { isFromUser: true }
        }
      }
    });
    
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    // Daily activity chart — only USER messages (exclude admin replies)
    const userMessages = await prisma.telegramMessage.findMany({
      where: { 
        createdAt: { gte: thirtyDaysAgo },
        isFromUser: true
      },
      select: { createdAt: true }
    });

    const countsByDate = {};
    userMessages.forEach(m => {
      const dateStr = m.createdAt.toISOString().slice(0, 10);
      countsByDate[dateStr] = (countsByDate[dateStr] || 0) + 1;
    });

    // Fill in missing days with 0
    const chartData = [];
    for (let d = new Date(thirtyDaysAgo); d <= new Date(); d.setDate(d.getDate() + 1)) {
      const dateStr = d.toISOString().slice(0, 10);
      chartData.push({ date: dateStr, count: countsByDate[dateStr] || 0 });
    }

    // Hourly activity chart — when the bot is most active (user messages only)
    const allUserMessages = await prisma.telegramMessage.findMany({
      where: { isFromUser: true },
      select: { createdAt: true }
    });
    
    const hourlyActivity = new Array(24).fill(0);
    allUserMessages.forEach(m => {
      const hour = m.createdAt.getHours();
      hourlyActivity[hour]++;
    });

    res.json({
      totalUsers,
      totalMessages,
      unansweredChats,
      chartData,
      hourlyActivity
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 2. Get Bot Users
app.get('/admin/bot/users', adminMiddleware, async (req, res) => {
  try {
    const users = await prisma.telegramUser.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        _count: { select: { messages: true } }
      }
    });
    const serializedUsers = users.map(u => ({
      id: u.id.toString(),
      username: u.username,
      firstName: u.firstName,
      lastName: u.lastName,
      createdAt: u.createdAt,
      messageCount: u._count.messages
    }));
    res.json(serializedUsers);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 3. Get Active Chats (Support Ticket List)
app.get('/admin/bot/chats', adminMiddleware, async (req, res) => {
  try {
    const users = await prisma.telegramUser.findMany({
      include: {
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1
        }
      }
    });
    
    const chats = users.map(u => {
      const lastMsg = u.messages[0];
      return {
        id: u.id.toString(),
        username: u.username,
        firstName: u.firstName,
        lastName: u.lastName,
        lastMessageText: lastMsg ? lastMsg.text : '',
        lastMessageTime: lastMsg ? lastMsg.createdAt : u.createdAt,
        isLastFromUser: lastMsg ? lastMsg.isFromUser : false
      };
    });

    chats.sort((a, b) => {
      if (a.isLastFromUser !== b.isLastFromUser) {
        return a.isLastFromUser ? -1 : 1;
      }
      return new Date(b.lastMessageTime) - new Date(a.lastMessageTime);
    });

    res.json(chats);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 4. Get Chat History
app.get('/admin/bot/chats/:id/history', adminMiddleware, async (req, res) => {
  try {
    const tgUserId = BigInt(req.params.id);
    const messages = await prisma.telegramMessage.findMany({
      where: { telegramUserId: tgUserId },
      orderBy: { createdAt: 'asc' },
      include: {
        admin: {
          select: { name: true }
        }
      }
    });
    
    const serializedMessages = messages.map(m => ({
      id: m.id,
      telegramUserId: m.telegramUserId.toString(),
      text: m.text,
      isFromUser: m.isFromUser,
      adminName: m.admin ? m.admin.name : null,
      createdAt: m.createdAt
    }));

    res.json(serializedMessages);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 5. Send Admin Reply
app.post('/admin/bot/chats/:id/reply', adminMiddleware, async (req, res) => {
  try {
    const tgUserId = BigInt(req.params.id);
    const { text } = req.body;
    if (!text) return res.status(400).json({ error: 'Текст ответа не может быть пустым' });

    const botToken = process.env.TELEGRAM_BOT_TOKEN;
    if (!botToken) {
      return res.status(500).json({ error: 'Токен Telegram бота не настроен на сервере' });
    }

    try {
      await sendTelegramMessage(botToken, tgUserId, text);
    } catch (telegramErr) {
      return res.status(400).json({ error: `Ошибка отправки в Telegram: ${telegramErr.message}` });
    }

    const savedMessage = await prisma.telegramMessage.create({
      data: {
        telegramUserId: tgUserId,
        text: text,
        isFromUser: false,
        adminId: req.user.id
      },
      include: {
        admin: {
          select: { name: true }
        }
      }
    });

    res.json({
      success: true,
      message: {
        id: savedMessage.id,
        telegramUserId: savedMessage.telegramUserId.toString(),
        text: savedMessage.text,
        isFromUser: false,
        adminName: savedMessage.admin ? savedMessage.admin.name : null,
        createdAt: savedMessage.createdAt
      }
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 5b. Telegram Bot Broadcast to All Users
app.post('/admin/bot/broadcast', adminMiddleware, async (req, res) => {
  try {
    const { text } = req.body;
    if (!text) return res.status(400).json({ error: 'Текст рассылки не может быть пустым' });

    const botToken = process.env.TELEGRAM_BOT_TOKEN;
    if (!botToken) {
      return res.status(500).json({ error: 'Токен Telegram бота не настроен на сервере' });
    }

    const tgUsers = await prisma.telegramUser.findMany();
    if (!tgUsers.length) {
      return res.json({ success: true, count: 0, message: 'Нет пользователей для рассылки' });
    }

    let successCount = 0;
    for (const tgUser of tgUsers) {
      try {
        await sendTelegramMessage(botToken, tgUser.id, text);
        await prisma.telegramMessage.create({
          data: {
            telegramUserId: tgUser.id,
            text: text,
            isFromUser: false,
            adminId: req.user.id
          }
        });
        successCount++;
      } catch (err) {
        console.error(`Failed to send broadcast message to ${tgUser.id}:`, err.message);
      }
    }

    res.json({
      success: true,
      count: successCount,
      total: tgUsers.length
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Export Users as CSV
app.get('/admin/users/export', adminMiddleware, async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      orderBy: { createdAt: 'desc' }
    });
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=users_report.csv');
    let csv = '\uFEFFID,Name,Email,Phone,DOB,Country,Role,Level,EXP,Lives,Blocked,RegisteredAt\n';
    users.forEach(u => {
      csv += `"${u.id}","${(u.name || '').replace(/"/g, '""')}","${(u.email || '').replace(/"/g, '""')}","${(u.phone || '').replace(/"/g, '""')}","${(u.dob || '').replace(/"/g, '""')}","${(u.country || '').replace(/"/g, '""')}","${u.role}","${u.level}","${u.exp}","${u.courseLives}","${u.isBlocked ? 'Yes' : 'No'}","${new Date(u.createdAt).toLocaleString()}"\n`;
    });
    res.send(csv);
  } catch (e) {
    res.status(500).send(e.message);
  }
});

// Export Orders as CSV
app.get('/admin/orders/export', adminMiddleware, async (req, res) => {
  try {
    const orders = await prisma.order.findMany({
      include: {
        user: { select: { name: true, email: true } }
      },
      orderBy: { createdAt: 'desc' }
    });
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=orders_report.csv');
    let csv = '\uFEFFID,Customer,Email,TotalAmount,Status,DeliveryCity,DeliveryAddress,DeliveryContact,CreatedAt\n';
    orders.forEach(o => {
      csv += `"${o.id}","${(o.user?.name || '').replace(/"/g, '""')}","${(o.user?.email || '').replace(/"/g, '""')}","${o.totalAmount}","${o.status}","${(o.deliveryCity || '').replace(/"/g, '""')}","${(o.deliveryAddress || '').replace(/"/g, '""')}","${(o.deliveryContact || '').replace(/"/g, '""')}","${new Date(o.createdAt).toLocaleString()}"\n`;
    });
    res.send(csv);
  } catch (e) {
    res.status(500).send(e.message);
  }
});

// 6. Download All Logs as CSV (must be before /admin/bot/logs to avoid conflict)
app.get('/admin/bot/logs/download', adminMiddleware, async (req, res) => {
  try {
    const logs = await prisma.telegramBotLog.findMany({
      orderBy: { createdAt: 'desc' }
    });
    
    const csvHeader = 'ID,Время,Уровень,Сообщение\n';
    const csvRows = logs.map(l => {
      const escapedMsg = `"${l.message.replace(/"/g, '""')}"`;
      return `${l.id},${l.createdAt.toISOString()},${l.level},${escapedMsg}`;
    }).join('\n');
    
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename=bot_logs_${new Date().toISOString().slice(0,10)}.csv`);
    res.send('\uFEFF' + csvHeader + csvRows); // BOM for Excel UTF-8
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 7. Get Bot Logs (with optional user filter)
app.get('/admin/bot/logs', adminMiddleware, async (req, res) => {
  try {
    const { userId } = req.query;
    const where = {};
    if (userId) {
      where.message = { contains: userId };
    }
    const logs = await prisma.telegramBotLog.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 200
    });
    res.json(logs);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 8. Get user-specific chat logs for export
app.get('/admin/bot/chats/:id/export', adminMiddleware, async (req, res) => {
  try {
    const tgUserId = BigInt(req.params.id);
    const user = await prisma.telegramUser.findUnique({ where: { id: tgUserId } });
    const messages = await prisma.telegramMessage.findMany({
      where: { telegramUserId: tgUserId },
      orderBy: { createdAt: 'asc' },
      include: { admin: { select: { name: true } } }
    });
    
    const userName = [user?.firstName, user?.lastName].filter(Boolean).join(' ') || user?.username || tgUserId.toString();
    const csvHeader = 'ID,Время,Отправитель,Текст\n';
    const csvRows = messages.map(m => {
      const sender = m.isFromUser ? userName : (m.admin?.name || 'Админ');
      const escapedText = `"${m.text.replace(/"/g, '""')}"`;
      return `${m.id},${m.createdAt.toISOString()},${sender},${escapedText}`;
    }).join('\n');
    
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename=chat_${tgUserId}_${new Date().toISOString().slice(0,10)}.csv`);
    res.send('\uFEFF' + csvHeader + csvRows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// SPA fallback — admin
app.get('/admin/*', (req, res) => {
  res.sendFile(path.join(__dirname, '../web/admin/index.html'));
});

// SPA fallback — public
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../web/index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ UZDF Backend запущен на порту ${PORT}`);
  console.log(`🌐 Публичный сайт: http://localhost:${PORT}`);
  console.log(`🔐 Admin панель:  http://localhost:${PORT}/admin`);
  startTelegramBot();
});