-- =====================================================================
-- 014_get_latest_prices_snapshot.sql
--
-- Delta sweep mode icin: cron sweep basinda tek RPC ile tum aktif
-- marketlerin latest_prices snapshot'i alinir. core.insert_price bu
-- map'i kullanarak ayni (product, market, price) icin yeni satir
-- yazmamaya karar verir — DB writes %80-95 azalir, gunduz refresh
-- cok hizli biter.
--
-- PostgREST default max-rows 1000 oldugu icin /latest_prices?select=
-- ile 16k row alinamaz. RPC tek POST'ta tam liste doner (HTTP response
-- size limit'i icinde, ~16k row × ~50 byte = ~800KB).
-- =====================================================================

CREATE OR REPLACE FUNCTION get_latest_prices_for_markets(
  p_market_ids TEXT[] DEFAULT NULL
)
RETURNS TABLE (
  product_id UUID,
  market_id  TEXT,
  price      NUMERIC
)
LANGUAGE sql
STABLE
AS $$
  SELECT lp.product_id, lp.market_id, lp.price
  FROM latest_prices lp
  WHERE
    p_market_ids IS NULL
    OR array_length(p_market_ids, 1) IS NULL
    OR lp.market_id = ANY(p_market_ids);
$$;

COMMENT ON FUNCTION get_latest_prices_for_markets(TEXT[]) IS
  'Delta sweep mode: cron sweep basinda tek RPC ile latest_prices '
  'snapshot doner. core.insert_price ayni fiyatli urunler icin INSERT '
  'atlar, DB write azalir.';

GRANT EXECUTE ON FUNCTION get_latest_prices_for_markets(TEXT[])
  TO anon, authenticated;
