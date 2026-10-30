const state = {
    data: null,
    section: 'catalog',
    query: '',
    category: 'all',
    page: 0,
    recipe: null,
    history: [],
    clockSkew: 0,
};

const NAV = [
    { id: 'catalog', label: 'Weapon Catalog', show: () => true },
    { id: 'manufacturing', label: 'Weapon Manufacturing', show: () => can('manufacture') },
    { id: 'bench', label: 'Crafting Bench', show: () => can('manufacture') || !!(state.data && state.data.publicCraft) },
    { id: 'materials', label: 'Material Inventory', show: () => can('materials') },
    { id: 'stock', label: 'Store Stock', show: () => can('stock') || can('prices') },
    { id: 'dashboard', label: 'Business Dashboard', show: () => can('dashboard') },
    { id: 'employees', label: 'Employee Management', show: () => can('hire') || can('fire') || can('permissions') },
    { id: 'recipes', label: 'Recipe Management', show: () => can('recipes') },
    { id: 'finance', label: 'Financial Management', show: () => can('deposit') || can('withdraw') || !!(state.data && state.data.owner) },
    { id: 'sales', label: 'Sales History', show: () => can('reports') },
    { id: 'mfg', label: 'Manufacturing History', show: () => can('reports') },
    { id: 'settings', label: 'Settings', show: () => can('settings') || can('benches') },
];

const resource = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'dj-weaponstore';

function can(perm) {
    if (!state.data) return false;
    if (state.data.admin || state.data.owner) return true;
    return !!(state.data.perms && state.data.perms[perm]);
}

function esc(value) {
    return String(value ?? '').replace(/[&<>"']/g, (char) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[char]));
}

function money(value) {
    return '$' + Math.floor(Number(value) || 0).toLocaleString('en-US');
}

function rpc(action, payload) {
    return fetch(`https://${resource}/rpc`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ action, payload: payload || {} }),
    }).then((res) => res.json()).catch(() => ({ ok: false, error: 'nui_failed', message: 'The interface lost its connection.' }));
}

function toast(message, ok) {
    const node = document.getElementById('toast');
    node.textContent = message || (ok ? 'Done' : 'Failed');
    node.className = ok ? 'ok' : 'error';
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => { node.className = 'hidden'; }, 3200);
}

function setLoading(on) {
    document.getElementById('loading').classList.toggle('hidden', !on);
}

async function run(action, payload, refresh) {
    setLoading(true);
    const result = await rpc(action, Object.assign({ storeId: state.data && state.data.store && state.data.store.id }, payload || {}));
    setLoading(false);
    toast(result.message || result.error || (result.ok ? 'Done' : 'Failed'), !!result.ok);
    if (result.ok && refresh) await reload();
    return result;
}

async function reload() {
    if (!state.data || !state.data.store) return;
    const next = await rpc('getState', {
        storeId: state.data.store.id,
        focus: state.section,
        benchId: state.data.bench && state.data.bench.id,
    });
    if (!next || !next.ok) {
        toast(next && (next.message || next.error) || 'Failed', false);
        return;
    }
    const section = state.section;
    const query = state.query;
    const category = state.category;
    state.data = next;
    state.section = section;
    state.query = query;
    state.category = category;
    if (next.serverNow) state.clockSkew = next.serverNow - Math.floor(Date.now() / 1000);
    render();
}

function show() {
    document.getElementById('app').classList.remove('hidden');
}

function hide() {
    document.getElementById('app').classList.add('hidden');
}

function categories() {
    const list = (state.data && state.data.categories) || [];
    return `<option value="all">All categories</option>` + list.map((row) => `<option value="${esc(row.id)}" ${state.category === row.id ? 'selected' : ''}>${esc(row.label)}</option>`).join('');
}

function filtered() {
    const q = state.query.trim().toLowerCase();
    return ((state.data && state.data.catalog) || []).filter((item) => {
        if (state.category !== 'all' && item.category !== state.category && item.family !== state.category) return false;
        if (!q) return true;
        return `${item.label} ${item.item} ${item.id} ${item.ammo || ''} ${item.kind || ''}`.toLowerCase().includes(q);
    });
}

function pageSlice(list) {
    const size = 12;
    const pages = Math.max(1, Math.ceil(list.length / size));
    if (state.page >= pages) state.page = pages - 1;
    if (state.page < 0) state.page = 0;
    return { rows: list.slice(state.page * size, state.page * size + size), pages, size };
}

