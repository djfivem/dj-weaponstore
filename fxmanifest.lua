fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dj-weaponstore'
author 'Diesel Dev Shack'
description 'DJ Weapon Store — weapon manufacturing, crafting benches, stock, and business management'
version '1.0.0'

-- oxmysql is required for persistence (sales, stock, benches, employees).
-- It is intentionally not a hard dependency: if it is stopped, the resource
-- still boots and the catalog UI opens in a read-only degraded state.
-- Install oxmysql and import sql/install.sql (tables are also created on start).
-- dependency 'oxmysql'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/style.css',
    'web/js/app.js',
    'sql/install.sql',
    'locales/en.lua',
}

shared_scripts {
    'config.lua',
    'shared/locations.lua',
    'locales/en.lua',
    'shared/events.lua',
    'shared/utils.lua',
    'shared/result.lua',
    'shared/permissions.lua',
    'shared/pricing.lua',
    'shared/recipes.lua',
    'shared/data/weapons.lua',
    'shared/data/components.lua',
    'shared/data/ammo.lua',
    'shared/catalog.lua',
    'shared/mappings.lua',
}

client_scripts {
    'bridges/loader.lua',
    'bridges/callback.lua',
    'bridges/framework/qbcore.lua',
    'bridges/framework/qbox.lua',
    'bridges/framework/esx.lua',
    'bridges/framework/esx_legacy.lua',
    'bridges/framework/standalone.lua',
    'bridges/framework/custom.lua',
    'bridges/framework_api.lua',
    'bridges/notifications/ox.lua',
    'bridges/notifications/qb.lua',
    'bridges/notifications/esx.lua',
    'bridges/notifications/custom.lua',
    'bridges/notifications/native.lua',
    'bridges/notify_api.lua',
    'bridges/target/ox.lua',
    'bridges/target/qb.lua',
    'bridges/target/custom.lua',
    'bridges/target/fallback.lua',
    'bridges/target_api.lua',
    'client/state.lua',
    'client/nui.lua',
    'client/craft.lua',
    'client/benches.lua',
    'client/placement.lua',
    'client/interact.lua',
    'client/main.lua',
}

server_scripts {
    'bridges/loader.lua',
    'bridges/callback.lua',
    'bridges/framework/qbcore.lua',
    'bridges/framework/qbox.lua',
    'bridges/framework/esx.lua',
    'bridges/framework/esx_legacy.lua',
    'bridges/framework/standalone.lua',
    'bridges/framework/custom.lua',
    'bridges/framework_api.lua',
    'bridges/inventory/build.lua',
    'bridges/inventory/ox.lua',
    'bridges/inventory/qb.lua',
    'bridges/inventory/ps.lua',
    'bridges/inventory/lj.lua',
    'bridges/inventory/qs.lua',
    'bridges/inventory/core.lua',
    'bridges/inventory/codem.lua',
    'bridges/inventory/tgiann.lua',
    'bridges/inventory/standalone.lua',
    'bridges/inventory/custom.lua',
    'bridges/inventory_api.lua',
    'bridges/notifications/ox.lua',
    'bridges/notifications/qb.lua',
    'bridges/notifications/esx.lua',
    'bridges/notifications/custom.lua',
    'bridges/notifications/native.lua',
    'bridges/notify_api.lua',
    'server/db.lua',
    'server/logs.lua',
    'server/security.lua',
    'server/business.lua',
    'server/employees.lua',
    'server/materials.lua',
    'server/stock.lua',
    'server/recipes.lua',
    'server/benches.lua',
    'server/crafting.lua',
    'server/sales.lua',
    'server/rpc.lua',
    'server/main.lua',
}
