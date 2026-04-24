-- =====================================================================
-- Yakinimda En Ucuz — Initial Schema
-- =====================================================================
-- Target: Supabase (Postgres 15+)
-- Apply order: run once on a fresh project.
-- Extensions: pg_trgm (fuzzy search), earthdistance/cube (branch proximity).
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------------------
-- markets: zincir market sözlüğü
-- ---------------------------------------------------------------------
CREATE TABLE markets (
  id TEXT PRIMARY KEY,                     -- 'bim', 'a101', 'sok', ...
  display_name TEXT NOT NULL,              -- 'BİM', 'A101'
  tier SMALLINT NOT NULL DEFAULT 3,        -- 1=ulusal, 2=orta, 3=bölgesel, 4=online/q-commerce
  website TEXT,
  logo_url TEXT,
  campaign_schedule JSONB,                 -- {"weekly_release":"wednesday_10_00","source":"aktuel_sayfa"}
  coverage_regions TEXT[],                 -- ISO 3166-2 (['TR-34','TR-06'])
  is_active BOOLEAN NOT NULL DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- market_branches: şubeler (marketfiyati depotId bazlı + kendi scrape)
-- ---------------------------------------------------------------------
CREATE TABLE market_branches (
  id BIGSERIAL PRIMARY KEY,
  market_id TEXT NOT NULL REFERENCES markets(id) ON DELETE CASCADE,
  external_id TEXT,                        -- kaynak tarafı ID (marketfiyati: depotId)
  name TEXT NOT NULL,
  city TEXT,
  district TEXT,
  neighborhood TEXT,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  region_id TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (market_id, external_id)
);

CREATE INDEX idx_branches_market ON market_branches(market_id);
CREATE INDEX idx_branches_city ON market_branches(city) WHERE is_active;
-- Konum sorgusu (yakınımdaki şubeler):
CREATE INDEX idx_branches_geo
  ON market_branches USING gist (ll_to_earth(latitude, longitude))
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- ---------------------------------------------------------------------
-- categories: ürün kategori ağacı (süt, ekmek, bebek bezi...)
-- ---------------------------------------------------------------------
CREATE TABLE categories (
  id TEXT PRIMARY KEY,                     -- slug: 'sut', 'camasir-deterjan'
  parent_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
  name_tr TEXT NOT NULL,
  name_en TEXT,
  path TEXT NOT NULL,                      -- 'gida/kahvaltilik/sut-urunleri/sut'
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_path ON categories(path text_pattern_ops);

-- ---------------------------------------------------------------------
-- products: canonical ürün kataloğu
-- Bir gerçek ürün = bir satır. (Sütaş Tam Yağlı Süt 1L tek satır, markete göre değişmez)
-- Farklı market/şubelerde bulunan fiyatlar `prices` tablosunda.
-- ---------------------------------------------------------------------
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_name TEXT NOT NULL,            -- 'Sütaş Tam Yağlı Süt 1L'
  brand TEXT,
  category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
  package_size NUMERIC,                    -- 1, 500, 250
  package_unit TEXT,                       -- 'L', 'ml', 'kg', 'g', 'adet', 'paket'
  package_count INTEGER DEFAULT 1,         -- "4'lü paket" gibi durumlar için
  barcode TEXT UNIQUE,                     -- EAN-13, nadir ama altın değerinde
  image_url TEXT,
  search_text TEXT,                        -- FTS için normalize edilmiş metin
  is_verified BOOLEAN NOT NULL DEFAULT false,  -- elle veya crowdsource onaylı
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_products_brand ON products(brand);
CREATE INDEX idx_products_category ON products(category_id);
-- Türkçe tam metin arama:
CREATE INDEX idx_products_fts
  ON products USING gin (to_tsvector('turkish', coalesce(search_text, canonical_name)));
-- Fuzzy matching (yazım hataları, farklı varyasyonlar):
CREATE INDEX idx_products_trgm
  ON products USING gin (canonical_name gin_trgm_ops);

-- ---------------------------------------------------------------------
-- product_aliases: aynı ürünü farklı isimlerle tanıma
-- BİM "Sütaş Süt 1LT", A101 "SÜTAŞ TAM YAĞLI 1L" → aynı products.id'ye bağlanır.
-- ---------------------------------------------------------------------
CREATE TABLE product_aliases (
  id BIGSERIAL PRIMARY KEY,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  alias TEXT NOT NULL,                     -- görüldüğü ham isim
  source TEXT,                             -- 'bim', 'a101', 'marketfiyati', 'crowdsource'
  confidence NUMERIC NOT NULL DEFAULT 1.0, -- 0..1
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (alias, source)
);

CREATE INDEX idx_aliases_product ON product_aliases(product_id);
CREATE INDEX idx_aliases_trgm ON product_aliases USING gin (alias gin_trgm_ops);

-- ---------------------------------------------------------------------
-- prices: fiyat gözlemleri (time series)
-- Her scrape bu tabloya yazar. product_id henüz eşlenmemişse NULL.
-- ---------------------------------------------------------------------
CREATE TABLE prices (
  id BIGSERIAL PRIMARY KEY,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,  -- match yoksa NULL
  market_id TEXT NOT NULL REFERENCES markets(id),
  branch_id BIGINT REFERENCES market_branches(id) ON DELETE SET NULL,
  region_id TEXT,
  price NUMERIC NOT NULL CHECK (price >= 0),
  unit_price NUMERIC,                      -- TL/kg, TL/L
  unit_price_label TEXT,                   -- '14,50 TL/Lt' gibi ham metin
  currency TEXT NOT NULL DEFAULT 'TRY',
  observed_at TIMESTAMPTZ NOT NULL,
  source TEXT NOT NULL,                    -- 'marketfiyati','bim_official_brochure','a101_aldin_aldin'
  source_url TEXT,
  raw_product_name TEXT,                   -- match yoksa ham isim burada
  raw_brand TEXT,
  raw_payload JSONB,
  is_on_sale BOOLEAN NOT NULL DEFAULT false,
  scrape_run_id BIGINT,                    -- FK aşağıda (scrape_runs yaratıldıktan sonra)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fiyat geçmişi sorgusu:
CREATE INDEX idx_prices_product_time
  ON prices(product_id, observed_at DESC) WHERE product_id IS NOT NULL;
-- Market bazlı timeline:
CREATE INDEX idx_prices_market_time ON prices(market_id, observed_at DESC);
-- Şube bazlı:
CREATE INDEX idx_prices_branch_time
  ON prices(branch_id, observed_at DESC) WHERE branch_id IS NOT NULL;
-- Henüz canonical'a bağlanmamış gözlemler (match kuyruğu):
CREATE INDEX idx_prices_unmatched
  ON prices(market_id, observed_at DESC) WHERE product_id IS NULL;

-- ---------------------------------------------------------------------
-- campaigns: aktüeller, fırsatlar, tarih kısıtlı indirimler
-- ---------------------------------------------------------------------
CREATE TABLE campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  raw_product_name TEXT NOT NULL,
  brand TEXT,
  category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
  discount_price NUMERIC NOT NULL CHECK (discount_price >= 0),
  regular_price NUMERIC CHECK (regular_price IS NULL OR regular_price >= 0),
  discount_ratio NUMERIC GENERATED ALWAYS AS (
    CASE
      WHEN regular_price IS NOT NULL AND regular_price > 0
        THEN (regular_price - discount_price) / regular_price
      ELSE NULL
    END
  ) STORED,
  valid_from DATE NOT NULL,
  valid_until DATE NOT NULL,
  source_url TEXT,
  brochure_image_url TEXT,
  ocr_text TEXT,
  confidence NUMERIC NOT NULL DEFAULT 1.0 CHECK (confidence BETWEEN 0 AND 1),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','expired','review','rejected')),
  detected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  raw_payload JSONB,
  CHECK (valid_until >= valid_from)
);

-- Aktif kampanyalar (sık sorgu):
CREATE INDEX idx_campaigns_active
  ON campaigns(market_id, valid_from, valid_until)
  WHERE status = 'active';
CREATE INDEX idx_campaigns_product
  ON campaigns(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX idx_campaigns_category_valid
  ON campaigns(category_id, valid_until) WHERE status = 'active';
-- Bildirim motoru için "yeni girmişler":
CREATE INDEX idx_campaigns_detected ON campaigns(detected_at DESC);

-- ---------------------------------------------------------------------
-- scrape_runs: worker çalıştırma kayıtları (gözlem ve debug için)
-- ---------------------------------------------------------------------
CREATE TABLE scrape_runs (
  id BIGSERIAL PRIMARY KEY,
  market_id TEXT NOT NULL REFERENCES markets(id),
  source_type TEXT NOT NULL,               -- 'brochure','api','ocr','crowdsource'
  source_label TEXT,                       -- 'bim_official_brochure' gibi
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ,
  products_added INTEGER NOT NULL DEFAULT 0,
  prices_added INTEGER NOT NULL DEFAULT 0,
  campaigns_added INTEGER NOT NULL DEFAULT 0,
  products_matched INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'running'
    CHECK (status IN ('running','success','partial','failed')),
  error_message TEXT,
  worker_version TEXT
);

CREATE INDEX idx_runs_market_time ON scrape_runs(market_id, started_at DESC);
CREATE INDEX idx_runs_status ON scrape_runs(status, started_at DESC);

-- prices.scrape_run_id ↔ scrape_runs FK (geriye dönük tanımlama):
ALTER TABLE prices
  ADD CONSTRAINT fk_prices_scrape_run
  FOREIGN KEY (scrape_run_id) REFERENCES scrape_runs(id) ON DELETE SET NULL;
CREATE INDEX idx_prices_scrape_run ON prices(scrape_run_id) WHERE scrape_run_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- user_profiles: auth.users uzantısı (Supabase Auth'a bağlı)
-- ---------------------------------------------------------------------
CREATE TABLE user_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT,
  display_name TEXT,
  preferred_city TEXT,
  preferred_district TEXT,
  preferred_latitude DOUBLE PRECISION,
  preferred_longitude DOUBLE PRECISION,
  preferred_markets TEXT[] DEFAULT '{}',   -- ['bim','a101','migros']
  preferred_categories TEXT[] DEFAULT '{}',
  notification_enabled BOOLEAN NOT NULL DEFAULT true,
  notification_quiet_hours JSONB,          -- {"start":"23:00","end":"08:00"}
  notification_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- user_watches: kullanıcının takip ettiği ürünler (price alerts)
-- ---------------------------------------------------------------------
CREATE TABLE user_watches (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  market_id TEXT REFERENCES markets(id),   -- NULL = herhangi bir market
  target_price NUMERIC,                    -- NULL = herhangi bir düşüş
  original_price NUMERIC,
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_notified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, product_id, market_id)
);

CREATE INDEX idx_watches_active_product ON user_watches(product_id) WHERE is_active;
CREATE INDEX idx_watches_user ON user_watches(user_id) WHERE is_active;

-- ---------------------------------------------------------------------
-- notifications: gönderilen push kayıtları (idempotency + audit)
-- ---------------------------------------------------------------------
CREATE TABLE notifications (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL
    CHECK (type IN ('watch_triggered','campaign_match','price_drop','weekly_digest')),
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
  market_id TEXT REFERENCES markets(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  payload JSONB,
  dedupe_key TEXT,                         -- "user+type+product+campaign" idempotency anahtarı
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivery_status TEXT NOT NULL DEFAULT 'sent'
    CHECK (delivery_status IN ('sent','failed','clicked','dismissed')),
  clicked_at TIMESTAMPTZ,
  UNIQUE (user_id, dedupe_key)
);

CREATE INDEX idx_notifications_user_time ON notifications(user_id, sent_at DESC);
CREATE INDEX idx_notifications_type ON notifications(type, sent_at DESC);

-- ---------------------------------------------------------------------
-- receipt_submissions: crowdsource fiş katkıları (Faz 2-3)
-- ---------------------------------------------------------------------
CREATE TABLE receipt_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  market_id TEXT REFERENCES markets(id),
  branch_id BIGINT REFERENCES market_branches(id) ON DELETE SET NULL,
  image_url TEXT,
  ocr_text TEXT,
  parsed_items JSONB,                      -- [{name, price, qty}, ...]
  total_amount NUMERIC,
  receipt_date DATE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','duplicate')),
  review_notes TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_receipts_status ON receipt_submissions(status, submitted_at DESC);
CREATE INDEX idx_receipts_user ON receipt_submissions(user_id, submitted_at DESC);

-- ---------------------------------------------------------------------
-- updated_at otomatik tetikleyici
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_markets_updated
  BEFORE UPDATE ON markets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_products_updated
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_profiles_updated
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
