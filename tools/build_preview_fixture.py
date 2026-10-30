#!/usr/bin/env python3
"""Build preview/fixtures.js from the generated catalog. Does not rename item fields."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'preview' / 'fixtures.js'

PRICING = {
    'pistols': (7500, 3500, 22000, 35, 15, 2),
    'heavy_pistols': (14500, 7000, 42000, 50, 26, 2),
    'smgs': (18500, 9000, 52000, 60, 32, 3),
    'shotguns': (16000, 8000, 48000, 55, 30, 3),
    'rifles': (24000, 12000, 70000, 75, 40, 3),
    'assault_rifles': (27500, 14000, 80000, 80, 44, 4),
    'snipers': (42000, 22000, 120000, 110, 60, 4),
    'melee': (2500, 500, 12000, 20, 8, 1),
    'custom': (20000, 5000, 90000, 70, 36, 3),
    'attachments': (1500, 250, 8000, 15, 6, 1),
    'ammunition': (150, 25, 800, 8, 2, 1),
}

RECIPES = {
    'pistols': [('steel', 6), ('springs', 2), ('frames', 1), ('plastic', 2), ('gunpowder', 1)],
    'heavy_pistols': [('steel', 10), ('iron', 4), ('springs', 3), ('frames', 1), ('barrels', 1), ('gunpowder', 2)],
    'smgs': [('steel', 12), ('aluminum', 4), ('springs', 4), ('frames', 1), ('barrels', 1), ('parts', 3)],
    'shotguns': [('steel', 14), ('iron', 6), ('barrels', 2), ('frames', 1), ('parts', 2)],
    'rifles': [('steel', 16), ('aluminum', 6), ('barrels', 2), ('frames', 1), ('springs', 3), ('parts', 4)],
    'assault_rifles': [('steel', 18), ('aluminum', 8), ('barrels', 2), ('frames', 1), ('springs', 4), ('parts', 5), ('components', 2)],
    'snipers': [('steel', 22), ('aluminum', 6), ('barrels', 3), ('frames', 1), ('components', 4), ('parts', 4)],
    'melee': [('steel', 4), ('iron', 2), ('rubber', 1)],
    'custom': [('steel', 10), ('parts', 4), ('components', 2), ('frames', 1)],
    'attachments': [('steel', 2), ('aluminum', 1), ('springs', 1)],
    'ammunition': [('gunpowder', 2), ('copper', 1), ('parts', 1)],
}

FIELD = re.compile(r"(\w+)=('(?:\\'|[^'])*'|true|false|-?\d+(?:\.\d+)?)")


def parse_entries(path):
    rows = []
    for line in path.read_text(encoding='utf-8').splitlines():
        stripped = line.strip()
        if not stripped.startswith('{id='):
            continue
        entry = {}
        for key, raw in FIELD.findall(stripped):
            if raw == 'true':
                entry[key] = True
            elif raw == 'false':
                entry[key] = False
            elif raw.startswith("'"):
                entry[key] = raw[1:-1].replace("\\'", "'")
            elif '.' in raw:
                entry[key] = float(raw)
            else:
                entry[key] = int(raw)
        if 'id' in entry and 'item' in entry:
            rows.append(entry)
    return rows


def price_for(entry):
    family = entry.get('family') or entry.get('category') or 'custom'
    price, low, high, time, xp, difficulty = PRICING.get(family, PRICING['custom'])
    if entry.get('category') == 'variants':
        price = int(price * 1.15)
        low = int(low * 1.15)
        high = int(high * 1.15)
    return price, low, high, time, xp, difficulty


def materials_for(entry):
    family = entry.get('family') or entry.get('category') or 'custom'
    rows = RECIPES.get(family, RECIPES['custom'])
    return [{'item': item, 'count': count} for item, count in rows]


def project(entry, index):
    price, low, high, time, xp, difficulty = price_for(entry)
    stock = 0
    manufactured = 0
    sold = 0
    if entry.get('craftable') is not False and entry.get('purchasable') is not False:
        if index < 12 or index % 11 == 0:
            stock = 3 + (index % 9)
            manufactured = 8 + (index % 17)
            sold = max(0, manufactured - stock)
    row = {
        'id': entry['id'],
        'item': entry['item'],
        'label': entry.get('label') or entry['item'],
        'description': entry.get('description') or '',
        'category': entry.get('category') or 'custom',
        'family': entry.get('family') or entry.get('category') or 'custom',
        'kind': entry.get('kind') or 'weapon',
        'ammo': entry.get('ammo') or '',
        'bench': entry.get('bench') or 'general',
        'craftable': entry.get('craftable') is not False,
        'purchasable': entry.get('purchasable') is not False,
        'stock': stock,
        'price': price,
        'minPrice': low,
        'maxPrice': high,
        'time': time,
        'xp': xp,
        'difficulty': difficulty,
        'output': 30 if entry.get('kind') == 'ammo' else 1,
        'enabled': True,
        'unlockXp': 0,
        'weight': entry.get('weight') or 0,
    }
    if stock:
        row['manufactured'] = manufactured
        row['sold'] = sold
    if index < 3:
        row['priceOverride'] = price + 500
        row['price'] = row['priceOverride']
    return row


def main():
    sources = [
        ROOT / 'shared' / 'data' / 'weapons.lua',
        ROOT / 'shared' / 'data' / 'components.lua',
        ROOT / 'shared' / 'data' / 'ammo.lua',
    ]
    catalog = []
    for path in sources:
        for entry in parse_entries(path):
            if entry.get('craftable') is False:
                continue
            catalog.append(project(entry, len(catalog)))

    perms = [
        'dashboard', 'manufacture', 'recipes', 'materials', 'stock', 'prices',
        'hire', 'fire', 'permissions', 'withdraw', 'benches', 'reports', 'settings', 'deposit',
    ]
    fixture = {
        'ok': True,
        'database': True,
        'brand': 'Diesel Dev Shack',
        'resource': 'dj-weaponstore',
        'serverNow': 0,
        'store': {'id': 'sandy', 'label': 'Sandy Shores Armory', 'balance': 186450, 'remote': False},
        'stores': [
            {'id': 'sandy', 'label': 'Sandy Shores Armory'},
            {'id': 'city', 'label': 'Pillbox Gunworks'},
            {'id': 'hawick', 'label': 'Hawick Gunworks'},
        ],
        'mode': 'staff',
        'admin': False,
        'owner': True,
        'perms': {name: True for name in perms},
        'permissions': perms,
        'grades': {'0': 'Trainee', '1': 'Maker', '2': 'Armorer', '3': 'Manager'},
        'categories': [
            {'id': 'pistols', 'label': 'Pistols'},
            {'id': 'heavy_pistols', 'label': 'Heavy Pistols'},
            {'id': 'smgs', 'label': 'SMGs'},
            {'id': 'shotguns', 'label': 'Shotguns'},
            {'id': 'rifles', 'label': 'Rifles'},
            {'id': 'assault_rifles', 'label': 'Assault Rifles'},
            {'id': 'snipers', 'label': 'Snipers'},
            {'id': 'melee', 'label': 'Melee'},
            {'id': 'custom', 'label': 'Custom'},
            {'id': 'variants', 'label': 'Variants'},
            {'id': 'attachments', 'label': 'Attachments'},
            {'id': 'ammunition', 'label': 'Ammunition'},
        ],
        'catalog': catalog,
        'focus': 'catalog',
        'bench': {
            'id': 2,
            'label': 'Sandy Rifle Bench',
            'benchType': 'rifle',
            'output': 'stock',
            'publicCraft': False,
        },
        'publicCraft': False,
        'benches': [
            {'id': 1, 'label': 'Sandy Pistol Bench', 'benchType': 'pistol', 'output': 'stock', 'publicCraft': False, 'storeId': 'sandy', 'coords': {'x': 1694.2, 'y': 3756.8, 'z': 34.7}},
            {'id': 2, 'label': 'Sandy Rifle Bench', 'benchType': 'rifle', 'output': 'stock', 'publicCraft': False, 'storeId': 'sandy', 'coords': {'x': 1690.4, 'y': 3761.2, 'z': 34.7}},
            {'id': 3, 'label': 'Pillbox Assembly Bench', 'benchType': 'assembly', 'output': 'player', 'publicCraft': True, 'storeId': 'city', 'coords': {'x': 20.1, 'y': -1108.4, 'z': 29.8}},
            {'id': 4, 'label': 'Hawick General Bench', 'benchType': 'general', 'output': 'stock', 'publicCraft': False, 'storeId': 'hawick', 'coords': {'x': 252.2, 'y': -48.9, 'z': 69.9}},
        ],
        'craft': None,
        'payments': {'cash': True, 'bank': True, 'tax': 8, 'commission': 5, 'direct': False, 'license': False},
        'limits': {'craft': 5, 'purchase': 10, 'material': 500, 'transaction': 250000, 'stock': 250},
        'models': {'pistol': 'gr_prop_gr_bench_02a', 'rifle': 'gr_prop_gr_bench_01a', 'melee': 'prop_tool_bench02', 'assembly': 'gr_prop_gr_bench_04b', 'general': 'gr_prop_gr_bench_03a'},
        'modelList': ['gr_prop_gr_bench_01a', 'gr_prop_gr_bench_02a', 'gr_prop_gr_bench_03a', 'gr_prop_gr_bench_04b', 'prop_tool_bench02', 'prop_tool_bench02_ld'],
        'materials': [
            {'item': 'aluminum', 'label': 'Aluminum', 'category': 'metal', 'price': 34, 'count': 260},
            {'item': 'barrels', 'label': 'Barrels', 'category': 'mechanical', 'price': 120, 'count': 24},
            {'item': 'components', 'label': 'Components', 'category': 'mechanical', 'price': 75, 'count': 40},
            {'item': 'copper', 'label': 'Copper', 'category': 'metal', 'price': 30, 'count': 90},
            {'item': 'frames', 'label': 'Frames', 'category': 'mechanical', 'price': 140, 'count': 18},
            {'item': 'gunpowder', 'label': 'Gunpowder', 'category': 'chemical', 'price': 55, 'count': 55},
            {'item': 'iron', 'label': 'Iron', 'category': 'metal', 'price': 28, 'count': 180},
            {'item': 'parts', 'label': 'Parts', 'category': 'mechanical', 'price': 18, 'count': 200},
            {'item': 'plastic', 'label': 'Plastic', 'category': 'polymer', 'price': 12, 'count': 140},
            {'item': 'rubber', 'label': 'Rubber', 'category': 'polymer', 'price': 14, 'count': 70},
            {'item': 'springs', 'label': 'Springs', 'category': 'mechanical', 'price': 22, 'count': 110},
            {'item': 'steel', 'label': 'Steel', 'category': 'metal', 'price': 40, 'count': 420},
        ],
        'materialCapacity': 8000,
        'suppliers': [
            {'id': 'foundry', 'label': 'Foundry Contract', 'categories': ['metal', 'polymer']},
            {'id': 'machine', 'label': 'Machine Shop', 'categories': ['mechanical', 'chemical']},
        ],
        'materialCatalog': [
            {'item': 'aluminum', 'label': 'Aluminum'},
            {'item': 'barrels', 'label': 'Barrels'},
            {'item': 'components', 'label': 'Components'},
            {'item': 'copper', 'label': 'Copper'},
            {'item': 'frames', 'label': 'Frames'},
            {'item': 'gunpowder', 'label': 'Gunpowder'},
            {'item': 'iron', 'label': 'Iron'},
            {'item': 'parts', 'label': 'Parts'},
            {'item': 'plastic', 'label': 'Plastic'},
            {'item': 'rubber', 'label': 'Rubber'},
            {'item': 'springs', 'label': 'Springs'},
            {'item': 'steel', 'label': 'Steel'},
        ],
        'dashboard': {
            'balance': 186450,
            'stockCount': 148,
            'stockValue': 942800,
            'manufactured': 326,
            'sold': 178,
            'employees': 4,
            'salesToday': 11,
            'revenueToday': 86400,
            'commissionOwed': 4320,
            'transactions': [
                {'kind': 'sale', 'amount': 8625, 'reason': 'Chucky Glock'},
                {'kind': 'deposit', 'amount': 25000, 'reason': 'Owner deposit'},
                {'kind': 'supply', 'amount': -4800, 'reason': 'Foundry steel'},
                {'kind': 'withdraw', 'amount': -1500, 'reason': 'Bench parts'},
            ],
            'crafts': [
                {'label': 'Chucky Glock', 'quantity': 1, 'success': True},
                {'label': 'Halloween Scorpion', 'quantity': 1, 'success': True},
                {'label': 'Saw AK v1', 'quantity': 1, 'success': False},
            ],
        },
        'employees': [
            {
                'name': 'Mina Alvarez',
                'identifier': 'license:mina',
                'grade': 3,
                'gradeLabel': 'Manager',
                'online': True,
                'permissions': ['dashboard', 'manufacture', 'materials', 'stock', 'prices', 'recipes', 'reports', 'benches', 'deposit'],
            },
            {
                'name': 'Chris Dalton',
                'identifier': 'license:chris',
                'grade': 1,
                'gradeLabel': 'Maker',
                'online': True,
                'permissions': ['dashboard', 'manufacture', 'materials'],
            },
            {
                'name': 'Jules Park',
                'identifier': 'license:jules',
                'grade': 0,
                'gradeLabel': 'Trainee',
                'online': False,
                'permissions': ['dashboard', 'manufacture'],
            },
        ],
        'settings': {
            'label': 'Sandy Shores Armory',
            'taxPercent': 8,
            'commissionPercent': 5,
            'jobRestrictions': [],
            'directSales': False,
            'licenseRequired': False,
            'blip': True,
        },
        'recipeSets': {
            family: [{'item': item, 'count': count} for item, count in rows]
            for family, rows in RECIPES.items()
        },
    }

    featured = [row for row in catalog if row['stock'] > 0][:6]

    def sale(row, buyer, qty, payment):
        unit = row['price']
        tax = int(unit * qty * 0.08)
        commission = int(unit * qty * 0.05)
        return {
            'label': row['label'],
            'buyer_name': buyer,
            'quantity': qty,
            'unit_price': unit,
            'tax': tax,
            'commission': commission,
            'total': unit * qty + tax,
            'payment': payment,
        }

    sales = []
    buyers = [('Nia Cole', 'cash'), ('Andre Wells', 'bank'), ('Samir Shah', 'bank'), ('Lena Ortiz', 'cash')]
    for index, row in enumerate(featured[:4] or catalog[:4]):
        buyer, payment = buyers[index % len(buyers)]
        sales.append(sale(row, buyer, 1, payment))

    manufacturing = []
    for index, row in enumerate((featured[:4] or catalog[:4])):
        manufacturing.append({
            'label': row['label'],
            'name': 'Mina Alvarez' if index % 2 == 0 else 'Chris Dalton',
            'quantity': 1,
            'quality': 86 - index,
            'success': index != 2,
            'output_mode': 'stock',
        })

    history = {
        'sales': sales,
        'manufacturing': manufacturing,
        'transactions': [
            {'kind': 'sale', 'amount': 8625, 'reason': 'Register sale'},
            {'kind': 'deposit', 'amount': 25000, 'reason': 'Owner deposit'},
            {'kind': 'supply', 'amount': -4800, 'reason': 'Foundry steel'},
        ],
        'materials': [
            {'item': 'steel', 'delta': -18, 'reason': 'Craft Chucky Glock'},
            {'item': 'frames', 'delta': -1, 'reason': 'Craft Chucky Glock'},
            {'item': 'steel', 'delta': 100, 'reason': 'Foundry delivery'},
        ],
    }

    payload = json.dumps({'fixture': fixture, 'history': history}, separators=(',', ':'))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        '/* Generated by tools/build_preview_fixture.py. Item names match the ox_inventory catalog. */\n'
        'window.DJWS_PREVIEW = ' + payload + ';\n',
        encoding='utf-8',
    )
    print(f'Wrote {OUT} with {len(catalog)} catalog rows')


if __name__ == '__main__':
    main()
