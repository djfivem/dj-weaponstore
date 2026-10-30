# DJ Weapon Store

Weapon manufacturing, crafting benches, store stock, and business management for FiveM.

Developed by **Diesel Dev Shack**.

The resource runs from its own folder. Drop this repository in your server `resources` directory (the folder name is the resource name) and add `ensure dj-weaponstore` after your framework, inventory, target, and `oxmysql`.

It does not require an MLO. Sandy Shores, Pillbox, and Hawick use default map coordinates you can move.

## What is included

- 778 weapons, 96 attachments, and 29 ammo items from the ox_inventory source, each with a stable internal catalog id.
- Framework bridges: QBCore, Qbox, ESX Legacy, ESX, standalone, and a custom export bridge.
- Inventory bridges: ox_inventory, qb-inventory, ps-inventory, lj-inventory, qs-inventory, core_inventory, codem-inventory, tgiann-inventory, standalone, and custom.
- Target bridges: ox_target, qb-target, custom exports, and an E-key fallback.
- Server-side crafting, stock, sales, employees, recipes, benches, and audit logs.
- A custom NUI (charcoal, gunmetal, red accent) with twelve working sections.

Gameplay never hardcodes an inventory item name. The server resolves `ws_...` catalog ids through `shared/mappings.lua`.

## Dependencies

| Piece | Required | Notes |
| --- | --- | --- |
| Server build | yes | `fx_version 'cerulean'`, Lua 5.4 |
| oxmysql | yes for persistence | Not a hard manifest dependency. Without it the catalog UI opens and every mutation returns `database_unavailable`. |
| ox_inventory | recommended | Item names in `shared/data` are the ox_inventory names. Other inventories need those items created, or a mapping. |
| ox_lib | optional | Skill checks and ox_lib notifications. Crafting works with the skill check disabled. |
| ox_target or qb-target | optional | Without a target, press E near a register or bench. |

## Install

1. Import `sql/install.sql` into the server database, or start the resource with oxmysql running. On start the resource reads that file and runs each `CREATE TABLE IF NOT EXISTS`.
2. Set `Config.Framework`, `Config.Inventory`, `Config.Target`, and `Config.Notify` in `config.lua`. `auto` detects started resources and does not override a manual choice.
3. Give operators `add_ace group.admin dj_weaponstore.admin allow`. Restricted commands also need the `command` ace unless you set `Config.Admin.allowCommandAce = false`.
4. Assign a store owner: `djws_owner sandy <server id>`.
5. Fund the bench and materials: `djws_fund sandy 50000` and `djws_materials sandy steel 200`.
6. Stand at the shop and run `djws`, or use the target on the register.

Tables: stores, employees, permissions, materials, material log, stock, recipes, benches, sales, manufacturing history, transactions, audit, XP, standalone wallets, standalone items, and active crafts. Indexes are in `sql/install.sql`.

## Framework

`Config.Framework`: `auto`, `qbcore`, `qbox`, `esx_legacy`, `esx`, `standalone`, `custom`.

Auto order: `qbx_core`, then `qb-core`, then `es_extended` (treated as ESX Legacy). If `esx_legacy` exports throw, auto falls back to the old `esx:getSharedObject` event. A configured value is never rewritten.

Standard calls live in `bridges/framework_api.lua`: identifier, name, job, cash, bank, add/remove money, admin, license, notify. Money moves are serialized per player and only count as success when the provider returns `true`.

Standalone cash and bank are rows in `dj_ws_wallets`. They are not a real bank script.

Custom framework: set `Config.CustomFramework.resource` and the export names. Each export must return a real value. A thrown export is a failure.

## Inventory

`Config.Inventory`: `auto`, `ox_inventory`, `qb-inventory`, `ps-inventory`, `lj-inventory`, `qs-inventory`, `core_inventory`, `codem-inventory`, `tgiann-inventory`, `standalone`, `custom`.

Auto picks the first started resource in that order.

Add and remove succeed only when the export does not throw and returns a truthy value. `nil` and `false` are failures. If your inventory returns `nil` on a real success, set `Config.InventoryOptions.nilAddIsSuccess['resource-name'] = true` only after you have confirmed the item was created. Leaving it off prevents a second grant.

If a carry check export is missing, the grant is refused (`carry_check_unverified`) instead of assuming the inventory has room.

Metadata (serial, quality, durability, ammo name, attachment hashes) is written only when that bridge reports `metadata` support.

Item names:

- ox_inventory uses the `item` field in the catalog.
- Other inventories use the same name unless you set `DJWS.ItemMappings[inventoryName][catalogId]` in `shared/mappings.lua`.
- Materials resolve through `Config.Materials` and `DJWS.MaterialMappings`.

