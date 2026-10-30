-- DJ Weapon Store
-- Diesel Dev Shack
-- Safe to run more than once. The resource also runs this file on start when oxmysql is running.

CREATE TABLE IF NOT EXISTS dj_ws_stores (
    id VARCHAR(64) NOT NULL,
    label VARCHAR(120) NOT NULL,
    owner_identifier VARCHAR(80) NULL,
    balance INT NOT NULL DEFAULT 0,
    commission_owed INT NOT NULL DEFAULT 0,
    manufactured INT NOT NULL DEFAULT 0,
    sold INT NOT NULL DEFAULT 0,
    settings LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS dj_ws_employees (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    identifier VARCHAR(80) NOT NULL,
    name VARCHAR(120) NOT NULL,
    grade INT NOT NULL DEFAULT 0,
    hired_by VARCHAR(80) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_djws_employee (store_id, identifier),
    KEY idx_djws_employee_ident (identifier)
);

CREATE TABLE IF NOT EXISTS dj_ws_permissions (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    identifier VARCHAR(80) NOT NULL,
    permission VARCHAR(40) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_djws_permission (store_id, identifier, permission),
    KEY idx_djws_permission_store (store_id)
);

CREATE TABLE IF NOT EXISTS dj_ws_materials (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    item VARCHAR(64) NOT NULL,
    count INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_djws_material (store_id, item)
);

CREATE TABLE IF NOT EXISTS dj_ws_material_log (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    identifier VARCHAR(80) NULL,
    item VARCHAR(64) NOT NULL,
    delta INT NOT NULL,
    reason VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_djws_material_log (store_id, created_at)
);

CREATE TABLE IF NOT EXISTS dj_ws_stock (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    catalog_id VARCHAR(96) NOT NULL,
    count INT NOT NULL DEFAULT 0,
    price INT NULL,
    manufactured INT NOT NULL DEFAULT 0,
    sold INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_djws_stock (store_id, catalog_id),
    KEY idx_djws_stock_store (store_id)
);

CREATE TABLE IF NOT EXISTS dj_ws_recipes (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    catalog_id VARCHAR(96) NOT NULL,
    data LONGTEXT NOT NULL,
    enabled TINYINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(80) NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_djws_recipe (store_id, catalog_id)
);

CREATE TABLE IF NOT EXISTS dj_ws_benches (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    label VARCHAR(120) NOT NULL,
    bench_type VARCHAR(32) NOT NULL,
    model VARCHAR(80) NOT NULL,
    x DOUBLE NOT NULL,
    y DOUBLE NOT NULL,
    z DOUBLE NOT NULL,
    heading DOUBLE NOT NULL DEFAULT 0,
    z_offset DOUBLE NOT NULL DEFAULT 0,
    output_mode VARCHAR(16) NOT NULL DEFAULT 'stock',
    jobs VARCHAR(255) NULL,
    min_grade INT NOT NULL DEFAULT 0,
    invisible TINYINT NOT NULL DEFAULT 0,
    public_craft TINYINT NOT NULL DEFAULT 0,
    created_by VARCHAR(80) NULL,
    PRIMARY KEY (id),
    KEY idx_djws_bench_store (store_id)
);

CREATE TABLE IF NOT EXISTS dj_ws_sales (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    catalog_id VARCHAR(96) NOT NULL,
    buyer_identifier VARCHAR(80) NOT NULL,
    buyer_name VARCHAR(120) NULL,
    seller_identifier VARCHAR(80) NULL,
    quantity INT NOT NULL,
    unit_price INT NOT NULL,
    tax INT NOT NULL,
    commission INT NOT NULL,
    total INT NOT NULL,
    payment VARCHAR(16) NOT NULL,
    direct_sale TINYINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_djws_sales_store (store_id, created_at),
    KEY idx_djws_sales_catalog (catalog_id),
    KEY idx_djws_sales_buyer (buyer_identifier)
);

CREATE TABLE IF NOT EXISTS dj_ws_manufacturing (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    bench_id INT NULL,
    catalog_id VARCHAR(96) NOT NULL,
    identifier VARCHAR(80) NOT NULL,
    name VARCHAR(120) NULL,
    quantity INT NOT NULL,
    quality INT NOT NULL DEFAULT 0,
    duration INT NOT NULL DEFAULT 0,
    success TINYINT NOT NULL DEFAULT 0,
    output_mode VARCHAR(16) NOT NULL,
    materials LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_djws_mfg_store (store_id, created_at),
    KEY idx_djws_mfg_catalog (catalog_id)
);

CREATE TABLE IF NOT EXISTS dj_ws_transactions (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NOT NULL,
    identifier VARCHAR(80) NULL,
    kind VARCHAR(32) NOT NULL,
    amount INT NOT NULL,
    balance_after INT NOT NULL,
    reason VARCHAR(180) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_djws_tx_store (store_id, created_at)
);

CREATE TABLE IF NOT EXISTS dj_ws_audit (
    id INT NOT NULL AUTO_INCREMENT,
    store_id VARCHAR(64) NULL,
    identifier VARCHAR(80) NULL,
    action VARCHAR(64) NOT NULL,
    detail LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_djws_audit_store (store_id, created_at),
    KEY idx_djws_audit_action (action)
);

CREATE TABLE IF NOT EXISTS dj_ws_xp (
    identifier VARCHAR(80) NOT NULL,
    xp INT NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier)
);

CREATE TABLE IF NOT EXISTS dj_ws_wallets (
    identifier VARCHAR(80) NOT NULL,
    cash INT NOT NULL DEFAULT 0,
    bank INT NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier)
);

CREATE TABLE IF NOT EXISTS dj_ws_player_items (
    id INT NOT NULL AUTO_INCREMENT,
    identifier VARCHAR(80) NOT NULL,
    item VARCHAR(80) NOT NULL,
    count INT NOT NULL,
    metadata LONGTEXT NULL,
    PRIMARY KEY (id),
    KEY idx_djws_player_item (identifier, item)
);

CREATE TABLE IF NOT EXISTS dj_ws_active_crafts (
    token VARCHAR(64) NOT NULL,
    store_id VARCHAR(64) NOT NULL,
    bench_id INT NULL,
    identifier VARCHAR(80) NOT NULL,
    catalog_id VARCHAR(96) NOT NULL,
    quantity INT NOT NULL,
    materials LONGTEXT NOT NULL,
    output_mode VARCHAR(16) NOT NULL,
    quality INT NOT NULL DEFAULT 0,
    paid TINYINT NOT NULL DEFAULT 0,
    started_at INT NOT NULL,
    ends_at INT NOT NULL,
    status VARCHAR(16) NOT NULL,
    PRIMARY KEY (token),
    KEY idx_djws_active_ident (identifier),
    KEY idx_djws_active_status (status)
);
