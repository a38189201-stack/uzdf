const API = 'http://localhost:3000';
let token = localStorage.getItem('skycheck_token');
let adminUser = JSON.parse(localStorage.getItem('skycheck_user')||'{}');
let allNews=[], allUsers=[], allZones=[], allCourses=[], allProducts=[], allOrders=[];
let adminMap=null, currentPolygon=null, editingZoneId=null, activeCourseId=null;
let loadedPolygons={};
let isDrawingMode=false, drawingColor='RED', drawingPoints=[], drawingMarkers=[], drawingPolyline=null;
let mapsReady=true;


document.addEventListener('DOMContentLoaded', () => {
  if (token && (adminUser.role==='admin' || adminUser.role==='superadmin')) showAdminApp();
  else document.getElementById('admin-login').style.display='flex';
  document.getElementById('admin-email').addEventListener('keydown', e=>e.key==='Enter'&&adminLogin());
  document.getElementById('admin-pass').addEventListener('keydown', e=>e.key==='Enter'&&adminLogin());
});

// ── AUTH ──
async function adminLogin() {
  const email=document.getElementById('admin-email').value.trim();
  const pass=document.getElementById('admin-pass').value;
  if(!email||!pass) return showLoginErr('Заполните все поля');
  try {
    const r=await fetch(`${API}/auth/login`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password:pass})});
    const d=await r.json();
    if(!r.ok) return showLoginErr(d.error);
    if(d.user.role!=='admin' && d.user.role!=='superadmin') return showLoginErr('Нет доступа администратора');
    token=d.token; adminUser=d.user;
    localStorage.setItem('skycheck_token',token);
    localStorage.setItem('skycheck_user',JSON.stringify(d.user));
    showAdminApp();
  } catch { showLoginErr('Ошибка соединения'); }
}

function showLoginErr(msg) {
  document.getElementById('admin-login-alert').innerHTML=`<div class="alert alert-error">${msg}</div>`;
}

function showAdminApp() {
  document.getElementById('admin-login').style.display='none';
  document.getElementById('admin-app').style.display='flex';
  const n=adminUser.name||adminUser.email||'Admin';
  document.getElementById('admin-name').textContent=n;
  document.getElementById('admin-avatar').textContent=n[0].toUpperCase();
  if (adminUser.role === 'superadmin') {
    const btn = document.getElementById('btn-create-admin');
    if (btn) btn.style.display = 'inline-block';
  }
  loadStats(); loadNews(); loadUsers(); loadCourses(); loadZones();
}

function adminLogout() {
  localStorage.removeItem('skycheck_token');
  localStorage.removeItem('skycheck_user');
  location.reload();
}

// ── NAVIGATION ──
function showSection(name) {
  document.querySelectorAll('.admin-section').forEach(s=>s.classList.remove('active'));
  document.querySelectorAll('.sidebar-item').forEach(b=>b.classList.remove('active'));
  document.getElementById('section-'+name).classList.add('active');
  document.getElementById('nav-'+name).classList.add('active');
  const titles={dashboard:'Dashboard',news:'Новости',map:'Карта зон',users:'Пользователи',courses:'Курсы',shop:'Магазин',orders:'Заказы',support:'Поддержка'};
  document.getElementById('topbar-title').textContent=titles[name]||name;
  if(name==='map') {
    if(mapsReady&&!adminMap) {
      initAdminMap();
    } else if (adminMap) {
      setTimeout(() => {
        adminMap.invalidateSize();
      }, 100);
    }
  }
  if(name==='shop'&&!allProducts.length) loadProducts();
  if(name==='orders'&&!allOrders.length) loadOrders();
  if(name==='support') loadSupportRequests();
}

// ── API HELPERS ──
const authH = () => ({'Content-Type':'application/json','Authorization':'Bearer '+token});
const api = async(url,opt={})=>{
  const r=await fetch(API+url,{...opt,headers:authH()});
  const d=await r.json();
  if(!r.ok) {
    alert(d.error || 'Произошла ошибка при запросе');
    throw new Error(d.error || 'API Error');
  }
  return d;
};

// ── STATS ──
async function loadStats() {
  try {
    const d=await api('/admin/stats');
    document.getElementById('s-users').textContent=d.users||0;
    document.getElementById('s-news').textContent=d.news||0;
    document.getElementById('s-courses').textContent=d.courses||0;
    document.getElementById('s-zones').textContent=d.zones||0;
    document.getElementById('s-products').textContent=d.products||0;
    document.getElementById('s-orders').textContent=d.orders||0;
    document.getElementById('s-revenue').textContent=d.revenue?d.revenue.toFixed(2):'0.00';
  } catch{}
}

// ── UTILS ──
const esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const fmtDate=d=>d?new Date(d).toLocaleDateString('ru-RU',{day:'numeric',month:'short',year:'numeric'}):'';
const courseEmoji=t=>({beginner:'🚀',intermediate:'🎯',advanced:'⚡',pro:'🏆'}[t]||'📚');

// ════════════════════════════════════
// NEWS
// ════════════════════════════════════
async function loadNews() {
  try { allNews=await api('/news'); renderNewsTable(); } catch{}
}

function renderNewsTable() {
  const q=(document.getElementById('news-search').value||'').toLowerCase();
  const items=allNews.filter(n=>n.title.toLowerCase().includes(q)||n.author?.toLowerCase().includes(q));
  if(!items.length){
    document.getElementById('news-table-body').innerHTML='<div class="empty-state"><div class="empty-state-icon">📰</div><p>Нет новостей</p></div>';
    return;
  }
  document.getElementById('news-table-body').innerHTML=`
    <table><thead><tr><th>Заголовок</th><th>Автор</th><th>Дата</th><th>Действия</th></tr></thead>
    <tbody>${items.map(n=>`
      <tr>
        <td><strong>${esc(n.title)}</strong></td>
        <td style="color:var(--text-muted)">${esc(n.author||'—')}</td>
        <td style="color:var(--text-muted)">${fmtDate(n.publishedAt)}</td>
        <td style="display:flex;gap:6px">
          <button class="btn btn-secondary btn-sm" onclick="openNewsModal(${n.id})">✏ Изм.</button>
          <button class="btn btn-danger btn-sm" onclick="deleteNews(${n.id})">🗑</button>
        </td>
      </tr>`).join('')}
    </tbody></table>`;
}

function filterNews(){ renderNewsTable(); }