## Target and notifications

`Config.Target`: `auto`, `ox_target`, `qb-target`, `custom`, `fallback`.

Auto uses ox_target, then qb-target, then the E key. Fallback does not create target zones.

`Config.Notify`: `auto`, `ox_lib`, `qb`, `esx`, `custom`, `native`.

## Catalog

Generated files (do not rename `item` values):

- `shared/data/weapons.lua` — 778 weapons
- `shared/data/components.lua` — 96 attachments and their component hashes
- `shared/data/ammo.lua` — 29 ammo items

Internal ids look like `ws_weapon_pistol`. They are separate from the inventory name `WEAPON_PISTOL`.

| Category | Weapons |
| --- | ---: |
| Pistols | 295 |
| Variants | 118 |
| Assault rifles | 102 |
| Melee | 90 |
| Custom | 68 |
| SMGs | 43 |
| Shotguns | 34 |
| Heavy pistols | 16 |
| Snipers | 10 |
| Rifles | 2 |

Family is used for recipes, benches, and prices. A variant uses its family's recipe and time, and `Config.Pricing.variantMultiplier` (default 1.15) on the sell price only.

740 weapons are craftable and purchasable. 38 world and environmental damage types (drowning, animal attacks, and similar) stay in the catalog with `craftable = false` and `purchasable = false`. They are hidden unless `Config.Catalog.showUncraftable = true`. A forged purchase of one of them is rejected.

Nine ox keys differ only by case (`WEAPON_CHUCKYAKV1BYDAIE` and `WEAPON_chuckyakv1bydaie`). Both are kept. The second id ends in `_2`.

Attachments and ammunition are extra categories because the source file includes them. Duplicate ox component keys were merged: later scalar fields win, and component hash lists were unioned so hashes were not dropped.

Police-gated rows (`requiredJob = 'police'`) are `WEAPON_PD*` (not `WEAPON_PINK*`) and `pd-*` ammo.

Regenerate after you replace the source file:

```bash
python3 tools/generate_catalog.py --source path/to/weapons.lua --out shared/data
```

### Adding a weapon

Add a row to `Config.ExtraCatalog` in `config.lua`:

```lua
{
    id = 'ws_weapon_example',
    item = 'WEAPON_EXAMPLE',
    label = 'Example Carbine',
    category = 'custom',
    family = 'custom',
    kind = 'weapon',
    bench = 'assembly',
    craftable = true,
    purchasable = true,
    weight = 2500,
    description = 'Shop-added carbine.',
    ammo = 'ammo-rifle',
}
```

The `id` must be unique and match `ws_` plus letters, numbers, and underscores. Create the same item in your inventory. Map it in `shared/mappings.lua` if the inventory name differs from `item`.

### Recipes and materials

Default bills of materials are `Config.RecipeSets`, keyed by family. `Config.Materials` is the material list (steel, iron, aluminum, copper, plastic, rubber, gunpowder, components, springs, barrels, frames, parts). Those names are examples. Rename them to items your inventory already has, and set `DJWS.MaterialMappings` when the inventory item differs from the config key.

`Config.RecipeOverrides['ws_weapon_example']` replaces time, XP, difficulty, output, unlock XP, bench, enabled, or materials for one id.

Per-store edits in the Recipe Management screen are stored in `dj_ws_recipes` and win over the config. Reset clears that row.

Ammo recipes produce `Config.Ammo.batch` rounds (default 30) per craft quantity of 1.

## Benches

Types: `pistol`, `rifle`, `melee`, `assembly`, `general`.

Allowed models are listed in `Config.Benches.models`. Anything else is rejected. If the model is not in the game image, the preview falls back to `prop_tool_bench02`.

`Config.BenchCategories` decides which families each bench type can build. A pistol bench does not build rifles. `general` allows every family.

Default benches are inserted once, only when that store has zero benches. Later restarts do not duplicate them. Move or delete them in game; the database is the source after that.

Placement (owner, admin, or the `benches` permission):

- Settings → Place bench, or `/djws_place` near a store.
- The ghost prop follows the camera.
- Scroll rotates, arrow keys change height, Enter saves, Backspace cancels.
- The server checks permission, model allow-list, and distance, then writes `dj_ws_benches`.
- Clients spawn the prop inside `spawnDistance` and delete it outside `despawnDistance`. Invisible benches are target zones instead of props.
- `output = stock` sends the finished weapon to store stock and consumes business materials. Staff with `manufacture` are required.
- `output = player` gives the item to the crafter and consumes that player's materials. `publicCraft` is only stored when output is `player`.

Several players can craft at different benches. One bench is locked to one craft. One player cannot start a second craft.