function pager(pages) {
    return `<div class="pager"><button type="button" class="ghost" data-act="page" data-dir="-1">Prev</button><span class="muted">${state.page + 1} / ${pages}</span><button type="button" class="ghost" data-act="page" data-dir="1">Next</button></div>`;
}

function thumb(item) {
    if (!item.image) return `<div class="thumb"><span class="tag">${esc(item.kind || 'item')}</span></div>`;
    return `<div class="thumb"><img src="${esc(item.image)}" alt="" onerror="this.remove()" /></div>`;
}

function craftBanner() {
    const craft = state.data && state.data.craft;
    if (!craft || craft.phase === 'done' || craft.phase === 'failed' || craft.phase === 'cancelled') return '';
    const left = Math.max(0, (craft.endsAt || 0) - (Math.floor(Date.now() / 1000) + state.clockSkew));
    return `<div class="panel craft-bar" id="craftBanner"><strong>${esc(craft.label || 'Craft')}</strong> <span class="muted" id="craftLeft">${left}s remaining</span> <div class="actions"><button type="button" class="danger" data-act="cancel-craft" data-token="${esc(craft.token || '')}">Cancel craft</button></div></div>`;
}

function toolbarInner() {
    return `<input id="search" type="search" placeholder="Search name, id, ammo" value="${esc(state.query)}" /><select id="category">${categories()}</select>`;
}

function toolbar() {
    return `<div class="toolbar">${toolbarInner()}</div>`;
}

function card(item, mode) {
    const buy = item.purchasable !== false && (item.stock > 0 || (state.data.payments && state.data.payments.direct));
    const make = (mode === 'make' || mode === 'bench') && item.craftable && item.enabled !== false;
    return `<article class="card" data-id="${esc(item.id)}">
        ${thumb(item)}
        <div class="tag">${esc((item.category || '').replace(/_/g, ' '))}</div>
        <h3>${esc(item.label)}</h3>
        <div class="muted">${esc(item.description || '')}</div>
        <div class="price">${money(item.price)} <span class="muted">stock ${Number(item.stock) || 0}</span></div>
        <div class="muted">${item.time ? `${item.time}s · ${item.xp || 0} XP · difficulty ${item.difficulty || 1}` : ''}</div>
        <div class="actions">
            ${buy ? `<button type="button" class="solid" data-act="buy" data-id="${esc(item.id)}">Buy</button>` : ''}
            ${make ? `<button type="button" class="ghost" data-act="craft" data-id="${esc(item.id)}">Manufacture</button>` : ''}
        </div>
    </article>`;
}

function viewCatalog(mode) {
    const list = filtered();
    const slice = pageSlice(list);
    const bench = state.data.bench;
    const benchNote = mode === 'bench'
        ? `<div class="panel">Bench: ${esc(bench ? bench.label : 'Stand at a bench')} · ${esc(bench ? bench.benchType : '')} · output ${esc(bench ? bench.output : 'stock')}</div>`
        : '';
    const payments = state.data.payments || {};
    const limits = state.data.limits || {};
    const showQty = mode !== 'catalog' || payments.direct;
    const qty = showQty ? `<label>Qty <input id="qty" type="number" min="1" max="${mode === 'catalog' ? (limits.purchase || 10) : (limits.craft || 5)}" value="1" /></label>` : '';
    const benchSelect = mode === 'manufacturing' ? `<label>Bench <select id="benchPick">${(state.data.benches || []).map((row) => `<option value="${row.id}">${esc(row.label)} (${esc(row.benchType)})</option>`).join('')}</select></label>` : '';
    const pay = mode === 'catalog' ? `<label>Pay <select id="account">${payments.cash ? '<option value="cash">Cash</option>' : ''}${payments.bank ? '<option value="bank">Bank</option>' : ''}</select></label>` : '';
    return `${craftBanner()}${benchNote}<div class="toolbar">${toolbarInner()}${qty}${benchSelect}${pay}</div>
        <div class="card-grid">${slice.rows.map((item) => card(item, mode === 'catalog' ? 'buy' : 'make')).join('') || '<div class="empty">Nothing in this filter.</div>'}</div>${pager(slice.pages)}`;
}