function openNewsModal(id=null) {
  const n=id?allNews.find(x=>x.id===id):null;
  document.getElementById('news-modal-title').textContent=n?'Редактировать новость':'Добавить новость';
  document.getElementById('nm-id').value=n?.id||'';
  document.getElementById('nm-title').value=n?.title||'';
  document.getElementById('nm-author').value=n?.author||'';
  document.getElementById('nm-image').value=n?.imageUrl||'';
  document.getElementById('nm-content').value=n?.content||'';
  document.getElementById('news-modal-alert').innerHTML='';
  document.getElementById('news-modal').style.display='flex';
}
function closeNewsModal(){ document.getElementById('news-modal').style.display='none'; }

async function saveNews() {
  const id=document.getElementById('nm-id').value;
  const body={title:document.getElementById('nm-title').value.trim(),author:document.getElementById('nm-author').value.trim(),imageUrl:document.getElementById('nm-image').value.trim(),content:document.getElementById('nm-content').value.trim()};
  if(!body.title||!body.content) return showModalAlert('news-modal-alert','Заголовок и содержание обязательны');
  try {
    if(id) await api(`/news/${id}`,{method:'PUT',body:JSON.stringify(body)});
    else await api('/news',{method:'POST',body:JSON.stringify(body)});
    closeNewsModal(); loadNews(); loadStats();
  } catch(e){ showModalAlert('news-modal-alert','Ошибка: '+e.message); }
}

async function deleteNews(id) {
  if(!confirm('Удалить эту новость?')) return;
  await api(`/news/${id}`,{method:'DELETE'});
  loadNews(); loadStats();
}

// ════════════════════════════════════
// USERS
// ════════════════════════════════════
async function loadUsers() {
  await loadUsersDashboard();
}

async function loadUsersDashboard() {
  const searchInput = document.getElementById('users-search');
  const search = searchInput ? searchInput.value.trim() : '';
  
  const sortSelect = document.getElementById('users-sort');
  const sort = sortSelect ? sortSelect.value : 'lastActivity';
  
  const orderSelect = document.getElementById('users-sort-order');
  const order = orderSelect ? orderSelect.value : 'desc';

  const roleSelect = document.getElementById('users-role-filter');
  const role = roleSelect ? roleSelect.value : 'ALL';
  
  try {
    const url = `/admin/users-dashboard?search=${encodeURIComponent(search)}&sort=${sort}&order=${order}`;
    let data = await api(url);
    if (role !== 'ALL') {
      data = data.filter(u => u.role === role);
    }
    renderUsersDashboardTable(data);
  } catch (err) {
    console.error('Error loading users dashboard:', err);
  }
}

function renderUsersDashboardTable(items) {
  const tbody = document.getElementById('users-table-body-rows');
  if (!items || !items.length) {
    tbody.innerHTML = `<tr><td colspan="9" style="text-align:center; padding:20px; color:var(--text-muted)">Нет активных пользователей курсов</td></tr>`;
    return;
  }

  tbody.innerHTML = items.map(u => {
    let roleCell = '';
    if (adminUser.role === 'superadmin' && u.userId !== adminUser.id) {
      roleCell = `
        <select onchange="changeUserRole(${u.userId}, this.value)" style="background:#111;color:#fff;border:1px solid var(--border);border-radius:4px;padding:4px">
          <option value="user" ${u.role === 'user' ? 'selected' : ''}>user</option>
          <option value="moderator" ${u.role === 'moderator' ? 'selected' : ''}>moderator</option>
          <option value="admin" ${u.role === 'admin' ? 'selected' : ''}>admin</option>
          <option value="superadmin" ${u.role === 'superadmin' ? 'selected' : ''}>superadmin</option>
        </select>
      `;
    } else {
      roleCell = `<span style="font-weight:bold; color:var(--blue)">${esc(u.role || 'user')}</span>`;
    }

    return `
      <tr style="border-bottom: 1px solid rgba(255,255,255,0.05)">
        <td style="padding: 12px; font-weight:bold">${esc(u.name)}</td>
        <td style="padding: 12px; color:var(--text-muted)">${esc(u.email)}</td>
        <td style="padding: 12px;">${esc(u.courseTitle)}</td>
        <td style="padding: 12px; color:var(--text-muted)">${fmtDate(u.startDate)}</td>
        <td style="padding: 12px; color:var(--text-muted)">${fmtDate(u.lastActivity)}</td>
        <td style="padding: 12px;">
          <div style="display:flex; align-items:center; gap:8px">
            <div style="width:60px; background:rgba(255,255,255,0.1); height:6px; border-radius:3px; overflow:hidden">
              <div style="width:${u.progressPercent}%; background:var(--blue); height:100%"></div>
            </div>
            <span>${u.progressPercent}%</span>
          </div>
        </td>
        <td style="padding: 12px;">${roleCell}</td>
        <td style="padding: 12px;">
          <span class="badge badge-${u.isBlocked ? 'danger' : 'success'}" style="background:${u.isBlocked ? '#EF4444' : '#10B981'}; color:#fff; padding:4px 8px; border-radius:4px; font-size:0.75rem;">
            ${u.isBlocked ? 'Блокирован' : 'Активен'}
          </span>
        </td>
        <td style="padding: 12px; display:flex; gap:6px">
          <button class="btn btn-secondary btn-sm" onclick="viewUserDetails(${u.userId})">🔍 Прогресс</button>
          <button class="btn btn-danger btn-sm" onclick="toggleUserBlock(${u.userId}, ${u.isBlocked})">
            ${u.isBlocked ? 'Разблокировать' : 'Блокировать'}
          </button>
        </td>
      </tr>
    `;
  }).join('');
}

let currentDetailUserId = null;
let currentUdTab = 'courses';
let udData = null;