## Permissions

Owners and admins have every permission. Employees do not.

`dashboard`, `manufacture`, `recipes`, `materials`, `stock`, `prices`, `hire`, `fire`, `permissions`, `withdraw`, `benches`, `reports`, `settings`, `deposit`.

Grade names are in `Config.Grades`. Hiring copies `Config.GradeTemplates`. Those templates never include `withdraw`, `fire`, `permissions`, or `settings`. Promote and demote change the grade number only. "Apply grade template" replaces that employee's permission rows. A manager cannot grant a permission they do not have.

Hire range is `Config.Business.hireDistance`. You cannot hire yourself, and you cannot fire or edit the owner.

## Prices and sales

Shelf price, minimum, and maximum come from `Config.Pricing[family]`, then `Config.PriceOverrides[catalogId]`, then a per-store price saved from Store Stock. The client never sends a price. Purchases use the server price.

Tax defaults to 8% and is added on top of the shelf price. `taxToBusiness = false` means tax is not credited to the shop. Commission defaults to 5% of the pre-tax price and is paid to the online owner's cash, or stored as `commission_owed` until the owner collects it.

Customers can buy only what is in stock. Direct manufacturing sales (consume business materials and mint the item) require both `Config.Payments.allowDirectManufacturingSales` and the store setting. Both default off. Direct quantity must be a multiple of the recipe output, so an ammo purchase uses the batch size.

Optional license check (`Config.Payments.license`) looks for an inventory item or a framework license. It fails closed. Job restrictions on the store settings, and `requiredJob` on a catalog row, are enforced on the server.

Cash and bank can be disabled separately. The business account is an internal balance in `dj_ws_stores`, not qb-banking or qb-management.

## MLO

`Config.MLO.enabled` defaults to false. Each store has an `mlo` key (`sandy`, `city`, `hawick`, `custom`) and coordinates. The `custom` store is disabled until you set its coords and `enabled = true`.

If you install an interior, set `Config.MLO.enabled = true` and put the IPL name on that interior. Empty IPL strings are ignored. The shop, benches, and targets still work on the default coordinates with no interior installed.

## Interface

`/djws` opens the nearest register, or the nearest bench when you are in reach of one. Escape or the close button releases NUI focus. The page is hidden until the server accepts `getState`.

Sections: Weapon Catalog, Weapon Manufacturing, Crafting Bench, Material Inventory, Store Stock, Business Dashboard, Employee Management, Recipe Management, Financial Management, Sales History, Manufacturing History, Settings.

Search and category filters run on the catalog the server already allowed that player to see. Customers see stocked items (and direct-sale items when that store setting is on). A public bench also lists what that bench type can craft. Staff see the full catalog except hidden environmental weapons.

Every button calls the `rpc` NUI callback. The client forwards it to the server except `close`, `placeBench`, and `editBench` (those start local placement; saving still hits `saveBench`).

## Security

- Catalog ids must match `^ws_[%w_]+$` and exist.
- Prices, materials, names, and permissions from the client are ignored.
- Purchases require the register distance. Crafting requires the bench distance. Remote admin management does not waive those checks, and it does not waive material deposit or withdraw.
- Store economy is locked per shop for the length of a transaction. Craft locks are per player and per bench.
- Rate limits are in `Config.Security.rateLimits`.
- Failed crafts grant nothing. Materials are removed only after the skill gate, inside the store lock. A failed roll refunds `failRefundPercent` (default 100). Cancel is refused in the last `cancelLockoutSeconds` (default 5) and refunds in full before that.
- Skill checks default off. With `trustClientSkillCheck = false`, a client report of success cannot skip the server roll. A client report of failure does fail the craft, and no materials are taken. Set `trustClientSkillCheck = true` only if you accept that a modified client can skip the roll.
- Discord logging uses `Config.Webhooks.url` (https only). A webhook failure does not roll back the sale. Toggle events under `Config.Webhooks.events`.

## Commands

| Command | Who | Effect |
| --- | --- | --- |
| `/djws` | anyone at a shop or bench | Open the UI |
| `/djws_place` | benches permission, owner, or admin, near a store | Start bench placement |
| `/djws_owner <storeId> <serverId>` | admin, restricted | Set the owner identifier |
| `/djws_fund <storeId> <amount>` | admin, restricted | Add or remove business balance |
| `/djws_materials <storeId> <item> <count>` | admin, restricted | Add or remove business materials |

Store ids shipped enabled: `sandy`, `city`, `hawick`.

## Example: Qbox + ox_inventory + ox_target

```lua
Config.Framework = 'qbox'
Config.Inventory = 'ox_inventory'
Config.Target = 'ox_target'
Config.Notify = 'ox_lib'
```