function viewMaterials() {
    const rows = state.data.materials || [];
    const suppliers = state.data.suppliers || [];
    return `${craftBanner()}<div class="split">
        <div class="panel" style="flex:2"><h3>Storage ${rows.reduce((sum, row) => sum + (row.count || 0), 0)} / ${state.data.materialCapacity || 0}</h3>
        <table><thead><tr><th>Material</th><th>Category</th><th>Stock</th><th>Unit</th><th></th></tr></thead><tbody>
        ${rows.map((row) => `<tr data-item="${esc(row.item)}"><td>${esc(row.label)}</td><td>${esc(row.category)}</td><td>${row.count}</td><td>${money(row.price)}</td>
        <td><input data-qty type="number" min="1" value="1" style="width:70px" />
        <button type="button" class="ghost" data-act="deposit-mat" data-item="${esc(row.item)}">Deposit</button>
        <button type="button" class="ghost" data-act="withdraw-mat" data-item="${esc(row.item)}">Withdraw</button></td></tr>`).join('')}
        </tbody></table></div>
        <div class="panel stack" style="flex:1"><h3>Suppliers</h3>
        <label>Supplier <select id="supplier">${suppliers.map((row) => `<option value="${esc(row.id)}">${esc(row.label)}</option>`).join('')}</select></label>
        <label>Material <select id="supplyItem">${rows.map((row) => `<option value="${esc(row.item)}">${esc(row.label)}</option>`).join('')}</select></label>
        <label>Qty <input id="supplyQty" type="number" min="1" value="10" /></label>
        <button type="button" class="solid" data-act="supply-buy">Buy from supplier</button>
        <button type="button" class="ghost" data-act="load-history" data-kind="materials">Usage history</button>
        <div id="historyBox"></div></div></div>`;
}

function viewStock() {
    const rows = (state.data.catalog || []).filter((item) => state.category === 'all' || item.category === state.category || item.family === state.category);
    const q = state.query.trim().toLowerCase();
    const shown = rows.filter((item) => !q || `${item.label} ${item.id}`.toLowerCase().includes(q));
    return `${toolbar()}<table><thead><tr><th>Weapon</th><th>Stock</th><th>Made</th><th>Sold</th><th>Price</th><th></th></tr></thead><tbody>
        ${shown.slice(0, 40).map((item) => `<tr><td>${esc(item.label)}<div class="muted">${esc(item.id)}</div></td><td>${item.stock || 0}</td><td>${item.manufactured || 0}</td><td>${item.sold || 0}</td>
        <td><input data-price="${esc(item.id)}" type="number" value="${item.priceOverride || item.price}" style="width:100px" /></td>
        <td>${can('prices') ? `<button class="ghost" data-act="set-price" data-id="${esc(item.id)}">Set price</button>` : ''}
        ${can('stock') ? `<button class="ghost" data-act="stock-add" data-id="${esc(item.id)}">+1</button><button class="ghost" data-act="stock-remove" data-id="${esc(item.id)}">-1</button>` : ''}</td></tr>`).join('')}
        </tbody></table>`;
}

function viewDashboard() {
    const dash = state.data.dashboard || {};
    const stats = [
        ['Balance', money(dash.balance)],
        ['Stock units', dash.stockCount || 0],
        ['Stock value', money(dash.stockValue)],
        ['Manufactured', dash.manufactured || 0],
        ['Sold', dash.sold || 0],
        ['Employees', dash.employees || 0],
        ['Sales today', dash.salesToday || 0],
        ['Revenue today', money(dash.revenueToday)],
    ];
    return `<div class="stat-grid">${stats.map((row) => `<div class="stat"><span class="muted">${esc(row[0])}</span><b>${esc(row[1])}</b></div>`).join('')}</div>
        <div class="split"><div class="panel" style="flex:1"><h3>Recent transactions</h3><table>${(dash.transactions || []).map((row) => `<tr><td>${esc(row.kind)}</td><td>${money(row.amount)}</td><td>${esc(row.reason || '')}</td></tr>`).join('')}</table></div>
        <div class="panel" style="flex:1"><h3>Recent crafts</h3><table>${(dash.crafts || []).map((row) => `<tr><td>${esc(row.label || row.catalog_id)}</td><td>${row.quantity}</td><td>${row.success ? 'ok' : 'fail'}</td></tr>`).join('')}</table></div></div>`;
}

