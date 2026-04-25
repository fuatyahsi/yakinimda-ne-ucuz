"""Quick unit test for BulkProductResolver — mock client, no Supabase.

python backend/workers/_test_bulk_resolver.py
"""

from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from core import (  # noqa: E402
    BulkProductResolver,
    RunStats,
    WorkerItem,
)


class MockClient:
    """In-memory product_aliases + products tabanli sahte SupabaseClient."""

    def __init__(self) -> None:
        # tablename → list of dicts
        self.aliases: list[dict] = []
        self.products: list[dict] = []
        self._next_pid = 0
        self.calls: list[tuple[str, str, dict]] = []  # method, table, params

    # Helpers --------------------------------------------------------
    def _new_pid(self) -> str:
        self._next_pid += 1
        return f"pid-{self._next_pid:04d}"

    @staticmethod
    def _parse_in(filter_value: str) -> list[str]:
        # 'in.("a","b","c, d")' → ['a','b','c, d']
        body = filter_value[len("in.("):-1]
        out: list[str] = []
        i = 0
        while i < len(body):
            assert body[i] == '"', f"expected quote at {i}: {body!r}"
            i += 1
            buf: list[str] = []
            while i < len(body):
                if body[i] == "\\":
                    buf.append(body[i + 1])
                    i += 2
                elif body[i] == '"':
                    i += 1
                    break
                else:
                    buf.append(body[i])
                    i += 1
            out.append("".join(buf))
            if i < len(body) and body[i] == ",":
                i += 1
        return out

    @staticmethod
    def _eq(filter_value: str) -> str:
        assert filter_value.startswith("eq."), filter_value
        return filter_value[len("eq."):]

    # API ------------------------------------------------------------
    def select(self, table: str, params: dict) -> list[dict]:
        self.calls.append(("select", table, dict(params)))
        if table == "product_aliases":
            wanted = set(self._parse_in(params["alias"]))
            source = self._eq(params["source"])
            return [
                {"alias": r["alias"], "product_id": r["product_id"]}
                for r in self.aliases
                if r["alias"] in wanted and r["source"] == source
            ]
        if table == "products":
            wanted = set(self._parse_in(params["canonical_name"]))
            return [
                {"id": r["id"], "canonical_name": r["canonical_name"]}
                for r in self.products
                if r["canonical_name"] in wanted
            ]
        raise AssertionError(f"unexpected select on table={table}")

    def insert(self, table: str, rows: list[dict]) -> list[dict]:
        self.calls.append(("insert", table, {"count": len(rows)}))
        if table == "products":
            out = []
            for r in rows:
                pid = self._new_pid()
                row = {**r, "id": pid}
                self.products.append(row)
                out.append(row)
            return out
        raise AssertionError(f"unexpected insert on table={table}")

    def upsert(
        self, table: str, rows: list[dict], on_conflict: str
    ) -> list[dict]:
        self.calls.append(
            ("upsert", table, {"count": len(rows), "on_conflict": on_conflict})
        )
        if table == "product_aliases":
            existing_keys = {(r["alias"], r["source"]) for r in self.aliases}
            for r in rows:
                key = (r["alias"], r["source"])
                if key in existing_keys:
                    continue
                self.aliases.append(dict(r))
                existing_keys.add(key)
            return rows
        raise AssertionError(f"unexpected upsert on table={table}")


def make_item(name: str, brand: str | None = None) -> WorkerItem:
    return WorkerItem(
        market_id="test",
        product_name=name,
        brand=brand,
        discount_price=10.0,
        regular_price=12.0,
    )


def test_all_new() -> None:
    """All items new — no existing aliases or products."""
    client = MockClient()
    stats = RunStats()
    resolver = BulkProductResolver(client, "marketfiyati", stats)

    items = [
        make_item("Sutas Tam Yagli Sut 1L", "Sutas"),
        make_item("Pinar Beyaz Peynir 200g", "Pinar"),
    ]
    mapping = resolver.resolve_batch(items)

    assert mapping[0] is not None
    assert mapping[1] is not None
    assert mapping[0] != mapping[1]
    assert stats.products_added == 2
    assert stats.products_matched == 0
    # 1 SELECT alias + 1 SELECT products + 1 INSERT products + 1 UPSERT alias
    methods = [c[0] for c in client.calls]
    assert methods == ["select", "select", "insert", "upsert"], methods
    print("test_all_new OK")


