/* Browser stand-in for the FiveM NUI bridge. No game client is contacted. */
(function () {
    window.GetParentResourceName = function () {
        return 'dj-weaponstore';
    };

    function bundle() {
        return window.DJWS_PREVIEW || { fixture: {}, history: {} };
    }

    function recipeFor(catalogId) {
        const data = bundle().fixture;
        const item = (data.catalog || []).find((row) => row.id === catalogId);
        if (!item) return null;
        const sets = data.recipeSets || {};
        return {
            catalogId: item.id,
            label: item.label,
            bench: item.bench,
            time: item.time,
            xp: item.xp,
            difficulty: item.difficulty,
            output: item.output || 1,
            unlockXp: item.unlockXp || 0,
            enabled: item.enabled !== false,
            materials: (sets[item.family] || sets.custom || []).map((row) => ({ item: row.item, count: row.count })),
        };
    }

    function stateFor(storeId) {
        const data = structuredClone(bundle().fixture);
        const stores = data.stores || [];
        const picked = stores.find((store) => store.id === storeId) || stores[0];
        if (picked) {
            data.store.id = picked.id;
            data.store.label = picked.label;
            if (data.settings) data.settings.label = picked.label;
        }
        data.ok = true;
        data.serverNow = Math.floor(Date.now() / 1000);
        return data;
    }

    window.fetch = function (_url, options) {
        let body = {};
        try {
            body = JSON.parse((options && options.body) || '{}');
        } catch (error) {
            body = {};
        }
        const action = body.action;
        const payload = body.payload || {};
        let result = { ok: true, message: 'Preview only. Nothing was saved.' };

        if (action === 'getState') {
            result = stateFor(payload.storeId);
        } else if (action === 'getHistory') {
            const rows = (bundle().history || {})[payload.kind] || [];
            result = { ok: true, rows: rows };
        } else if (action === 'getRecipe') {
            const recipe = recipeFor(payload.catalogId);
            result = recipe
                ? { ok: true, recipe: recipe }
                : { ok: false, error: 'unknown_weapon', message: 'That weapon is not in the preview catalog.' };
        } else if (action === 'close' || action === 'placeBench' || action === 'editBench') {
            result = { ok: true };
        }

        return Promise.resolve({
            ok: true,
            json: function () { return Promise.resolve(result); },
        });
    };
}());