function viewEmployees() {
    const grades = state.data.grades || {};
    const gradeOptions = Object.keys(grades).map((key) => `<option value="${esc(key)}">${esc(grades[key])}</option>`).join('');
    const perms = state.data.permissions || [];
    return `<div class="panel stack" style="margin-bottom:12px"><h3>Hire</h3><div class="form-grid">
        <label>Server ID <input id="hireId" type="number" min="1" /></label>
        <label>Grade <select id="hireGrade">${gradeOptions}</select></label>
        <button type="button" class="solid" data-act="hire">Hire</button></div></div>
        ${(state.data.employees || []).map((emp) => `<div class="panel" style="margin-bottom:8px"><h3>${esc(emp.name)} <span class="tag ${emp.online ? 'red' : ''}">${emp.online ? 'online' : 'offline'}</span></h3>
        <div class="muted">${esc(emp.identifier)} · ${esc(emp.gradeLabel)}</div>
        <div class="actions">
            <button class="ghost" data-act="grade" data-id="${esc(emp.identifier)}" data-grade="${Math.max(0, (emp.grade || 0) - 1)}">Demote</button>
            <button class="ghost" data-act="grade" data-id="${esc(emp.identifier)}" data-grade="${(emp.grade || 0) + 1}">Promote</button>
            <button class="ghost" data-act="grade" data-id="${esc(emp.identifier)}" data-grade="${emp.grade || 0}" data-template="1">Apply grade template</button>
            <button class="danger" data-act="fire" data-id="${esc(emp.identifier)}">Fire</button>
        </div>
        <div class="checks" data-perms="${esc(emp.identifier)}">${perms.map((perm) => `<label><input type="checkbox" value="${esc(perm)}" ${(emp.permissions || []).includes(perm) ? 'checked' : ''}/> ${esc(perm)}</label>`).join('')}</div>
        <button class="solid" data-act="save-perms" data-id="${esc(emp.identifier)}">Save permissions</button></div>`).join('') || '<div class="empty">No employees yet.</div>'}`;
}

function viewRecipes() {
    const list = filtered().filter((item) => item.craftable);
    const slice = pageSlice(list);
    const recipe = state.recipe;
    const materials = (state.data.materialCatalog || []);
    const editor = recipe ? `<div class="panel stack"><h3>${esc(recipe.label || recipe.catalogId)}</h3>
        <label>Bench <select id="recipeBench">${Object.keys(state.data.models || {}).map((key) => `<option value="${esc(key)}" ${recipe.bench === key ? 'selected' : ''}>${esc(key)}</option>`).join('')}</select></label>
        <div class="form-grid"><label>Time <input id="recipeTime" type="number" value="${recipe.time || 30}" /></label>
        <label>XP <input id="recipeXp" type="number" value="${recipe.xp || 0}" /></label>
        <label>Difficulty <input id="recipeDiff" type="number" min="1" max="5" value="${recipe.difficulty || 1}" /></label>
        <label>Output <input id="recipeOutput" type="number" value="${recipe.output || 1}" /></label>
        <label>Unlock XP <input id="recipeUnlock" type="number" value="${recipe.unlockXp || 0}" /></label></div>
        <label><input id="recipeEnabled" type="checkbox" ${recipe.enabled ? 'checked' : ''}/> Enabled</label>
        <div id="recipeMats">${(recipe.materials || []).map((row, index) => `<div class="form-grid" data-mat="${index}"><select data-mat-item>${materials.map((mat) => `<option value="${esc(mat.item)}" ${mat.item === row.item ? 'selected' : ''}>${esc(mat.label)}</option>`).join('')}</select><input data-mat-count type="number" value="${row.count}" /></div>`).join('')}</div>
        <div class="actions"><button class="ghost" data-act="add-mat">Add material</button><button class="solid" data-act="save-recipe" data-id="${esc(recipe.catalogId)}">Save recipe</button><button class="danger" data-act="reset-recipe" data-id="${esc(recipe.catalogId)}">Reset</button></div></div>` : '<div class="empty">Select a weapon to edit its recipe.</div>';
    return `<div class="split"><div style="flex:1">${toolbar()}<div class="stack">${slice.rows.map((item) => `<button class="ghost" data-act="open-recipe" data-id="${esc(item.id)}">${esc(item.label)}</button>`).join('')}</div>${pager(slice.pages)}</div><div style="flex:1.2">${editor}</div></div>`;
}