def test_all_existing_alias() -> None:
    """All items have an existing alias — should be 1 SELECT only."""
    client = MockClient()
    # Pre-seed aliases
    client.products.append({"id": "p1", "canonical_name": "X"})
    client.aliases.append(
        {"alias": "sutas-sut-1l", "source": "marketfiyati", "product_id": "p1"}
    )
    client.aliases.append(
        {"alias": "pinar-peynir-200g", "source": "marketfiyati", "product_id": "p1"}
    )

    stats = RunStats()
    resolver = BulkProductResolver(client, "marketfiyati", stats)

    items = [
        make_item("Sutas Sut 1L"),
        make_item("Pinar Peynir 200g"),
    ]
    # canonical_key()'in deterministik oldugunu kontrol et
    print(
        f"  canonical_keys: {[i.canonical_key() for i in items]}"
    )
    # Alias'lari item'larin canonical_key'ine gore ayarla
    client.aliases.clear()
    for item in items:
        client.aliases.append(
            {
                "alias": item.canonical_key(),
                "source": "marketfiyati",
                "product_id": "p1",
            }
        )

    mapping = resolver.resolve_batch(items)
    assert mapping[0] == "p1", mapping
    assert mapping[1] == "p1", mapping
    assert stats.products_added == 0
    assert stats.products_matched == 2
    methods = [c[0] for c in client.calls]
    # Sadece alias SELECT
    assert methods == ["select"], methods
    print("test_all_existing_alias OK")


def test_mixed() -> None:
    """1 alias hit, 1 canonical_name hit, 1 totally new."""
    client = MockClient()
    stats = RunStats()
    resolver = BulkProductResolver(client, "marketfiyati", stats)

    items = [
        make_item("AAA Item One"),       # alias zaten var
        make_item("BBB Item Two"),       # alias yok ama canonical var
        make_item("CCC Item Three"),     # tamamen yeni
    ]
    # alias hit
    client.aliases.append(
        {
            "alias": items[0].canonical_key(),
            "source": "marketfiyati",
            "product_id": "p-existing-1",
        }
    )
    # canonical_name hit
    client.products.append({"id": "p-existing-2", "canonical_name": "BBB Item Two"})

    mapping = resolver.resolve_batch(items)
    assert mapping[0] == "p-existing-1", mapping
    assert mapping[1] == "p-existing-2", mapping
    assert mapping[2] is not None and mapping[2].startswith("pid-")
    assert stats.products_added == 1  # only CCC
    assert stats.products_matched == 1  # only AAA (BBB came via name path)
    print("test_mixed OK")


def test_dup_canonical_in_batch() -> None:
    """Ayni canonical_name farkli alias'lar (ayni product) — tek INSERT."""
    client = MockClient()
    stats = RunStats()
    resolver = BulkProductResolver(client, "marketfiyati", stats)

    # Ayni product_name, farkli brand → ayni canonical_name ama farkli alias
    items = [
        make_item("Sut 1 Litre", "Sutas"),
        make_item("Sut 1 Litre", "Pinar"),
    ]
    assert items[0].canonical_key() != items[1].canonical_key(), \
        "Brand alias'a giriyor — bu test bunu test ediyor"

    mapping = resolver.resolve_batch(items)
    assert mapping[0] == mapping[1], (mapping, "ayni product paylasilmali")
    assert stats.products_added == 1, stats
    # Iki alias UPSERT edilmeli
    upserts = [c for c in client.calls if c[0] == "upsert"]
    assert len(upserts) == 1
    assert upserts[0][2]["count"] == 2
    print("test_dup_canonical_in_batch OK")


def test_empty() -> None:
    client = MockClient()
    stats = RunStats()
    resolver = BulkProductResolver(client, "marketfiyati", stats)
    assert resolver.resolve_batch([]) == {}
    assert client.calls == []
    print("test_empty OK")


if __name__ == "__main__":
    test_empty()
    test_all_new()
    test_all_existing_alias()
    test_mixed()
    test_dup_canonical_in_batch()
    print("\nAll resolver tests passed.")
