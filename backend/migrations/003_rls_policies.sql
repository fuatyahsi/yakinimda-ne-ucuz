-- =====================================================================
-- 003_rls_policies.sql — Row Level Security
-- =====================================================================
-- Prensipler:
--   * Public okuma: markets, market_branches, categories, products,
--     product_aliases, prices, campaigns, latest_prices.
--     (App anon key ile bunları okuyabilmeli.)
--
--   * Kullanıcıya özel: user_profiles, user_watches, notifications,
--     receipt_submissions. Her kullanıcı SADECE kendi satırlarını
--     okur/yazar. Auth zorunlu.
--
--   * Worker/Edge Function: service_role_key ile bağlanır ve RLS'i
--     bypass eder (Supabase'in default davranışı). Politika yazmamıza
--     gerek yok.
--
--   * scrape_runs sadece service_role tarafından yazılır, herkes okuyabilir
--     (admin panel için).
-- =====================================================================

-- --- public okuma tabloları ---
ALTER TABLE markets           ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_branches   ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_aliases   ENABLE ROW LEVEL SECURITY;
ALTER TABLE prices            ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaigns         ENABLE ROW LEVEL SECURITY;
ALTER TABLE scrape_runs       ENABLE ROW LEVEL SECURITY;

-- --- kullanıcıya özel tablolar ---
ALTER TABLE user_profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_watches          ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications         ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_submissions   ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- Public read policies (anon + authenticated)
-- ---------------------------------------------------------------------
CREATE POLICY markets_public_read          ON markets         FOR SELECT USING (true);
CREATE POLICY branches_public_read         ON market_branches FOR SELECT USING (true);
CREATE POLICY categories_public_read       ON categories      FOR SELECT USING (true);
CREATE POLICY products_public_read         ON products        FOR SELECT USING (true);
CREATE POLICY aliases_public_read          ON product_aliases FOR SELECT USING (true);
CREATE POLICY prices_public_read           ON prices          FOR SELECT USING (true);
CREATE POLICY campaigns_public_read        ON campaigns       FOR SELECT USING (status = 'active' OR status = 'expired');
CREATE POLICY scrape_runs_public_read      ON scrape_runs     FOR SELECT USING (true);

-- ---------------------------------------------------------------------
-- user_profiles: her kullanıcı kendi profiline erişir
-- ---------------------------------------------------------------------
CREATE POLICY user_profiles_self_select
  ON user_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY user_profiles_self_insert
  ON user_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_profiles_self_update
  ON user_profiles FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_profiles_self_delete
  ON user_profiles FOR DELETE
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- user_watches: her kullanıcı kendi watch'larına erişir
-- ---------------------------------------------------------------------
CREATE POLICY user_watches_self_select
  ON user_watches FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY user_watches_self_insert
  ON user_watches FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_watches_self_update
  ON user_watches FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_watches_self_delete
  ON user_watches FOR DELETE
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- notifications: kullanıcı sadece kendi bildirimlerini okur.
-- Yazma işini Edge Function service_role ile yapar, bu yüzden INSERT
-- policy'si yok (RLS aktifken service_role bypass eder).
-- ---------------------------------------------------------------------
CREATE POLICY notifications_self_select
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY notifications_self_update
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
-- ^ kullanıcı "clicked" veya "dismissed" işaretleyebilsin diye.

-- ---------------------------------------------------------------------
-- receipt_submissions: kullanıcı kendi gönderimini görür.
-- ---------------------------------------------------------------------
CREATE POLICY receipts_self_select
  ON receipt_submissions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY receipts_self_insert
  ON receipt_submissions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE sadece service_role (moderation). Kullanıcı gönderdikten
-- sonra değiştiremez. Policy yok → RLS bloklar, service_role bypass eder.

-- ---------------------------------------------------------------------
-- Grant'ler: Supabase default rolleri anon ve authenticated
-- ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- Public tablolar: SELECT yeterli
GRANT SELECT ON markets, market_branches, categories, products,
               product_aliases, prices, campaigns, scrape_runs,
               latest_prices, price_stats_7d, price_stats_30d,
               current_campaigns
  TO anon, authenticated;

-- Kullanıcıya özel: tam CRUD (policy'ler satır satır kısıtlar)
GRANT SELECT, INSERT, UPDATE, DELETE ON user_profiles, user_watches
  TO authenticated;
GRANT SELECT, UPDATE ON notifications
  TO authenticated;
GRANT SELECT, INSERT ON receipt_submissions
  TO authenticated;

-- Sequence grant'leri (user_watches, receipt_submissions BIGSERIAL kullanıyor)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Function execute grant'leri
GRANT EXECUTE ON FUNCTION detect_deals(NUMERIC, INTEGER)    TO anon, authenticated;
GRANT EXECUTE ON FUNCTION watches_to_trigger(UUID)          TO authenticated;
-- ^ watches_to_trigger server-side sorgu için; Edge Function service_role ile çağırır,
--   ama authenticated için de izin açık kalsın (RLS halt almayacak zaten).