function viewFinance() {
    const dash = state.data.dashboard || {};
    return `<div class="stat-grid"><div class="stat"><span class="muted">Balance</span><b>${money(state.data.store.balance)}</b></div><div class="stat"><span class="muted">Commission owed</span><b>${money(dash.commissionOwed || 0)}</b></div></div>
        <div class="form-grid">
        <label>Amount <input id="moneyAmt" type="number" min="1" value="1000" /></label>
        <label>Account <select id="moneyAccount"><option value="cash">Cash</option><option value="bank">Bank</option></select></label>
        ${can('deposit') ? '<button class="solid" data-act="deposit-money">Deposit</button>' : ''}
        ${can('withdraw') ? '<button class="danger" data-act="withdraw-money">Withdraw</button>' : ''}
        ${state.data.owner || state.data.admin ? '<button class="ghost" data-act="collect">Collect commission</button>' : ''}
        <button class="ghost" data-act="load-history" data-kind="transactions">Ledger</button></div><div id="historyBox"></div>`;
}

function viewHistory(kind) {
    const rows = state.history || [];
    const head = kind === 'sales'
        ? '<tr><th>Item</th><th>Buyer</th><th>Qty</th><th>Unit</th><th>Tax</th><th>Commission</th><th>Total</th><th>Pay</th></tr>'
        : '<tr><th>Item</th><th>Maker</th><th>Qty</th><th>Quality</th><th>Result</th><th>Output</th></tr>';
    const body = rows.map((row) => kind === 'sales'
        ? `<tr><td>${esc(row.label)}</td><td>${esc(row.buyer_name || '')}</td><td>${row.quantity}</td><td>${money(row.unit_price)}</td><td>${money(row.tax)}</td><td>${money(row.commission)}</td><td>${money(row.total)}</td><td>${esc(row.payment)}</td></tr>`
        : `<tr><td>${esc(row.label)}</td><td>${esc(row.name || '')}</td><td>${row.quantity}</td><td>${row.quality}</td><td>${row.success ? 'success' : 'failed'}</td><td>${esc(row.output_mode)}</td></tr>`).join('');
    return `<div class="toolbar"><input id="search" type="search" placeholder="Search" value="${esc(state.query)}" /><button class="solid" data-act="load-history" data-kind="${kind === 'mfg' ? 'manufacturing' : 'sales'}">Load</button></div><table><thead>${head}</thead><tbody>${body}</tbody></table>${pager(20)}`;
}

function viewSettings() {
    const settings = state.data.settings || {};
    const benches = state.data.benches || [];
    const models = state.data.modelList || [];
    const jobs = (settings.jobRestrictions || []).join(', ');
    return `<div class="split"><div class="panel stack" style="flex:1"><h3>Store</h3>
        ${can('settings') ? `<label>Label <input id="setLabel" value="${esc(settings.label || '')}" /></label>
        <label>Tax % <input id="setTax" type="number" value="${settings.taxPercent || 0}" /></label>
        <label>Commission % <input id="setCommission" type="number" value="${settings.commissionPercent || 0}" /></label>
        <label>Job restrictions <input id="setJobs" value="${esc(jobs)}" placeholder="police, sheriff" /></label>
        <label><input id="setDirect" type="checkbox" ${settings.directSales ? 'checked' : ''}/> Direct manufacturing sales</label>
        <label><input id="setLicense" type="checkbox" ${settings.licenseRequired ? 'checked' : ''}/> License required</label>
        <label><input id="setBlip" type="checkbox" ${settings.blip !== false ? 'checked' : ''}/> Blip enabled</label>
        <button class="solid" data-act="save-settings">Save settings</button>` : '<div class="muted">Settings permission required.</div>'}
        </div><div class="panel stack" style="flex:1"><h3>Benches</h3>
        ${can('benches') ? `<label>Label <input id="benchLabel" value="New bench" /></label>
        <label>Type <select id="benchType">${Object.keys(state.data.models || {}).map((key) => `<option value="${esc(key)}">${esc(key)}</option>`).join('')}</select></label>
        <label>Model <select id="benchModel">${models.map((model) => `<option value="${esc(model)}">${esc(model)}</option>`).join('')}</select></label>
        <label>Output <select id="benchOutput"><option value="stock">Business stock</option><option value="player">Player inventory</option></select></label>
        <label>Jobs <input id="benchJobs" placeholder="optional job names" /></label>
        <label>Min grade <input id="benchGrade" type="number" value="0" /></label>
        <label><input id="benchPublic" type="checkbox"/> Public player crafting</label>
        <label><input id="benchInvisible" type="checkbox"/> Invisible zone instead of a prop</label>
        <button class="solid" data-act="place-bench">Place bench</button>` : ''}
        ${benches.map((bench) => `<div class="panel"><strong>${esc(bench.label)}</strong><div class="muted">${esc(bench.benchType)} · ${esc(bench.output)} · ${bench.publicCraft ? 'public' : 'staff'}</div>
        <div class="actions"><button class="ghost" data-act="edit-bench" data-id="${bench.id}">Move</button><button class="danger" data-act="delete-bench" data-id="${bench.id}">Remove</button></div></div>`).join('')}
        </div></div>`;
}

