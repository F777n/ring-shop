const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const port = Number(readArg('--port') || process.env.PORT || 8080);
const host = readArg('--host') || '0.0.0.0';
const staticRootArg = readArg('--static');
const accessTtl = Math.max(30, Number(readArg('--ttl') || 900));
const sessionTtl = Math.max(120, Number(readArg('--session') || 8 * 60 * 60));
const tokenSecret = 'ring-shop-practice';
const allowedOrigins = new Set([
  'http://localhost:5555',
  'http://127.0.0.1:5555',
  'http://localhost:8123',
  'http://127.0.0.1:8123',
  'http://127.0.0.1:8080',
  'http://localhost:8080',
  'https://f777n.github.io',
]);

function originAllowed(origin) {
  if (!origin || !allowedOrigins.has(origin)) return false;
  return true;
}

const catalog = JSON.parse(fs.readFileSync(path.join(__dirname, 'api', 'catalog.json'), 'utf8'));
const db = {
  products: catalog.products,
  brands: catalog.brands,
  categories: catalog.categories,
  disciplines: catalog.disciplines,
  customers: catalog.customers,
};

function readArg(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function send(res, status, body, origin) {
  const headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Pinggy-No-Screen',
  };
  if (originAllowed(origin)) {
    headers['Access-Control-Allow-Origin'] = origin;
    headers.Vary = 'Origin';
  }
  res.writeHead(status, headers);
  res.end(body == null ? '' : JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function pageOf(rows, query) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.max(1, Number(query.size) || 10);
  const from = (page - 1) * size;
  return { items: rows.slice(from, from + size), page, size, total: rows.length };
}

function compare(field) {
  return (a, b) => {
    const left = a[field];
    const right = b[field];
    if (typeof left === 'number' && typeof right === 'number') return left - right;
    return String(left ?? '').localeCompare(String(right ?? ''), 'ru');
  };
}

function applyList(rows, query, searchOf, yearOf) {
  let list = rows.filter((item) => query.includeDeleted === 'true' || !item.deletedAt);
  const needle = String(query.search || '').trim().toLowerCase();
  if (needle) list = list.filter((item) => searchOf(item).toLowerCase().includes(needle));
  if (query.yearFrom) list = list.filter((item) => yearOf(item) >= Number(query.yearFrom));
  if (query.yearTo) list = list.filter((item) => yearOf(item) <= Number(query.yearTo));
  const [field, direction] = String(query.sort || 'name,asc').split(',');
  list.sort(compare(field));
  if (direction === 'desc') list.reverse();
  return pageOf(list, query);
}

function linkedCount(field, id) {
  return db.products.filter((item) => {
    if (field === 'brandId') return item.brandId === id;
    if (field === 'categoryId') return (item.categoryIds || []).includes(id);
    return (item.disciplineIds || []).includes(id);
  }).length;
}

function word(count) {
  const mod10 = count % 10;
  const mod100 = count % 100;
  if (mod10 === 1 && mod100 !== 11) return 'товар';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'товара';
  return 'товаров';
}

const resources = {
  products: {
    rows: () => db.products,
    search: (item) => `${item.name} ${item.sku}`,
    year: (item) => item.year,
    extra(list, query) {
      if (query.brandId) list = list.filter((item) => item.brandId === Number(query.brandId));
      if (query.categoryId) {
        list = list.filter((item) => (item.categoryIds || []).includes(Number(query.categoryId)));
      }
      if (query.disciplineId) {
        list = list.filter((item) => (item.disciplineIds || []).includes(Number(query.disciplineId)));
      }
      return list;
    },
    validate(body, exceptId) {
      const sku = String(body.sku || '').trim().toLowerCase();
      const taken = db.products.some(
        (item) => item.id !== exceptId && String(item.sku || '').trim().toLowerCase() === sku,
      );
      if (taken) return { sku: 'Такой артикул уже есть' };
      return null;
    },
  },
  brands: {
    rows: () => db.brands,
    search: (item) => `${item.name} ${item.country} ${item.email || ''}`,
    year: (item) => item.foundedYear,
    extra: (list, query) =>
      query.country ? list.filter((item) => item.country === query.country) : list,
    blockDelete(item) {
      const count = linkedCount('brandId', item.id);
      return count
        ? `Нельзя удалить «${item.name}»: с записью связано ${count} ${word(count)}.`
        : null;
    },
  },
  categories: {
    rows: () => db.categories,
    search: (item) => `${item.name} ${item.code}`,
    year: (item) => item.introducedYear,
    extra(list, query) {
      return query.kind ? list.filter((item) => item.kind === query.kind) : list;
    },
    validate(body, exceptId) {
      const code = String(body.code || '').trim().toLowerCase();
      const taken = db.categories.some(
        (item) => item.id !== exceptId && String(item.code || '').trim().toLowerCase() === code,
      );
      if (taken) return { code: 'Такой код уже есть' };
      return null;
    },
    blockDelete(item) {
      const count = linkedCount('categoryId', item.id);
      return count
        ? `Нельзя удалить «${item.name}»: с записью связано ${count} ${word(count)}.`
        : null;
    },
  },
  disciplines: {
    rows: () => db.disciplines,
    search: (item) => `${item.name} ${item.country}`,
    year: (item) => item.establishedYear,
    extra: (list, query) =>
      query.country ? list.filter((item) => item.country === query.country) : list,
    blockDelete(item) {
      const count = linkedCount('disciplineId', item.id);
      return count
        ? `Нельзя удалить «${item.name}»: с записью связано ${count} ${word(count)}.`
        : null;
    },
  },
  customers: {
    rows: () => db.customers,
    search: (item) => `${item.fullName} ${item.email} ${item.card ? item.card.number : ''}`,
    year: (item) => item.birthYear,
    extra(list, query) {
      if (query.city) list = list.filter((item) => item.city === query.city);
      if (query.card === '1') list = list.filter((item) => item.card && item.card.active);
      if (query.card === '0') list = list.filter((item) => item.card && !item.card.active);
      return list;
    },
    validate(body, exceptId) {
      const email = String(body.email || '').trim().toLowerCase();
      const taken = db.customers.some(
        (item) => item.id !== exceptId && String(item.email || '').trim().toLowerCase() === email,
      );
      if (taken) return { email: 'Такая почта уже есть' };
      return null;
    },
  },
};

function nextId(rows) {
  return rows.reduce((max, item) => Math.max(max, item.id || 0), 0) + 1;
}

function hashPassword(password) {
  return crypto.createHash('sha256').update(`ring:${password}`).digest('hex');
}

function passwordProblems(password) {
  const text = String(password || '');
  if (text.length < 8) return 'Минимум 8 символов';
  if (!/\d/.test(text)) return 'Добавьте цифру';
  if (!/[^A-Za-zА-Яа-яЁё0-9]/.test(text)) return 'Добавьте специальный символ';
  return null;
}

const accounts = [
  { id: 1, username: 'buyer', passwordHash: hashPassword('Buyer123!'), fullName: 'Иванов Пётр', role: 'buyer' },
  { id: 2, username: 'seller', passwordHash: hashPassword('Seller123!'), fullName: 'Петрова Анна', role: 'seller' },
  { id: 3, username: 'admin', passwordHash: hashPassword('Admin123!'), fullName: 'Сидоров Игорь', role: 'admin' },
];

const reservations = [
  {
    id: 1,
    userId: 1,
    productName: 'Перчатки Winning MS-600',
    dueAt: new Date(Date.now() + 3 * 24 * 3600 * 1000).toISOString(),
    status: 'open',
  },
];
const sales = [];

function sign(payload) {
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', tokenSecret).update(body).digest('base64url');
  return `${body}.${sig}`;
}

function verify(token) {
  if (!token || !token.includes('.')) return null;
  const [body, sig] = token.split('.');
  const expected = crypto.createHmac('sha256', tokenSecret).update(body).digest('base64url');
  const left = Buffer.from(sig);
  const right = Buffer.from(expected);
  if (left.length !== right.length || !crypto.timingSafeEqual(left, right)) return null;
  try {
    return JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch (error) {
    return null;
  }
}

function publicUser(user) {
  return { id: user.id, username: user.username, fullName: user.fullName, role: user.role };
}

function issueTokens(user, sessionExp) {
  const now = Math.floor(Date.now() / 1000);
  const session = sessionExp || now + sessionTtl;
  return {
    accessToken: sign({
      sub: user.id,
      username: user.username,
      role: user.role,
      type: 'access',
      exp: now + accessTtl,
      sessionExp: session,
    }),
    refreshToken: sign({
      sub: user.id,
      username: user.username,
      role: user.role,
      type: 'refresh',
      exp: now + 7 * 24 * 3600,
      sessionExp: session,
    }),
    sessionExpiresAt: new Date(session * 1000).toISOString(),
    user: publicUser(user),
  };
}

function readActor(req) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  const payload = verify(token);
  const now = Math.floor(Date.now() / 1000);
  if (!payload || payload.type !== 'access' || payload.exp < now || payload.sessionExp < now) return null;
  return payload;
}

function permit(actor, method, name, parts, query) {
  if (name === 'customers' && actor.role === 'buyer') return false;
  if (method === 'GET') return true;
  if (name === 'products' && parts[3] === 'sell') return actor.role === 'seller';
  const hard = method === 'DELETE' && query.hard === 'true';
  const restore = method === 'POST' && parts[3] === 'restore';
  if (hard || restore) return actor.role === 'admin';
  return actor.role === 'seller' || actor.role === 'admin';
}

async function handleAuth(req, res, parts, origin) {
  const action = parts[2];
  if (req.method === 'GET' && action === 'me') {
    const actor = readActor(req);
    if (!actor) return send(res, 401, { message: 'Требуется вход в систему.' }, origin);
    const user = accounts.find((item) => item.id === actor.sub);
    if (!user) return send(res, 401, { message: 'Требуется вход в систему.' }, origin);
    return send(res, 200, publicUser(user), origin);
  }
  if (req.method === 'POST' && action === 'logout') {
    return send(res, 204, null, origin);
  }
  const body = req.method === 'POST' ? await readBody(req) : {};
  if (req.method === 'POST' && action === 'login') {
    const username = String(body.username || '').trim();
    const user = accounts.find((item) => item.username === username);
    if (!user || user.passwordHash !== hashPassword(body.password || '')) {
      return send(res, 401, { message: 'Неверный логин или пароль' }, origin);
    }
    return send(res, 200, issueTokens(user), origin);
  }
  if (req.method === 'POST' && action === 'register') {
    const username = String(body.username || '').trim();
    const fullName = String(body.fullName || '').trim();
    const problem = passwordProblems(body.password);
    const errors = {};
    if (username.length < 3) errors.username = 'Логин от 3 символов';
    if (fullName.length < 2) errors.fullName = 'Укажите имя';
    if (problem) errors.password = problem;
    if (accounts.some((item) => item.username === username)) errors.username = 'Такой логин уже есть';
    if (Object.keys(errors).length) {
      return send(res, 422, { message: 'Ошибка валидации', errors }, origin);
    }
    const user = {
      id: nextId(accounts),
      username,
      passwordHash: hashPassword(body.password),
      fullName,
      role: 'buyer',
    };
    accounts.push(user);
    return send(res, 201, issueTokens(user), origin);
  }
  if (req.method === 'POST' && action === 'refresh') {
    const payload = verify(body.refreshToken);
    const now = Math.floor(Date.now() / 1000);
    if (!payload || payload.type !== 'refresh' || payload.exp < now || payload.sessionExp < now) {
      return send(res, 401, { message: 'Сессия истекла. Войдите снова.' }, origin);
    }
    const user = accounts.find((item) => item.id === payload.sub);
    if (!user) return send(res, 401, { message: 'Сессия истекла. Войдите снова.' }, origin);
    return send(res, 200, issueTokens(user, payload.sessionExp), origin);
  }
  return send(res, 404, { message: 'Адрес не найден' }, origin);
}

async function handleOrders(req, res, parts, origin, actor) {
  if (actor.role !== 'buyer') {
    return send(res, 403, { message: 'Недостаточно прав для этого действия.' }, origin);
  }
  if (req.method === 'GET' && parts.length === 2) {
    const items = reservations.filter((item) => item.userId === actor.sub);
    return send(res, 200, { items }, origin);
  }
  if (req.method === 'POST' && parts[3] === 'extend') {
    const order = reservations.find((item) => item.id === Number(parts[2]) && item.userId === actor.sub);
    if (!order) return send(res, 404, { message: 'Бронь не найдена' }, origin);
    order.dueAt = new Date(new Date(order.dueAt).getTime() + 7 * 24 * 3600 * 1000).toISOString();
    return send(res, 200, order, origin);
  }
  return send(res, 404, { message: 'Адрес не найден' }, origin);
}

async function handleSales(req, res, parts, origin, actor) {
  if (actor.role !== 'seller') {
    return send(res, 403, { message: 'Недостаточно прав для этого действия.' }, origin);
  }
  if (req.method === 'GET' && parts.length === 2) return send(res, 200, { items: sales }, origin);
  if (req.method === 'POST' && parts.length === 2) {
    const body = await readBody(req);
    const product = db.products.find((item) => item.id === Number(body.productId));
    const customer = db.customers.find((item) => item.id === Number(body.customerId));
    if (!product || !customer) return send(res, 404, { message: 'Товар или клиент не найден' }, origin);
    if ((product.stockAvailable || 0) <= 0) {
      return send(res, 409, { message: `Нет свободного остатка: «${product.name}» продать нельзя.` }, origin);
    }
    product.stockAvailable -= 1;
    const sale = {
      id: nextId(sales),
      productId: product.id,
      productName: product.name,
      customerId: customer.id,
      customerName: customer.fullName,
      status: 'open',
    };
    sales.push(sale);
    return send(res, 201, sale, origin);
  }
  if (req.method === 'POST' && parts[3] === 'close') {
    const sale = sales.find((item) => item.id === Number(parts[2]));
    if (!sale) return send(res, 404, { message: 'Продажа не найдена' }, origin);
    sale.status = 'closed';
    return send(res, 200, sale, origin);
  }
  return send(res, 404, { message: 'Адрес не найден' }, origin);
}

async function handleUsers(req, res, parts, origin, actor) {
  if (actor.role !== 'admin') {
    return send(res, 403, { message: 'Недостаточно прав для этого действия.' }, origin);
  }
  if (req.method === 'GET' && parts.length === 2) {
    return send(res, 200, { items: accounts.map(publicUser) }, origin);
  }
  if (req.method === 'PUT' && parts.length === 3) {
    const user = accounts.find((item) => item.id === Number(parts[2]));
    if (!user) return send(res, 404, { message: 'Пользователь не найден' }, origin);
    const body = await readBody(req);
    if (!['buyer', 'seller', 'admin'].includes(body.role)) {
      return send(res, 422, { message: 'Ошибка валидации', errors: { role: 'Неизвестная роль' } }, origin);
    }
    if (user.id === actor.sub) {
      return send(res, 409, { message: 'Свою роль менять нельзя.' }, origin);
    }
    user.role = body.role;
    return send(res, 200, publicUser(user), origin);
  }
  return send(res, 404, { message: 'Адрес не найден' }, origin);
}

function handleStats(req, res, origin, actor) {
  if (actor.role !== 'admin') {
    return send(res, 403, { message: 'Недостаточно прав для этого действия.' }, origin);
  }
  const alive = (rows) => rows.filter((item) => !item.deletedAt).length;
  return send(
    res,
    200,
    {
      products: alive(db.products),
      brands: alive(db.brands),
      customers: alive(db.customers),
      users: accounts.length,
      openSales: sales.filter((item) => item.status === 'open').length,
    },
    origin,
  );
}

const staticTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.map': 'application/json; charset=utf-8',
};

