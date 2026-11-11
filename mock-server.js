const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(readArg('--port') || 8080);
const allowedOrigins = new Set([
  'http://localhost:5555',
  'http://127.0.0.1:5555',
  'http://localhost:8123',
  'http://127.0.0.1:8123',
]);

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
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
  if (origin && allowedOrigins.has(origin)) {
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

const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin;
  if (req.method === 'OPTIONS') {
    if (origin && !allowedOrigins.has(origin)) return send(res, 403, { message: 'CORS' }, null);
    return send(res, 204, null, origin);
  }
  const url = new URL(req.url, `http://127.0.0.1:${port}`);
  const delay = Number(url.searchParams.get('__delay') || 0);
  if (delay > 0) await new Promise((resolve) => setTimeout(resolve, Math.min(delay, 5000)));
  const fail = Number(url.searchParams.get('__fail') || 0);
  if (fail >= 400) {
    return send(res, fail, { message: 'Учебный сбой сервера' }, origin);
  }
  if (url.pathname === '/api/__health') return send(res, 200, { ok: true }, origin);

  const parts = url.pathname.split('/').filter(Boolean);
  if (parts[0] !== 'api' || !resources[parts[1]]) {
    return send(res, 404, { message: 'Адрес не найден' }, origin);
  }
  const name = parts[1];
  const resource = resources[name];
  const rows = resource.rows();
  const query = Object.fromEntries(url.searchParams.entries());

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

server.listen(port, '127.0.0.1', () => {
  console.log(`Учебный API: http://127.0.0.1:${port}/api/__health`);
});