function renderNav() {
    const nav = document.getElementById('nav');
    nav.innerHTML = NAV.filter((item) => item.show()).map((item) => `<button type="button" data-section="${item.id}" class="${item.id === state.section ? 'active' : ''}">${esc(item.label)}</button>`).join('');
    const titles = {};
    NAV.forEach((item) => { titles[item.id] = item.label; });
    document.getElementById('title').textContent = titles[state.section] || 'DJ Weapon Store';
    document.getElementById('kicker').textContent = (state.data && state.data.brand) || 'Diesel Dev Shack';
}

function renderHeader() {
    const select = document.getElementById('storeSelect');
    const stores = (state.data && state.data.stores) || [];
    select.innerHTML = stores.map((store) => `<option value="${esc(store.id)}" ${state.data.store && store.id === state.data.store.id ? 'selected' : ''}>${esc(store.label)}</option>`).join('');
    const balance = state.data && state.data.store && state.data.store.balance;
    document.getElementById('balance').textContent = balance == null ? '' : money(balance);
    const banner = document.getElementById('banner');
    if (state.data && state.data.database === false) banner.innerHTML = `<div class="banner">${esc(state.data.message || 'Database offline')}</div>`;
    else if (state.data && state.data.store && state.data.store.remote) banner.innerHTML = '<div class="banner">Remote admin view. Purchases and crafting still require you to be at the shop.</div>';
    else banner.innerHTML = '';
}

function render() {
    if (!state.data) return;
    if (!NAV.some((item) => item.id === state.section && item.show())) state.section = 'catalog';
    renderNav();
    renderHeader();
    const view = document.getElementById('view');
    if (state.section === 'catalog') view.innerHTML = viewCatalog('catalog');
    else if (state.section === 'manufacturing') view.innerHTML = viewCatalog('manufacturing');
    else if (state.section === 'bench') view.innerHTML = viewCatalog('bench');
    else if (state.section === 'materials') view.innerHTML = viewMaterials();
    else if (state.section === 'stock') view.innerHTML = viewStock();
    else if (state.section === 'dashboard') view.innerHTML = viewDashboard();
    else if (state.section === 'employees') view.innerHTML = viewEmployees();
    else if (state.section === 'recipes') view.innerHTML = viewRecipes();
    else if (state.section === 'finance') view.innerHTML = viewFinance();
    else if (state.section === 'sales') view.innerHTML = viewHistory('sales');
    else if (state.section === 'mfg') view.innerHTML = viewHistory('mfg');
    else if (state.section === 'settings') view.innerHTML = viewSettings();
}

function benchPayload() {
    return {
        storeId: state.data.store.id,
        label: document.getElementById('benchLabel').value,
        benchType: document.getElementById('benchType').value,
        model: document.getElementById('benchModel').value,
        output: document.getElementById('benchOutput').value,
        jobs: document.getElementById('benchJobs').value,
        minGrade: Number(document.getElementById('benchGrade').value || 0),
        publicCraft: document.getElementById('benchPublic').checked,
        invisible: document.getElementById('benchInvisible').checked,
    };
}

function recipePayload(id) {
    const materials = [];
    document.querySelectorAll('[data-mat]').forEach((row) => {
        materials.push({
            item: row.querySelector('[data-mat-item]').value,
            count: Number(row.querySelector('[data-mat-count]').value || 0),
        });
    });
    return {
        catalogId: id,
        bench: document.getElementById('recipeBench').value,
        time: Number(document.getElementById('recipeTime').value),
        xp: Number(document.getElementById('recipeXp').value),
        difficulty: Number(document.getElementById('recipeDiff').value),
        output: Number(document.getElementById('recipeOutput').value),
        unlockXp: Number(document.getElementById('recipeUnlock').value),
        enabled: document.getElementById('recipeEnabled').checked,
        materials,
    };
}