async function viewUserDetails(userId) {
  currentDetailUserId = userId;
  currentUdTab = 'courses';
  document.querySelectorAll('.ud-tab-btn').forEach(btn => btn.classList.remove('active'));
  document.getElementById('ud-tab-courses').classList.add('active');
  document.getElementById('ud-content-courses').style.display = 'block';
  document.getElementById('ud-content-timeline').style.display = 'none';

  try {
    udData = await api(`/admin/users/${userId}/detail`);
    document.getElementById('ud-name').textContent = udData.user.name;
    document.getElementById('ud-email').textContent = udData.user.email;
    
    // Block status and control button
    const blockCtrl = document.getElementById('ud-block-control');
    if (udData.user.isBlocked) {
      blockCtrl.innerHTML = `
        <span style="color:#EF4444; font-weight:bold; font-size:0.9rem">Заблокирован</span>
        <button class="btn btn-success btn-sm" onclick="toggleUserBlock(${userId}, true)">Разблокировать</button>
      `;
    } else {
      blockCtrl.innerHTML = `
        <span style="color:#10B981; font-weight:bold; font-size:0.9rem">Доступ активен</span>
        <button class="btn btn-danger btn-sm" onclick="toggleUserBlock(${userId}, false)">Заблокировать</button>
      `;
    }

    // Notifications and alerts flags
    const notifs = document.getElementById('ud-notifications');
    notifs.innerHTML = '';
    
    if (udData.notifications.screenshotBlocked) {
      notifs.innerHTML += `
        <div style="background:rgba(239,68,68,0.15); border:1px solid #EF4444; color:#EF4444; padding:12px; border-radius:8px; margin-bottom:12px; font-weight:bold">
          ⚠️ Пользователь заблокирован в одном из курсов на 24 часа из-за скриншотов (5+ нарушений)!
        </div>
      `;
    }
    if (udData.notifications.exhaustedAttempts) {
      notifs.innerHTML += `
        <div style="background:rgba(245,158,11,0.15); border:1px solid #F59E0B; color:#F59E0B; padding:12px; border-radius:8px; margin-bottom:12px; font-weight:bold">
          ⚠️ Пользователь исчерпал все 5 попыток прохождения одного из тестов!
        </div>
      `;
    }
    if (udData.notifications.inactiveAlert) {
      notifs.innerHTML += `
        <div style="background:rgba(59,130,246,0.15); border:1px solid #3B82F6; color:#3B82F6; padding:12px; border-radius:8px; margin-bottom:12px; font-weight:bold">
          ℹ️ Пользователь неактивен более 7 дней, при этом курс не завершен.
        </div>
      `;
    }

    renderUdCourses();
    renderUdTimeline();

    document.getElementById('user-detail-modal').style.display = 'flex';
  } catch (err) {
    console.error('Error fetching user details:', err);
  }
}

function closeUserDetailModal() {
  document.getElementById('user-detail-modal').style.display = 'none';
}

function switchUdTab(tab) {
  currentUdTab = tab;
  document.querySelectorAll('.ud-tab-btn').forEach(btn => btn.classList.remove('active'));
  
  if (tab === 'courses') {
    document.getElementById('ud-tab-courses').classList.add('active');
    document.getElementById('ud-content-courses').style.display = 'block';
    document.getElementById('ud-content-timeline').style.display = 'none';
  } else {
    document.getElementById('ud-tab-timeline').classList.add('active');
    document.getElementById('ud-content-courses').style.display = 'none';
    document.getElementById('ud-content-timeline').style.display = 'block';
  }
}

