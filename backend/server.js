const express = require('express');
const cors = require('cors');
const path = require('path');
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

const app = express();
const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'skycheck-super-secret-2024';

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
    from: process.env.SMTP_FROM || '"SkyCheck" <noreply@skycheck.uz>',
    to: email,
    subject: 'Код подтверждения регистрации SkyCheck',
    html: `
      <div style="font-family: Arial, sans-serif; background-color: #050814; color: #ffffff; padding: 30px; border-radius: 10px; max-width: 500px; margin: 0 auto; border: 1px solid #0066FF;">
        <div style="text-align: center; margin-bottom: 20px;">
          <h1 style="color: #0066FF; margin: 0; font-size: 28px; letter-spacing: 2px;">SKYCHECK</h1>
          <p style="color: #00E5FF; margin: 5px 0 0 0; font-size: 10px; letter-spacing: 4px; font-weight: bold;">УЗБЕКИСТАН</p>
        </div>
        <hr style="border-color: #0066FF; opacity: 0.3; margin-bottom: 25px;">
        <p style="font-size: 16px; line-height: 1.5;">Здравствуйте!</p>
        <p style="font-size: 16px; line-height: 1.5;">Спасибо за регистрацию в SkyCheck Uzbekistan. Для подтверждения вашей почты используйте следующий код подтверждения:</p>
        <div style="background-color: #0A0D1A; border: 1px solid #00E5FF; border-radius: 8px; padding: 15px; text-align: center; margin: 30px 0; letter-spacing: 6px;">
          <span style="font-size: 32px; font-weight: bold; color: #00E5FF;">${code}</span>
        </div>
        <p style="font-size: 14px; color: #94A3B8; line-height: 1.5;">Код действителен в течение 10 минут. Если вы не запрашивали этот код, просто проигнорируйте это письмо.</p>
        <hr style="border-color: #0066FF; opacity: 0.3; margin-top: 25px; margin-bottom: 15px;">
        <p style="font-size: 12px; color: #64748B; text-align: center; margin: 0;">&copy; 2026 SkyCheck Uzbekistan. Все права защищены.</p>
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
const authMiddleware = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Токен не найден' });
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await prisma.user.findUnique({ where: { id: decoded.id } });
    if (!user) return res.status(401).json({ error: 'Пользователь не найден' });
    if (user.isBlocked) {
      return res.status(403).json({ error: 'Ваш доступ временно приостановлен. Обратитесь к администратору' });
    }
    req.user = user;
    next();
  } catch (e) {
    res.status(401).json({ error: 'Недействительный токен или сессия устарела' });
  }
};

const adminMiddleware = (req, res, next) => {
  authMiddleware(req, res, () => {
    if (req.user.role !== 'admin' && req.user.role !== 'superadmin') return res.status(403).json({ error: 'Только для администраторов' });
    next();
  });
};

const superAdminMiddleware = (req, res, next) => {
  authMiddleware(req, res, () => {
    if (req.user.role !== 'superadmin') return res.status(403).json({ error: 'Только для суперадминистраторов' });
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

  // Recalculate level in case achievement rewards pushed user up
  calculatedLevel = 1;
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
    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        exp: user.exp,
        level: user.level,
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
    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        exp: user.exp,
        level: user.level,
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
    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        exp: user.exp,
        level: user.level,
        achievements: user.achievements.map(a => ({ achievementId: a.achievementId, unlockedAt: a.unlockedAt }))
      }
    });
  } catch (e) {
    res.status(500).json({ error: 'Ошибка сервера при авторизации через Google' });
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
        achievements: { select: { achievementId: true, unlockedAt: true } }
      },
    });
    res.json(user);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/auth/me', authMiddleware, async (req, res) => {
  try {
    const { name, email, phone, language, avatar } = req.body;
    if (email) {
      const existing = await prisma.user.findUnique({ where: { email } });
      if (existing && existing.id !== req.user.id) {
        return res.status(400).json({ error: 'Этот Email уже зарегистрирован другим пользователем' });
      }
    }
    const user = await prisma.user.update({
      where: { id: req.user.id },
      data: { name, email, phone, language, avatar },
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
        achievements: { select: { achievementId: true, unlockedAt: true } }
      },
    });
    res.json(user);
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
    // Store delivery info in status field as JSON (minimal schema change)
    const deliveryInfo = JSON.stringify({ deliveryAddress, deliveryCity, deliveryContact });
    const updated = await prisma.order.update({
      where: { id: orderId },
      data: { status: order.status === 'PENDING' ? `PENDING|${deliveryInfo}` : order.status },
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
    let completedCourseIds = [];
    if (userId) {
      const completions = await prisma.courseCompletion.findMany({
        where: { userId }
      });
      completedCourseIds = completions.map(c => c.courseId);
    }

    const coursesWithLock = courses.map((course, index) => {
      let isLocked = false;
      if (index > 0) {
        const prevCourse = courses[index - 1];
        isLocked = !completedCourseIds.includes(prevCourse.id);
      }
      return {
        ...course,
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

    if (passed && step.isFinalExam) {
      // Attempt to issue certificate if all conditions are met
      try {
        const certResult = await evaluateAndIssueCertificate(req.user.id, step.courseId);
        if (certResult.issued) {
          certificateIssued = true;
          certificateUuid = certResult.uuid;
        }
      } catch (err) {
        errorIssuingCertificate = err.message;
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
      errorIssuingCertificate
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

    let blocked = false;
    let blockedUntil = null;

    if (courseViolationsCount >= 5) {
      blocked = true;
      blockedUntil = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours block
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
    res.json(course);
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
    const { title, description, iconType, color } = req.body;
    const course = await prisma.course.create({ data: { title, description, iconType, color } });
    res.json(course);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/courses/:id', adminMiddleware, async (req, res) => {
  try {
    const { title, description, iconType, color } = req.body;
    const course = await prisma.course.update({
      where: { id: parseInt(req.params.id) },
      data: { title, description, iconType, color },
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
    const { type, title, content, questions, order } = req.body;
    const step = await prisma.courseStep.create({
      data: { courseId: parseInt(req.params.id), type, title, content, questions, order: parseInt(order) },
    });
    res.json(step);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/courses/:courseId/steps/:stepId', adminMiddleware, async (req, res) => {
  try {
    const { type, title, content, questions, order } = req.body;
    const step = await prisma.courseStep.update({
      where: { id: parseInt(req.params.stepId) },
      data: { type, title, content, questions, order: parseInt(order) },
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

app.get('/admin/users/:id/detail', adminMiddleware, async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, name: true, email: true, role: true, isBlocked: true, blockedAt: true, blockedBy: true, blockReason: true }
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

    res.json({
      user,
      courses: courseDetails,
      timeline: timeline.slice(0, 30), // limit to last 30 events
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
    const products = await prisma.product.findMany({ orderBy: { createdAt: 'desc' } });
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
    if (!product) return res.status(404).json({ error: 'Товар не найден' });
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
    const ordersCount = await prisma.orderItem.count({ where: { productId: id } });
    if (ordersCount > 0) {
      return res.status(400).json({ error: 'Невозможно удалить товар, так как он содержится в существующих заказах. Вы можете обнулить его остаток на складе.' });
    }
    await prisma.product.delete({ where: { id } });
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
        if (!product) throw new Error(`Товар ID ${item.productId} не найден`);
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
            <p>Указанный уникальный идентификатор сертификата не зарегистрирован в системе SkyCheck Uzbekistan. Пожалуйста, проверьте правильность ссылки.</p>
            <a href="/" class="btn">На главную</a>
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
        <title>Подлинность сертификата - SkyCheck</title>
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
          <div class="subtitle">SkyCheck Uzbekistan</div>
          
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
  console.log(`✅ SkyCheck Backend запущен на порту ${PORT}`);
  console.log(`🌐 Публичный сайт: http://localhost:${PORT}`);
  console.log(`🔐 Admin панель:  http://localhost:${PORT}/admin`);
});