async function onClick(event) {
    const navButton = event.target.closest('[data-section]');
    if (navButton && event.currentTarget.id === 'nav') {
        state.section = navButton.dataset.section;
        state.page = 0;
        state.history = [];
        render();
        if (state.section === 'sales' || state.section === 'mfg') {
            const result = await run('getHistory', { kind: state.section === 'mfg' ? 'manufacturing' : 'sales', page: 0 }, false);
            if (result.ok) { state.history = result.rows || []; render(); }
        }
        return;
    }
    const button = event.target.closest('[data-act]');
    if (!button) return;
    const act = button.dataset.act;
    const id = button.dataset.id;
    if (act === 'page') {
        state.page += Number(button.dataset.dir || 0);
        if (state.section === 'sales' || state.section === 'mfg') {
            const result = await run('getHistory', { kind: state.section === 'mfg' ? 'manufacturing' : 'sales', page: state.page, query: state.query }, false);
            if (result.ok) state.history = result.rows || [];
        }
        render();
        return;
    }
    if (act === 'buy') {
        const account = document.getElementById('account');
        const qtyNode = document.getElementById('qty');
        await run('purchase', { catalogId: id, quantity: qtyNode ? Number(qtyNode.value || 1) : 1, account: account ? account.value : 'cash' }, true);
        return;
    }
    if (act === 'craft') {
        const qty = Number((document.getElementById('qty') || {}).value || 1);
        const pick = document.getElementById('benchPick');
        const benchId = state.section === 'bench' && state.data.bench ? state.data.bench.id : (pick ? Number(pick.value) : null);
        const result = await run('startCraft', { catalogId: id, quantity: qty, benchId }, false);
        if (result.ok && result.craft) {
            state.data.craft = result.craft;
            render();
        } else if (result.ok) await reload();
        return;
    }
    if (act === 'cancel-craft') {
        await run('cancelCraft', { token: button.dataset.token }, true);
        return;
    }
    if (act === 'deposit-mat' || act === 'withdraw-mat') {
        const row = button.closest('tr');
        const count = Number(row.querySelector('[data-qty]').value || 1);
        await run(act === 'deposit-mat' ? 'depositMaterial' : 'withdrawMaterial', { item: button.dataset.item, count }, true);
        return;
    }
    if (act === 'supply-buy') {
        await run('buySupply', {
            supplier: document.getElementById('supplier').value,
            item: document.getElementById('supplyItem').value,
            count: Number(document.getElementById('supplyQty').value || 1),
        }, true);
        return;
    }
    if (act === 'set-price') {
        const input = document.querySelector(`[data-price="${CSS.escape(id)}"]`);
        await run('setPrice', { catalogId: id, price: Number(input.value) }, true);
        return;
    }
    if (act === 'stock-add' || act === 'stock-remove') {
        await run('adjustStock', { catalogId: id, delta: act === 'stock-add' ? 1 : -1 }, true);
        return;
    }
    if (act === 'hire') {
        await run('hire', { target: Number(document.getElementById('hireId').value), grade: Number(document.getElementById('hireGrade').value) }, true);
        return;
    }
    if (act === 'fire') {
        await run('fire', { identifier: id }, true);
        return;
    }
    if (act === 'grade') {
        await run('setGrade', { identifier: id, grade: Number(button.dataset.grade), applyTemplate: button.dataset.template === '1' }, true);
        return;
    }
    if (act === 'save-perms') {
        const box = document.querySelector(`[data-perms="${CSS.escape(id)}"]`);
        const permissions = Array.from(box.querySelectorAll('input:checked')).map((input) => input.value);
        await run('setPermissions', { identifier: id, permissions }, true);
        return;
    }
    if (act === 'open-recipe') {
        const result = await run('getRecipe', { catalogId: id }, false);
        if (result.ok) { state.recipe = result.recipe; render(); }
        return;
    }
    if (act === 'add-mat') {
        state.recipe.materials = state.recipe.materials || [];
        const first = (state.data.materialCatalog || [])[0];
        state.recipe.materials.push({ item: first ? first.item : 'steel', count: 1 });
        render();
        return;
    }
    if (act === 'save-recipe') {
        const result = await run('saveRecipe', recipePayload(id), false);
        if (result.ok) { state.recipe = result.recipe || state.recipe; await reload(); }
        return;
    }
    if (act === 'reset-recipe') {
        const result = await run('resetRecipe', { catalogId: id }, false);
        if (result.ok) { state.recipe = result.recipe; await reload(); }
        return;
    }
    if (act === 'deposit-money' || act === 'withdraw-money') {
        await run(act === 'deposit-money' ? 'depositAccount' : 'withdrawAccount', {
            amount: Number(document.getElementById('moneyAmt').value),
            account: document.getElementById('moneyAccount').value,
        }, true);
        return;
    }
    if (act === 'collect') {
        await run('collectCommission', {}, true);
        return;
    }
    if (act === 'load-history') {
        const result = await run('getHistory', { kind: button.dataset.kind, page: state.page, query: state.query }, false);
        if (result.ok) {
            state.history = result.rows || [];
            const box = document.getElementById('historyBox');
            if (box) box.innerHTML = `<table>${state.history.map((row) => `<tr><td>${esc(row.item || row.kind || row.label || '')}</td><td>${esc(row.delta || row.amount || row.quantity || '')}</td><td>${esc(row.reason || row.created_at || '')}</td></tr>`).join('')}</table>`;
            else render();
        }
        return;
    }
    if (act === 'save-settings') {
        const jobs = document.getElementById('setJobs').value.split(',').map((part) => part.trim()).filter(Boolean);
        await run('saveSettings', {
            label: document.getElementById('setLabel').value,
            taxPercent: Number(document.getElementById('setTax').value),
            commissionPercent: Number(document.getElementById('setCommission').value),
            jobRestrictions: jobs,
            directSales: document.getElementById('setDirect').checked,
            licenseRequired: document.getElementById('setLicense').checked,
            blip: document.getElementById('setBlip').checked,
        }, true);
        return;
    }
    if (act === 'place-bench') {
        await rpc('placeBench', benchPayload());
        return;
    }
    if (act === 'edit-bench') {
        const bench = (state.data.benches || []).find((row) => String(row.id) === String(id));
        if (!bench) return;
        await rpc('editBench', Object.assign({}, bench, { storeId: bench.storeId, x: bench.coords.x, y: bench.coords.y, z: bench.coords.z }));
        return;
    }
    if (act === 'delete-bench') {
        await run('deleteBench', { id: Number(id) }, true);
    }
}