function renderUdCourses() {
  const container = document.getElementById('ud-courses-container');
  if (!udData || !udData.courses.length) {
    container.innerHTML = '<p style="color:var(--text-muted)">Нет данных о курсах</p>';
    return;
  }

  container.innerHTML = udData.courses.map(c => `
    <div style="margin-bottom:24px; background:rgba(255,255,255,0.02); border:1px solid rgba(255,255,255,0.05); border-radius:12px; padding:16px">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px">
        <h4 style="margin:0; font-size:1.1rem; color:#00E5FF">${esc(c.courseTitle)}</h4>
        <span style="font-weight:bold; font-size:0.9rem">${c.progressPercent}% пройдено</span>
      </div>
      <table style="width:100%; border-collapse:collapse; font-size:0.85rem">
        <thead>
          <tr style="border-bottom:1.5px solid rgba(255,255,255,0.05); text-align:left; color:var(--text-muted)">
            <th style="padding:8px 4px">Название урока</th>
            <th style="padding:8px 4px">Тип</th>
            <th style="padding:8px 4px">Статус</th>
            <th style="padding:8px 4px">Детали</th>
            <th style="padding:8px 4px">Сброс ограничений</th>
          </tr>
        </thead>
        <tbody>
          ${c.steps.map(s => {
            let details = '—';
            let resetBtn = '';
            
            if (s.type === 'text') {
              details = `Проведено: ${s.timeSpentSeconds}с`;
            } else if (s.type === 'video') {
              details = `Таймер завершен: ${s.isTimerCompleted ? 'Да' : 'Нет'}`;
              if (s.status === 'completed' || s.lessonStartedAt) {
                resetBtn = `<button class="btn btn-secondary btn-sm" onclick="resetUserTimer(${udData.user.id}, ${s.id})" style="padding:4px 8px; font-size:0.75rem">Сбросить таймер</button>`;
              }
            } else if (s.type === 'quiz') {
              const remainingCooldownMinutes = s.cooldownUntil ? Math.ceil((new Date(s.cooldownUntil).getTime() - Date.now()) / 1000 / 60) : 0;
              details = `Попыток: ${s.quizAttempts}/5 ${s.status === 'completed' ? `(Балл: ${s.timeSpentSeconds}%)` : ''}`;
              if (remainingCooldownMinutes > 0) {
                details += ` <br><span style="color:#F59E0B">Кулдаун: ${remainingCooldownMinutes} мин</span>`;
              }
              if (s.quizAttempts > 0) {
                resetBtn = `<button class="btn btn-secondary btn-sm" onclick="resetUserQuiz(${udData.user.id}, ${s.id})" style="padding:4px 8px; font-size:0.75rem">Сбросить попытки</button>`;
              }
            }

            const statusColors = {completed: '#10B981', in_progress: '#3B82F6', not_started: 'var(--text-muted)'};
            const statusLabels = {completed: 'Пройден', in_progress: 'В процессе', not_started: 'Не начат'};

            return `
              <tr style="border-bottom:1px solid rgba(255,255,255,0.03)">
                <td style="padding:8px 4px; font-weight:600">${esc(s.title)} ${s.isFinalExam ? '<span style="color:#EF4444; font-size:0.7rem; border:1px solid #EF4444; padding:2px 4px; border-radius:4px; margin-left:4px">Экзамен</span>' : ''}</td>
                <td style="padding:8px 4px; color:var(--text-muted); text-transform:uppercase">${s.type}</td>
                <td style="padding:8px 4px; color:${statusColors[s.status]}">${statusLabels[s.status]}</td>
                <td style="padding:8px 4px; color:var(--text-muted)">${details}</td>
                <td style="padding:8px 4px">${resetBtn}</td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    </div>
  `).join('');
}

function renderUdTimeline() {
  const container = document.getElementById('ud-timeline-container');
  if (!udData || !udData.timeline.length) {
    container.innerHTML = '<p style="color:var(--text-muted)">История активности пуста</p>';
    return;
  }

  container.innerHTML = `
    <div style="position:relative; padding-left:20px; border-left:2px solid rgba(255,255,255,0.05)">
      ${udData.timeline.map(t => {
        let color = '#3B82F6'; // blue
        if (t.type === 'violation') color = '#EF4444'; // red
        if (t.type === 'progress_update' && t.message.includes('completed')) color = '#10B981'; // green

        return `
          <div style="margin-bottom:16px; position:relative">
            <span style="position:absolute; left:-27px; top:4px; width:12px; height:12px; border-radius:50%; background:${color}; border:2px solid var(--bg-card)"></span>
            <div style="font-size:0.75rem; color:var(--text-muted)">${new Date(t.timestamp).toLocaleString('ru-RU')}</div>
            <div style="font-size:0.85rem; font-weight:600; color:white; margin-top:2px">${esc(t.message)}</div>
          </div>
        `;
      }).join('')}
    </div>
  `;
}

async function toggleUserBlock(userId, isBlocked) {
  let reason = '';
  if (!isBlocked) {
    reason = prompt('Укажите причину блокировки пользователя:');
    if (reason === null) return; // cancel
    if (!reason.trim()) reason = 'Нарушение правил платформы';
  } else {
    if (!confirm('Разблокировать доступ пользователю?')) return;
  }

  const endpoint = isBlocked ? `/admin/users/${userId}/unblock` : `/admin/users/${userId}/block`;
  const body = isBlocked ? {} : { reason };

  try {
    await api(endpoint, {
      method: 'POST',
      body: JSON.stringify(body)
    });
    
    // Refresh lists
    loadUsersDashboard();
    if (currentDetailUserId === userId) {
      viewUserDetails(userId);
    }
  } catch (err) {
    console.error('Error toggling block:', err);
  }
}

async function resetUserQuiz(userId, stepId) {
  if (!confirm('Вы уверены, что хотите сбросить попытки прохождения теста и кулдаун?')) return;
  try {
    await api(`/admin/users/${userId}/reset-quiz`, {
      method: 'POST',
      body: JSON.stringify({ stepId })
    });
    viewUserDetails(userId);
  } catch (err) {
    console.error('Error resetting quiz:', err);
  }
}

async function resetUserTimer(userId, stepId) {
  if (!confirm('Вы уверены, что хотите сбросить таймер урока? Пользователю придется смотреть его заново.')) return;
  try {
    await api(`/admin/users/${userId}/reset-timer`, {
      method: 'POST',
      body: JSON.stringify({ stepId })
    });
    viewUserDetails(userId);
  } catch (err) {
    console.error('Error resetting timer:', err);
  }
}

// ════════════════════════════════════
// MAP ZONES (Leaflet Custom Pen Tool Drawing)
// ════════════════════════════════════
function getBoundsArea(coords) {
  if (!Array.isArray(coords) || coords.length === 0) return 0;
  let minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
  coords.forEach(p => {
    const lat = Array.isArray(p) ? p[1] : p.lat;
    const lng = Array.isArray(p) ? p[0] : p.lng;
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lng < minLng) minLng = lng;
    if (lng > maxLng) maxLng = lng;
  });
  return (maxLat - minLat) * (maxLng - minLng);
}

async function loadZones() {
  try { 
    allZones=await api('/zones'); 
    allZones.sort((a, b) => {
      let coordsA = a.coordinates; if(typeof coordsA === 'string') try{coordsA=JSON.parse(coordsA);}catch{}
      let coordsB = b.coordinates; if(typeof coordsB === 'string') try{coordsB=JSON.parse(coordsB);}catch{}
      return getBoundsArea(coordsB) - getBoundsArea(coordsA);
    });
    Object.values(loadedPolygons).forEach(poly => {
      if (adminMap) adminMap.removeLayer(poly);
    });
    loadedPolygons={};
    if (adminMap) {
      allZones.forEach(z=>drawAdminZone(z));
    }
    renderZoneList(); 
  } catch{}
}

function selectDrawingColor(color, btn) {
  drawingColor = color;
  document.querySelectorAll('.color-btn').forEach(b => b.style.border = '2px solid transparent');
  btn.style.border = '2px solid #fff';
  const zfType = document.getElementById('zf-type');
  if (zfType) zfType.value = color;
}

function initAdminMap() {
  if (adminMap) return;
  adminMap = L.map('admin-map').setView([41.3111, 69.2406], 12);
  
  L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
    subdomains: 'abcd',
    maxZoom: 20
  }).addTo(adminMap);

  allZones.sort((a, b) => {
    let coordsA = a.coordinates; if(typeof coordsA === 'string') try{coordsA=JSON.parse(coordsA);}catch{}
    let coordsB = b.coordinates; if(typeof coordsB === 'string') try{coordsB=JSON.parse(coordsB);}catch{}
    return getBoundsArea(coordsB) - getBoundsArea(coordsA);
  });
  allZones.forEach(z => drawAdminZone(z));

  setTimeout(() => {
    adminMap.invalidateSize();
  }, 100);
}

function drawAdminZone(zone) {
  const colors = {RED:'#EF4444', YELLOW:'#F59E0B', GREEN:'#10B981'};
  const color = colors[zone.type] || '#6B7280';
  let coords = zone.coordinates;
  if(typeof coords === 'string') try{coords=JSON.parse(coords);}catch{}
  if(!Array.isArray(coords)) return;
  
  const paths = coords.map(p => Array.isArray(p) ? [p[1], p[0]] : [p.lat, p.lng]);
  const poly = L.polygon(paths, {
    color: color,
    fillColor: color,
    fillOpacity: 0.25,
    weight: 2
  }).addTo(adminMap);
  
  poly.on('click', (e) => {
    L.DomEvent.stopPropagation(e);
    selectZone(zone.id);
  });
  
  loadedPolygons[zone.id] = poly;
  return poly;
}

function startDrawing() {
  if (!adminMap) return;
  if (isDrawingMode) return;
  isDrawingMode = true;
  drawingPoints = [];
  drawingMarkers = [];
  
  if (drawingPolyline) { adminMap.removeLayer(drawingPolyline); drawingPolyline = null; }
  if (currentPolygon) { adminMap.removeLayer(currentPolygon); currentPolygon = null; }
  
  document.getElementById('draw-btn').textContent = '✏ Рисование...';
  
  const container = adminMap.getContainer();
  container.style.cursor = 'crosshair';
  container.classList.add('drawing-active');
  adminMap.dragging.disable();
  adminMap.doubleClickZoom.disable();
  
  adminMap.on('click', onMapClick);
  adminMap.on('mousemove', onMapMouseMove);
}

function stopDrawing() {
  if (!isDrawingMode) return;
  isDrawingMode = false;
  document.getElementById('draw-btn').textContent = '✏ Рисовать';
  if (adminMap) {
    const container = adminMap.getContainer();
    container.style.cursor = '';
    container.classList.remove('drawing-active');
    adminMap.dragging.enable();
    adminMap.doubleClickZoom.enable();
    adminMap.off('click', onMapClick);
    adminMap.off('mousemove', onMapMouseMove);
  }
  drawingMarkers.forEach(m => adminMap.removeLayer(m));
  drawingMarkers = [];
  if (drawingPolyline) { adminMap.removeLayer(drawingPolyline); drawingPolyline = null; }
  drawingPoints = [];
}

function getHexColor(type) {
  return { RED: '#EF4444', YELLOW: '#F59E0B', GREEN: '#10B981' }[type] || '#6B7280';
}

function onMapClick(e) {
  if (!isDrawingMode) return;
  const latlng = e.latlng;
  drawingPoints.push(latlng);
  
  const color = getHexColor(drawingColor);
  if (drawingPoints.length === 1) {
    const startMarker = L.circleMarker(latlng, {
      radius: 8,
      fillColor: color,
      fillOpacity: 1,
      color: '#ffffff',
      weight: 2,
      className: 'drawing-vertex'
    }).addTo(adminMap);
    
    startMarker.on('mouseover', () => {
      adminMap.getContainer().style.cursor = 'pointer';
      startMarker.setRadius(10);
      startMarker.bindTooltip("Замкнуть полигон", { direction: 'top', offset: [0, -10] }).openTooltip();
    });
    startMarker.on('mouseout', () => {
      adminMap.getContainer().style.cursor = 'crosshair';
      startMarker.setRadius(8);
      startMarker.closeTooltip();
    });
    startMarker.on('click', (ev) => {
      L.DomEvent.stopPropagation(ev);
      closePolygon();
    });
    drawingMarkers.push(startMarker);
    
    drawingPolyline = L.polyline([latlng, latlng], {
      color: color,
      weight: 3,
      dashArray: '5, 5'
    }).addTo(adminMap);
  } else {
    const vertexMarker = L.circleMarker(latlng, {
      radius: 5,
      fillColor: '#ffffff',
      fillOpacity: 1,
      color: color,
      weight: 2,
      className: 'drawing-vertex'
    }).addTo(adminMap);
    drawingMarkers.push(vertexMarker);
    drawingPolyline.setLatLngs(drawingPoints.concat([latlng]));
  }
}

function onMapMouseMove(e) {
  if (!isDrawingMode || drawingPoints.length === 0 || !drawingPolyline) return;
  drawingPolyline.setLatLngs(drawingPoints.concat([e.latlng]));
}

function closePolygon() {
  if (drawingPoints.length < 3) {
    alert("Нужно как минимум 3 точки!");
    return;
  }
  const color = getHexColor(drawingColor);
  if (drawingPolyline) { adminMap.removeLayer(drawingPolyline); drawingPolyline = null; }
  currentPolygon = L.polygon(drawingPoints, {
    color: color,
    fillColor: color,
    fillOpacity: 0.3,
    weight: 3
  }).addTo(adminMap);
  stopDrawing();
  
  editingZoneId = null;
  document.getElementById('zone-form-panel').style.display = 'block';
  document.getElementById('zone-form-title').textContent = 'Новая зона';
  document.getElementById('zf-name').value = '';
  document.getElementById('zf-type').value = drawingColor;
  document.getElementById('zf-alt').value = '50';
  
  const deleteBtn = document.getElementById('zf-delete-btn');
  if (deleteBtn) deleteBtn.style.display = 'none';
}

function renderZoneList() {
  const colors={RED:'#EF4444',YELLOW:'#F59E0B',GREEN:'#10B981'};
  document.getElementById('zone-list').innerHTML=allZones.length
    ? allZones.map(z=>`
        <div class="zone-list-item" id="zitem-${z.id}" onclick="selectZone(${z.id})">
          <div class="zone-dot" style="background:${colors[z.type]||'#6B7280'}"></div>
          <div class="zone-list-name">${esc(z.name)}</div>
          <span class="badge badge-${z.type?.toLowerCase()}">${z.type}</span>
          <button class="btn btn-danger btn-sm" onclick="deleteZone(event, ${z.id})">🗑</button>
        </div>`).join('')
    : '<div class="empty-state" style="padding:30px"><p>Нет зон. Нарисуйте полигон.</p></div>';
}

function selectZone(id) {
  const z=allZones.find(x=>x.id===id); if(!z) return;
  document.querySelectorAll('.zone-list-item').forEach(el=>el.classList.remove('selected'));
  const el=document.getElementById('zitem-'+id); if(el) el.classList.add('selected');
  editingZoneId=id;
  document.getElementById('zone-form-panel').style.display='block';
  document.getElementById('zone-form-title').textContent='Редактировать зону';
  document.getElementById('zf-name').value=z.name;
  document.getElementById('zf-type').value=z.type;
  document.getElementById('zf-alt').value=z.maxAltitude;
  
  const deleteBtn = document.getElementById('zf-delete-btn');
  if (deleteBtn) deleteBtn.style.display = 'inline-block';
  
  const poly = loadedPolygons[id];
  if (poly && adminMap) {
    adminMap.fitBounds(poly.getBounds());
  }
}

async function saveZone() {
  const name=document.getElementById('zf-name').value.trim();
  const type=document.getElementById('zf-type').value;
  const maxAltitude=parseInt(document.getElementById('zf-alt').value)||50;
  if(!name) return alert('Введите название зоны');

  if(editingZoneId) {
    await api(`/zones/${editingZoneId}`,{method:'PUT',body:JSON.stringify({name,type,maxAltitude})});
  } else {
    if(!currentPolygon) return alert('Нарисуйте зону на карте');
    let latlngs = currentPolygon.getLatLngs();
    if (Array.isArray(latlngs[0])) latlngs = latlngs[0];
    const coords = latlngs.map(p => [p.lng, p.lat]);
    await api('/zones',{method:'POST',body:JSON.stringify({name,type,coordinates:coords,maxAltitude})});
    if (adminMap) adminMap.removeLayer(currentPolygon);
    currentPolygon=null;
  }
  cancelZoneForm(); loadZones(); loadStats();
}

async function deleteZone(e, id) {
  if (e) {
    if (typeof e.stopPropagation === 'function') e.stopPropagation();
    else if (window.event) window.event.cancelBubble = true;
  }
  if(!confirm('Удалить зону?')) return;
  await api(`/zones/${id}`,{method:'DELETE'});
  cancelZoneForm();
  loadZones(); loadStats();
}

function cancelZoneForm() {
  document.getElementById('zone-form-panel').style.display='none';
  editingZoneId=null;
  if(currentPolygon){
    if (adminMap) adminMap.removeLayer(currentPolygon);
    currentPolygon=null;
  }
  const deleteBtn = document.getElementById('zf-delete-btn');
  if (deleteBtn) deleteBtn.style.display = 'none';
}

async function deleteCurrentZone() {
  if (!editingZoneId) return;
  await deleteZone(null, editingZoneId);
}

// ════════════════════════════════════
// COURSES
// ════════════════════════════════════
async function loadCourses() {
  try { allCourses=await api('/courses'); renderAdminCoursesList(); } catch{}
}

function renderAdminCoursesList() {
  const el=document.getElementById('admin-courses-list');
  el.innerHTML=allCourses.length
    ? allCourses.map(c=>`
        <div class="course-list-item ${c.id===activeCourseId?'active':''}" onclick="openAdminCourse(${c.id})">
          <div class="course-list-icon" style="background:${c.color}22">${courseEmoji(c.iconType)}</div>
          <div>
            <div class="course-list-name">${esc(c.title)}</div>
            <div class="course-list-steps">${c.steps?.length||0} шагов</div>
          </div>
        </div>`).join('')
    : '<div class="empty-state" style="padding:30px"><p>Нет курсов</p></div>';
}

function openAdminCourse(id) {
  activeCourseId=id;
  renderAdminCoursesList();
  const c=allCourses.find(x=>x.id===id); if(!c) return;
  const panel=document.getElementById('course-editor-panel');
  panel.innerHTML=`
    <div class="course-editor-header">
      <div>
        <div style="font-weight:700;font-size:1.1rem">${esc(c.title)}</div>
        <div style="color:var(--text-muted);font-size:0.82rem">${esc(c.description)}</div>
      </div>
      <div style="display:flex;gap:8px">
        <button class="btn btn-secondary btn-sm" onclick="openCourseModal(${c.id})">✏ Изм.</button>
        <button class="btn btn-danger btn-sm" onclick="deleteCourse(${c.id})">🗑</button>
      </div>
    </div>
    <div class="steps-editor" id="steps-editor-${c.id}">
      ${renderStepsEditor(c)}
      <button class="btn btn-secondary" style="width:100%;justify-content:center;margin-top:8px" onclick="addStep(${c.id})">+ Добавить шаг</button>
    </div>`;
}

function renderStepsEditor(c) {
  if(!c.steps?.length) return '<div class="empty-state" style="padding:30px"><p>Нет шагов. Добавьте первый.</p></div>';
  return c.steps.map((s,i)=>`
    <div class="step-editor-card" id="step-card-${s.id}">
      <div class="step-editor-top">
        <div style="display:flex;align-items:center;gap:10px">
          <div class="step-num">${i+1}</div>
          <input value="${esc(s.title)}" id="st-title-${s.id}" style="background:var(--bg-card2);border:1px solid var(--border);border-radius:8px;padding:6px 12px;color:var(--text);font-size:0.875rem;width:200px;font-family:inherit;outline:none">
        </div>
        <div style="display:flex;gap:6px">
          <div class="step-type-selector">
            ${['text','video','quiz'].map(t=>`<button class="step-type-btn ${s.type===t?'active':''}" onclick="changeStepType(${s.id},${c.id},'${t}',this)">${{text:'📄',video:'🎬',quiz:'📝'}[t]} ${t}</button>`).join('')}
          </div>
          <button class="btn btn-danger btn-sm" onclick="deleteStep(${s.id},${c.id})">🗑</button>
        </div>
      </div>
      ${renderStepInput(s)}
      <div style="margin-top:12px;text-align:right">
        <button class="btn btn-primary btn-sm" onclick="saveStep(${s.id},${c.id})">💾 Сохранить шаг</button>
      </div>
    </div>`).join('');
}

function renderStepInput(s) {
  if(s.type==='text') return `<textarea id="st-content-${s.id}" rows="5" style="width:100%;background:var(--bg);border:1px solid var(--border);border-radius:10px;padding:12px;color:var(--text);font-family:inherit;font-size:0.875rem;resize:vertical;outline:none" placeholder="Текст урока...">${esc(s.content||'')}</textarea>`;
  if(s.type==='video') return `<input id="st-content-${s.id}" value="${esc(s.content||'')}" placeholder="YouTube URL: https://youtube.com/watch?v=..." style="width:100%;background:var(--bg);border:1px solid var(--border);border-radius:10px;padding:11px 16px;color:var(--text);font-family:inherit;font-size:0.875rem;outline:none">`;
  if(s.type==='quiz') return renderQuizBuilder(s);
  return '';
}

function renderQuizBuilder(s) {
  const qs=s.questions||[{question:'',options:['','','',''],answer:0}];
  return `<div class="quiz-builder" id="quiz-${s.id}">
    ${qs.map((q,qi)=>`
      <div style="background:var(--bg-card2);border-radius:10px;padding:14px;margin-bottom:10px">
        <div style="font-size:0.8rem;color:var(--text-muted);margin-bottom:8px">Вопрос ${qi+1}</div>
        <input id="q-${s.id}-${qi}-q" value="${esc(q.question)}" placeholder="Вопрос..." style="width:100%;background:var(--bg);border:1px solid var(--border);border-radius:8px;padding:8px 12px;color:var(--text);font-family:inherit;font-size:0.875rem;outline:none;margin-bottom:10px">
        ${(q.options||[]).map((opt,oi)=>`
          <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
            <input type="radio" name="ans-${s.id}-${qi}" ${oi===q.answer?'checked':''} onchange="document.getElementById('qa-${s.id}-${qi}').value='${oi}'">
            <input id="q-${s.id}-${qi}-o${oi}" value="${esc(opt)}" placeholder="Вариант ${oi+1}" style="flex:1;background:var(--bg);border:1px solid var(--border);border-radius:8px;padding:7px 12px;color:var(--text);font-family:inherit;font-size:0.85rem;outline:none">
          </div>`).join('')}
        <input type="hidden" id="qa-${s.id}-${qi}" value="${q.answer||0}">
      </div>`).join('')}
    <input type="hidden" id="quiz-count-${s.id}" value="${qs.length}">
  </div>`;
}

function changeStepType(stepId, courseId, type, btn) {
  btn.closest('.step-type-selector').querySelectorAll('.step-type-btn').forEach(b=>b.classList.remove('active'));
  btn.classList.add('active');
  const c=allCourses.find(x=>x.id===courseId);
  const s=c?.steps?.find(x=>x.id===stepId);
  if(s){ s.type=type; const card=document.getElementById('step-card-'+stepId); if(card){ const inp=card.querySelector('.quiz-builder, textarea, input[id^="st-content"]'); if(inp) inp.outerHTML=renderStepInput({...s,type}); } }
}

async function saveStep(stepId, courseId) {
  const title=document.getElementById(`st-title-${stepId}`)?.value?.trim();
  const c=allCourses.find(x=>x.id===courseId);
  const s=c?.steps?.find(x=>x.id===stepId);
  if(!s||!title) return;
  const type=s.type;
  let content=null, questions=null;
  if(type!=='quiz') content=document.getElementById(`st-content-${stepId}`)?.value?.trim();
  else {
    const count=parseInt(document.getElementById(`quiz-count-${stepId}`)?.value||'1');
    questions=[];
    for(let qi=0;qi<count;qi++){
      const question=document.getElementById(`q-${stepId}-${qi}-q`)?.value?.trim()||'';
      const answer=parseInt(document.getElementById(`qa-${stepId}-${qi}`)?.value||'0');
      const options=[0,1,2,3].map(oi=>document.getElementById(`q-${stepId}-${qi}-o${oi}`)?.value?.trim()||'');
      questions.push({question,options,answer});
    }
  }
  await api(`/courses/${courseId}/steps/${stepId}`,{method:'PUT',body:JSON.stringify({title,type,content,questions,order:s.order})});
  await loadCourses(); openAdminCourse(courseId);
}

async function addStep(courseId) {
  const c=allCourses.find(x=>x.id===courseId);
  const order=(c?.steps?.length||0)+1;
  await api(`/courses/${courseId}/steps`,{method:'POST',body:JSON.stringify({title:'Новый шаг',type:'text',content:'',order})});
  await loadCourses(); openAdminCourse(courseId);
}

async function deleteStep(stepId, courseId) {
  if(!confirm('Удалить шаг?')) return;
  await api(`/courses/${courseId}/steps/${stepId}`,{method:'DELETE'});
  await loadCourses(); openAdminCourse(courseId);
}

function openCourseModal(id=null) {
  const c=id?allCourses.find(x=>x.id===id):null;
  document.getElementById('cm-title').textContent=c?'Редактировать курс':'Новый курс';
  document.getElementById('cm-id').value=c?.id||'';
  document.getElementById('cm-name').value=c?.title||'';
  document.getElementById('cm-desc').value=c?.description||'';
  document.getElementById('cm-icon').value=c?.iconType||'beginner';
  document.getElementById('cm-color').value=c?.color||'#2563EB';
  document.getElementById('cm-alert').innerHTML='';
  document.getElementById('course-modal').style.display='flex';
}
function closeCourseModal(){ document.getElementById('course-modal').style.display='none'; }

async function saveCourse() {
  const id=document.getElementById('cm-id').value;
  const body={title:document.getElementById('cm-name').value.trim(),description:document.getElementById('cm-desc').value.trim(),iconType:document.getElementById('cm-icon').value,color:document.getElementById('cm-color').value};
  if(!body.title) return showModalAlert('cm-alert','Название обязательно');
  if(id) await api(`/courses/${id}`,{method:'PUT',body:JSON.stringify(body)});
  else await api('/courses',{method:'POST',body:JSON.stringify(body)});
  closeCourseModal(); await loadCourses(); loadStats();
  if(id) openAdminCourse(parseInt(id));
}

async function deleteCourse(id) {
  if(!confirm('Удалить курс и все его шаги?')) return;
  await api(`/courses/${id}`,{method:'DELETE'});
  activeCourseId=null;
  document.getElementById('course-editor-panel').innerHTML='<div style="display:flex;align-items:center;justify-content:center;height:100%;color:var(--text-muted)"><div style="text-align:center"><div style="font-size:3rem;margin-bottom:12px">📚</div><p>Выберите курс слева</p></div></div>';
  await loadCourses(); loadStats();
}

function showModalAlert(elId, msg) {
  document.getElementById(elId).innerHTML=`<div class="alert alert-error">${msg}</div>`;
}

// ════════════════════════════════════
// SHOP (PRODUCTS)
// ════════════════════════════════════
async function loadProducts() {
  try { allProducts=await api('/products'); renderProductsTable(); } catch{}
}

function renderProductsTable() {
  const q=(document.getElementById('shop-search').value||'').toLowerCase();
  const items=allProducts.filter(p=>p.title.toLowerCase().includes(q));
  if(!items.length){
    document.getElementById('shop-table-body').innerHTML='<div class="empty-state"><div class="empty-state-icon">🛒</div><p>Нет товаров</p></div>';
    return;
  }
  document.getElementById('shop-table-body').innerHTML=`
    <table><thead><tr><th>Товар</th><th>Цена</th><th>Склад</th><th>Добавлен</th><th>Действия</th></tr></thead>
    <tbody>${items.map(p=>`
      <tr>
        <td style="display:flex;align-items:center;gap:12px">
          ${p.imageUrl?`<img src="${esc(p.imageUrl)}" style="width:40px;height:40px;object-fit:cover;border-radius:4px" onerror="this.style.display='none'">`:'<div style="width:40px;height:40px;background:#222;border-radius:4px;display:flex;align-items:center;justify-content:center;font-size:1.2rem">🛒</div>'}
          <strong>${esc(p.title)}</strong>
        </td>
        <td>$${p.price.toFixed(2)}</td>
        <td><span class="badge ${p.stock>0?'badge-green':'badge-red'}">${p.stock} шт</span></td>
        <td style="color:var(--text-muted)">${fmtDate(p.createdAt)}</td>
        <td>
          <div style="display:flex;gap:6px">
            <button class="btn btn-secondary btn-sm" onclick="openProductModal(${p.id})">✏ Изм.</button>
            <button class="btn btn-danger btn-sm" onclick="deleteProduct(${p.id})">🗑</button>
          </div>
        </td>
      </tr>`).join('')}
    </tbody></table>`;
}

function filterShop(){ renderProductsTable(); }

function openProductModal(id=null) {
  const p=id?allProducts.find(x=>x.id===id):null;
  document.getElementById('pm-title').textContent=p?'Редактировать товар':'Новый товар';
  document.getElementById('pm-id').value=p?.id||'';
  document.getElementById('pm-title-in').value=p?.title||'';
  document.getElementById('pm-price').value=p?.price||'';
  document.getElementById('pm-stock').value=p?.stock||'0';
  document.getElementById('pm-image').value=p?.imageUrl||'';
  document.getElementById('pm-images').value=p?.images?.join(', ')||'';
  document.getElementById('pm-desc').value=p?.description||'';
  document.getElementById('pm-alert').innerHTML='';
  document.getElementById('product-modal').style.display='flex';
}
function closeProductModal(){ document.getElementById('product-modal').style.display='none'; }

async function saveProduct() {
  const id=document.getElementById('pm-id').value;
  const imagesStr=document.getElementById('pm-images').value;
  const images=imagesStr?imagesStr.split(',').map(s=>s.trim()).filter(s=>s):[];
  const body={title:document.getElementById('pm-title-in').value.trim(),description:document.getElementById('pm-desc').value.trim(),price:document.getElementById('pm-price').value,stock:document.getElementById('pm-stock').value,imageUrl:document.getElementById('pm-image').value.trim(),images};
  if(!body.title||!body.price) return showModalAlert('pm-alert','Название и цена обязательны');
  try {
    if(id) await api(`/admin/products/${id}`,{method:'PUT',body:JSON.stringify(body)});
    else await api('/admin/products',{method:'POST',body:JSON.stringify(body)});
    closeProductModal(); loadProducts(); loadStats();
  } catch(e){ showModalAlert('pm-alert','Ошибка: '+e.message); }
}

async function deleteProduct(id) {
  if(!confirm('Удалить товар?')) return;
  await api(`/admin/products/${id}`,{method:'DELETE'});
  loadProducts(); loadStats();
}

// ════════════════════════════════════
// ORDERS
// ════════════════════════════════════
async function loadOrders() {
  try { allOrders=await api('/admin/orders'); renderOrdersTable(); } catch{}
}

function renderOrdersTable() {
  const q=(document.getElementById('orders-search').value||'').toLowerCase();
  const items=allOrders.filter(o=>o.id.toString().includes(q)||(o.user?.email||'').toLowerCase().includes(q));
  if(!items.length){
    document.getElementById('orders-table-body').innerHTML='<div class="empty-state"><div class="empty-state-icon">📦</div><p>Нет заказов</p></div>';
    return;
  }
  document.getElementById('orders-table-body').innerHTML=`
    <table><thead><tr><th>ID</th><th>Клиент</th><th>Сумма</th><th>Статус</th><th>Дата</th><th>Действия</th></tr></thead>
    <tbody>${items.map(o=>`
      <tr>
        <td><strong>#${o.id}</strong></td>
        <td>
          <div style="font-weight:600">${esc(o.user?.name||'—')}</div>
          <div style="font-size:0.75rem;color:var(--text-muted)">${esc(o.user?.email||'—')}</div>
        </td>
        <td><strong>$${o.totalAmount.toFixed(2)}</strong></td>
        <td><span class="badge ${o.status==='COMPLETED'?'badge-green':o.status==='CANCELLED'?'badge-red':'badge-yellow'}">${o.status}</span></td>
        <td style="color:var(--text-muted)">${fmtDate(o.createdAt)}</td>
        <td>
          <select style="background:#111;color:#fff;border:1px solid var(--border);border-radius:4px;padding:4px" onchange="changeOrderStatus(${o.id}, this.value)">
            <option value="PENDING" ${o.status==='PENDING'?'selected':''}>Ожидает</option>
            <option value="COMPLETED" ${o.status==='COMPLETED'?'selected':''}>Выполнен</option>
            <option value="CANCELLED" ${o.status==='CANCELLED'?'selected':''}>Отменён</option>
          </select>
        </td>
      </tr>`).join('')}
    </tbody></table>`;
}

function filterOrders(){ renderOrdersTable(); }

async function changeOrderStatus(id, status) {
  if(!confirm(`Изменить статус на ${status}?`)) return loadOrders(); // reload to reset select
  await api(`/admin/orders/${id}/status`,{method:'PUT',body:JSON.stringify({status})});
  loadOrders(); loadStats();
}

// ════════════════════════════════════
// SUPPORT REQUESTS
// ════════════════════════════════════
let allSupportRequests = [];
async function loadSupportRequests() {
  try {
    document.getElementById('support-table-body').innerHTML = '<div class="loading"><div class="spinner"></div><span>Загрузка...</span></div>';
    allSupportRequests = await api('/admin/support');
    renderSupportTable();
  } catch {}
}

function renderSupportTable() {
  const filter = document.getElementById('support-filter').value;
  let items = allSupportRequests;
  if (filter !== 'ALL') {
    items = allSupportRequests.filter(s => s.status === filter);
  }
  if (!items.length) {
    document.getElementById('support-table-body').innerHTML = '<div class="empty-state"><div class="empty-state-icon">💬</div><p>Нет запросов в службу поддержки</p></div>';
    return;
  }
  document.getElementById('support-table-body').innerHTML = `
    <table><thead><tr><th>ID</th><th>Пользователь</th><th>Сообщение</th><th>Статус</th><th>Дата</th><th>Действия</th></tr></thead>
    <tbody>${items.map(s => `
      <tr>
        <td><strong>#${s.id}</strong></td>
        <td>
          <div style="font-weight:600">${esc(s.user?.name || 'Гость')}</div>
          <div style="font-size:0.75rem;color:var(--text-muted)">${esc(s.user?.email || '—')}</div>
        </td>
        <td style="max-width: 400px; white-space: normal; word-break: break-all;">${esc(s.message)}</td>
        <td><span class="badge ${s.status === 'RESOLVED' ? 'badge-green' : 'badge-yellow'}">${s.status}</span></td>
        <td style="color:var(--text-muted)">${fmtDate(s.createdAt)}</td>
        <td>
          ${s.status === 'PENDING' ? `<button class="btn btn-success btn-sm" onclick="resolveSupport(${s.id})">Решить</button>` : '—'}
        </td>
      </tr>`).join('')}
    </tbody></table>`;
}

async function resolveSupport(id) {
  if (!confirm('Отметить этот запрос как решенный?')) return;
  await api(`/admin/support/${id}/status`, { method: 'PUT', body: JSON.stringify({ status: 'RESOLVED' }) });
  loadSupportRequests();
}

async function changeUserRole(userId, newRole) {
  if (!confirm(`Вы действительно хотите изменить роль этого пользователя на ${newRole}?`)) {
    loadUsersDashboard();
    return;
  }
  try {
    await api(`/admin/users/${userId}/role`, {
      method: 'PATCH',
      body: JSON.stringify({ role: newRole })
    });
    alert('Роль успешно обновлена');
    loadUsersDashboard();
  } catch (err) {
    loadUsersDashboard();
  }
}

function openCreateAdminModal() {
  document.getElementById('cam-name').value = '';
  document.getElementById('cam-email').value = '';
  document.getElementById('cam-password').value = '';
  document.getElementById('cam-role').value = 'admin';
  document.getElementById('cam-alert').innerHTML = '';
  document.getElementById('create-admin-modal').style.display = 'flex';
}

function closeCreateAdminModal() {
  document.getElementById('create-admin-modal').style.display = 'none';
}

async function saveAdmin() {
  const name = document.getElementById('cam-name').value.trim();
  const email = document.getElementById('cam-email').value.trim();
  const password = document.getElementById('cam-password').value;
  const role = document.getElementById('cam-role').value;
  if (!name || !email || !password) {
    return showModalAlert('cam-alert', 'Заполните все поля');
  }
  try {
    await api('/admin/create-admin', {
      method: 'POST',
      body: JSON.stringify({ name, email, password, role })
    });
    alert('Администратор успешно создан');
    closeCreateAdminModal();
    loadUsersDashboard();
    loadStats();
  } catch (err) {
    showModalAlert('cam-alert', 'Ошибка: ' + err.message);
  }
}