Leave the mappings empty. Item names already match ox_inventory.

## Example: QBCore + qb-inventory

```lua
Config.Framework = 'qbcore'
Config.Inventory = 'qb-inventory'
Config.Target = 'qb-target'
Config.Notify = 'qb'
```

Create every catalog `item` in `qb-core/shared/items.lua` (or map each catalog id in `DJWS.ItemMappings['qb-inventory']`). Weapons that are not items in that inventory cannot be granted. The bridge uses `CanAddItem`, `AddItem`, `RemoveItem`, and `GetItemByName`, and falls back to `Player.Functions` only when the export throws.

## Example: one custom weapon and a harder recipe

```lua
Config.PriceOverrides['ws_weapon_example'] = { price = 32000, min = 20000, max = 60000 }

Config.RecipeOverrides['ws_weapon_example'] = {
    time = 90,
    xp = 50,
    difficulty = 4,
    unlockXp = 100,
    materials = {
        { item = 'steel', count = 20 },
        { item = 'barrels', count = 2 },
        { item = 'frames', count = 1 },
        { item = 'components', count = 3 },
    },
}
```

## Troubleshooting

- **Catalog only, red database banner.** oxmysql is stopped or the connection string is wrong. Start oxmysql first. Confirm the tables exist.
- **Craft says inventory full.** The carry export returned false, or it is missing. Missing carry checks are refused on purpose.
- **Item never appears but materials were refunded.** The add export returned nil/false or threw. Check the server console for the inventory name. Do not flip `nilAddIsSuccess` until you have seen a real item created with a nil return.
- **Wrong item name in qb/qs/ps.** Add a mapping. The ox name is only the default.
- **Cannot buy.** The weapon is out of stock, you are not at the register, a license or job check failed, or the quantity is not a multiple of the ammo batch during a direct sale.
- **Bench prop missing.** You are outside spawn distance, the bench is marked invisible, or the model was rejected and the fallback also failed to stream. Restart the resource after a database change if clients were connected before `dj_ws:benches` was broadcast; new joins request the list.
- **Skill check does nothing.** `Config.Crafting.skillCheck.enabled` is false, or ox_lib is not started. A missing export does not count as a pass; the server roll still runs.
- **Employee cannot withdraw.** Grade templates do not include withdraw. Grant it from Employee Management.

## Limitations

These were not executed inside FXServer or against a live inventory. Export names are the commonly documented ones.

- ox_inventory: `CanCarryItem`, `AddItem`, `RemoveItem`, `GetItemCount`.
- qb-inventory: `CanAddItem`, `AddItem`, `RemoveItem`, `GetItemByName`, plus the QBCore player functions when the export throws.
- qbox money: `AddMoney` / `RemoveMoney` must return `true`. A nil return is treated as failure.
- ps-inventory, lj-inventory, qs-inventory, codem-inventory, and tgiann-inventory use the same export names those resources document publicly. They were not live-tested. A thrown or nil export fails the action.
- core_inventory ids vary by version. `Config.InventoryOptions.core_inventory.idMode` is `source`, `identifier`, `content`, or `primary`. The bridge tries one id only, so a wrong mode cannot double-grant. `canCarry` must exist or the grant is blocked.
- ESX licenses read `user_licenses` (`owner`, `type`). If that table is absent, the check fails closed.
- The business account is internal. It does not sync to qb-banking, qb-management, or Renewed-Banking.
- Standalone inventory is a weight-and-slot table (`dj_ws_player_items`). It is enough to buy and craft without another inventory. It is not a player-facing inventory UI.
- Images use `nui://ox_inventory/web/images/%s.png`. No images are shipped. Point `Config.Images.template` at your image pack.
- A restart refunds in-progress crafts from `dj_ws_active_crafts`. Stock-output refunds go back to the business. Player-output refunds need the player online; if they are offline the refund is an audit row (`refund_pending`) and a webhook, not a silent item grant.
- `trustClientSkillCheck = true` lets a modified client skip the success roll.
- Tax does not go to a government account unless `taxToBusiness` is on, in which case it goes to the shop.
- This environment did not boot FiveM, so proximity, props, NUI focus, and inventory grants were reviewed from the Lua and the NUI wiring, not from an in-game session.

## Layout

```
fxmanifest.lua
config.lua
locales/en.lua
sql/install.sql
shared/          catalog, recipes, pricing, mappings, locations
shared/data/     generated weapons, attachments, ammo
bridges/         framework, inventory, target, notifications, callbacks
client/          NUI, props, placement, interaction
server/          database, security, business, crafting, sales
web/             html, css, js
tools/generate_catalog.py
```
