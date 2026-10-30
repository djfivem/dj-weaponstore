/* Opens the real NUI against the preview fixture. */
(function () {
    const params = new URLSearchParams(window.location.search);
    const section = params.get('section') || 'catalog';
    const clean = params.get('clean') === '1';
    if (clean) document.documentElement.dataset.clean = '1';
    document.documentElement.dataset.shot = section;

    const SECTIONS = [
        ['catalog', 'Catalog'],
        ['manufacturing', 'Manufacturing'],
        ['bench', 'Bench'],
        ['materials', 'Materials'],
        ['stock', 'Stock'],
        ['dashboard', 'Dashboard'],
        ['employees', 'Employees'],
        ['recipes', 'Recipes'],
        ['finance', 'Finance'],
        ['sales', 'Sales'],
        ['mfg', 'Manufacturing log'],
        ['settings', 'Settings'],
    ];

    const bar = document.getElementById('preview-nav');
    if (bar) {
        bar.innerHTML = SECTIONS.map(([id, label]) => {
            const href = '?section=' + encodeURIComponent(id);
            const current = id === section ? ' aria-current="page"' : '';
            return `<a href="${href}"${current}>${label}</a>`;
        }).join('');
    }

    function sourceState() {
        const packed = window.DJWS_PREVIEW || {};
        const data = structuredClone(packed.fixture || {});
        data.serverNow = Math.floor(Date.now() / 1000);
        data.recipeSets = packed.recipeSets || data.recipeSets;
        if (section === 'manufacturing' || section === 'bench' || section === 'materials') {
            const sample = (data.catalog || []).find((row) => row.craftable);
            data.craft = {
                label: sample ? sample.label : 'Weapon',
                phase: 'running',
                token: 'preview-craft',
                endsAt: data.serverNow + 42,
            };
        }
        data.focus = section === 'loading' || section === 'toast' ? 'catalog' : section;
        return data;
    }

    function markReady() {
        document.documentElement.dataset.ready = '1';
    }

    function waitFor(check) {
        return new Promise((resolve) => {
            const started = Date.now();
            const tick = () => {
                if (check() || Date.now() - started > 2000) resolve();
                else setTimeout(tick, 20);
            };
            tick();
        });
    }

    window.addEventListener('DOMContentLoaded', () => {
        const data = sourceState();
        window.addEventListener('message', function onOpen(event) {
            if (!event.data || event.data.action !== 'open') return;
            window.removeEventListener('message', onOpen);
            setTimeout(() => {
                const target = data.focus;
                let pending = Promise.resolve();
                if (target === 'sales' || target === 'mfg') {
                    const button = document.querySelector(`#nav [data-section="${target}"]`);
                    if (button) button.click();
                    pending = waitFor(() => document.querySelector('#view tbody tr'));
                } else if (target === 'recipes') {
                    const button = document.querySelector('[data-act="open-recipe"]');
                    if (button) button.click();
                    pending = waitFor(() => document.getElementById('recipeBench'));
                }
                pending.then(() => {
                    if (section === 'loading') {
                        document.getElementById('loading').classList.remove('hidden');
                    }
                    if (section === 'toast') {
                        const node = document.getElementById('toast');
                        node.textContent = 'Chucky Glock added to Sandy Shores stock.';
                        node.className = 'ok';
                    }
                    markReady();
                });
            }, 0);
        });
        window.postMessage({ action: 'open', data: data }, '*');
    });
}());