function serveStatic(req, res, url) {
  if (!staticRootArg || (req.method !== 'GET' && req.method !== 'HEAD')) return false;
  if (url.pathname === '/api' || url.pathname.startsWith('/api/')) return false;
  const root = path.resolve(staticRootArg);
  let relative = decodeURIComponent(url.pathname);
  if (relative.endsWith('/')) relative += 'index.html';
  const requested = path.resolve(root, `.${relative}`);
  const fromRoot = path.relative(root, requested);
  const inside = fromRoot === '' || (!fromRoot.startsWith('..') && !path.isAbsolute(fromRoot));
  const file = inside && fs.existsSync(requested) && fs.statSync(requested).isFile()
    ? requested
    : path.join(root, 'index.html');
  if (!fs.existsSync(file)) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Сборка не найдена');
    return true;
  }
  const type = staticTypes[path.extname(file).toLowerCase()] || 'application/octet-stream';
  res.writeHead(200, { 'Content-Type': type });
  if (req.method === 'HEAD') {
    res.end();
    return true;
  }
  fs.createReadStream(file).pipe(res);
  return true;
}

const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin;
  if (req.method === 'OPTIONS') {
    if (origin && !originAllowed(origin)) return send(res, 403, { message: 'CORS' }, null);
    return send(res, 204, null, origin);
  }
  const url = new URL(req.url, `http://127.0.0.1:${port}`);
  if (serveStatic(req, res, url)) return;
  const delay = Number(url.searchParams.get('__delay') || 0);
  if (delay > 0) await new Promise((resolve) => setTimeout(resolve, Math.min(delay, 5000)));
  const fail = Number(url.searchParams.get('__fail') || 0);
  if (fail >= 400) {
    return send(res, fail, { message: 'Учебный сбой сервера' }, origin);
  }
  if (url.pathname === '/api/__health') return send(res, 200, { ok: true }, origin);

  const parts = url.pathname.split('/').filter(Boolean);
  const query = Object.fromEntries(url.searchParams.entries());
  if (parts[0] !== 'api') return send(res, 404, { message: 'Адрес не найден' }, origin);
  if (parts[1] === 'auth') return handleAuth(req, res, parts, origin);
  const actor = readActor(req);
  if (!actor) return send(res, 401, { message: 'Требуется вход в систему.' }, origin);
  if (parts[1] === 'orders') return handleOrders(req, res, parts, origin, actor);
  if (parts[1] === 'sales') return handleSales(req, res, parts, origin, actor);
  if (parts[1] === 'users') return handleUsers(req, res, parts, origin, actor);
  if (parts[1] === 'stats') return handleStats(req, res, origin, actor);
  if (!resources[parts[1]]) return send(res, 404, { message: 'Адрес не найден' }, origin);
  if (!permit(actor, req.method, parts[1], parts, query)) {
    return send(res, 403, { message: 'Недостаточно прав для этого действия.' }, origin);
  }
  const name = parts[1];
  const resource = resources[name];
  const rows = resource.rows();

  try {
    if (req.method === 'GET' && parts.length === 2) {
      let list = rows.slice();
      if (resource.extra) list = resource.extra(list, query);
      return send(res, 200, applyList(list, query, resource.search, resource.year), origin);
    }

    if (req.method === 'GET' && name === 'products' && parts[2] === 'sku-taken') {
      const sku = String(query.sku || '').trim().toLowerCase();
      const exceptId = Number(query.exceptId || 0);
      const taken = rows.some(
        (item) => item.id !== exceptId && String(item.sku || '').trim().toLowerCase() === sku,
      );
      return send(res, 200, { taken }, origin);
    }

    if (req.method === 'POST' && parts[2] === 'bulk-delete') {
      const body = await readBody(req);
      const ids = Array.isArray(body.ids) ? body.ids.map(Number) : [];
      const seen = new Set();
      let deleted = 0;
      for (const id of ids) {
        if (seen.has(id)) continue;
        seen.add(id);
        const item = rows.find((row) => row.id === id);
        if (!item || item.deletedAt) continue;
        item.deletedAt = new Date().toISOString();
        deleted += 1;
      }
      return send(res, 200, { deleted }, origin);
    }

    if (req.method === 'POST' && parts.length === 2) {
      const body = await readBody(req);
      const errors = resource.validate ? resource.validate(body) : null;
      if (errors) return send(res, 422, { message: 'Ошибка валидации', errors }, origin);
      const created = { ...body, id: nextId(rows), deletedAt: null };
      rows.push(created);
      return send(res, 201, created, origin);
    }

    const id = Number(parts[2]);
    const item = rows.find((row) => row.id === id);
    if (!item && parts[2] !== 'sku-taken') return send(res, 404, { message: 'Запись не найдена' }, origin);

    if (req.method === 'GET' && parts.length === 3) return send(res, 200, item, origin);

    if (req.method === 'PUT' && parts.length === 3) {
      const body = await readBody(req);
      const errors = resource.validate ? resource.validate(body, id) : null;
      if (errors) return send(res, 422, { message: 'Ошибка валидации', errors }, origin);
      Object.assign(item, body, { id, deletedAt: item.deletedAt || null });
      return send(res, 200, item, origin);
    }

    if (req.method === 'DELETE' && parts.length === 3) {
      if (query.hard === 'true') {
        const blocked = resource.blockDelete ? resource.blockDelete(item) : null;
        if (blocked) return send(res, 409, { message: blocked }, origin);
        rows.splice(rows.indexOf(item), 1);
        return send(res, 204, null, origin);
      }
      const blocked = resource.blockDelete ? resource.blockDelete(item) : null;
      if (blocked) return send(res, 409, { message: blocked }, origin);
      item.deletedAt = new Date().toISOString();
      return send(res, 200, item, origin);
    }

    if (req.method === 'POST' && parts[3] === 'restore') {
      item.deletedAt = null;
      return send(res, 200, item, origin);
    }

    if (req.method === 'POST' && name === 'products' && parts[3] === 'sell') {
      if ((item.stockAvailable || 0) <= 0) {
        return send(
          res,
          409,
          { message: `Нет свободного остатка: «${item.name}» продать нельзя.` },
          origin,
        );
      }
      item.stockAvailable -= 1;
      return send(res, 200, item, origin);
    }

    return send(res, 404, { message: 'Адрес не найден' }, origin);
  } catch (error) {
    return send(res, 400, { message: 'Некорректный запрос' }, origin);
  }
});

server.listen(port, host, () => {
  console.log(`Учебный API: http://127.0.0.1:${port}/api/__health`);
  if (staticRootArg) {
    console.log(`Магазин и API: http://127.0.0.1:${port}/`);
  }
});