document.getElementById('nav').addEventListener('click', onClick);
document.getElementById('view').addEventListener('click', onClick);
document.getElementById('view').addEventListener('input', (event) => {
    if (event.target.id === 'search') {
        state.query = event.target.value;
        state.page = 0;
        if (state.section !== 'recipes') render();
    }
    if (event.target.id === 'category') {
        state.category = event.target.value;
        state.page = 0;
        render();
    }
});
document.getElementById('closeBtn').addEventListener('click', () => rpc('close'));
document.getElementById('refreshBtn').addEventListener('click', () => reload());
document.getElementById('storeSelect').addEventListener('change', async (event) => {
    setLoading(true);
    const next = await rpc('getState', { storeId: event.target.value, focus: state.section });
    setLoading(false);
    if (!next.ok) { toast(next.message || next.error, false); return; }
    state.data = next;
    state.page = 0;
    state.recipe = null;
    render();
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        rpc('close');
    }
});

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'open') {
        state.data = msg.data;
        state.section = (msg.data && msg.data.focus) || 'catalog';
        state.query = '';
        state.category = 'all';
        state.page = 0;
        state.recipe = null;
        state.history = [];
        if (msg.data && msg.data.serverNow) state.clockSkew = msg.data.serverNow - Math.floor(Date.now() / 1000);
        show();
        render();
    }
    if (msg.action === 'close') hide();
    if (msg.action === 'craft' && state.data) {
        state.data.craft = msg.data && msg.data.phase === 'running' ? msg.data : null;
        if (document.getElementById('craftBanner') || state.section === 'manufacturing' || state.section === 'bench') render();
        if (msg.data && msg.data.phase && msg.data.phase !== 'running') setTimeout(reload, 500);
    }
});

setInterval(() => {
    const node = document.getElementById('craftLeft');
    const craft = state.data && state.data.craft;
    if (!node || !craft || !craft.endsAt) return;
    const left = Math.max(0, craft.endsAt - (Math.floor(Date.now() / 1000) + state.clockSkew));
    node.textContent = `${left}s remaining`;
}, 500);
