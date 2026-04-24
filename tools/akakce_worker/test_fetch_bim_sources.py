from __future__ import annotations

import unittest
from datetime import datetime

import fetch_bim_sources


class FetchBimSourcesTest(unittest.TestCase):
    def test_extracts_bim_sections_and_big_images(self) -> None:
        html = """
        <div class="posterArea">
          <div class="subMenu aktuelsubmenu">
            <table>
              <tr>
                <th class="title">AKTUEL URUNLER</th>
                <th class="title">INDIRIM</th>
              </tr>
              <tr>
                <td class="link"><a href="/Categories/100/aktuel-urunler.aspx?Bim_AktuelTarihKey=1531">13 Mart Cuma</a></td>
                <td class="link"><a href="/Categories/100/aktuel-urunler.aspx?Bim_AktuelTarihKey=1540">14-21 Mart Indirim</a></td>
              </tr>
            </table>
          </div>
          <div class="genelgrup grup1 col-12">
            <a class="subTabArea triangle"><span class="text">13 Mart Cuma </span></a>
            <div class="row item">
              <a class="download" href="https://cdn1.bim.com.tr/uploads/afisler/main-1.jpg" download></a>
              <div class="bigArea">
                <a href="https://cdn1.bim.com.tr/uploads/afisler/main-1.jpg" class="fancyboxImage"></a>
              </div>
              <div class="smallArea">
                <a class="small" data-bigimg="https://cdn1.bim.com.tr/uploads/afisler/main-1.jpg"></a>
                <a class="small" data-bigimg="https://cdn1.bim.com.tr/uploads/afisler/page-2.jpg"></a>
              </div>
            </div>
          </div>
          <div class="genelgrup grup2 col-12">
            <a class="subTabArea triangle"><span class="text">14-21 Mart Indirim</span></a>
            <div class="row item">
              <a class="download" href="https://cdn1.bim.com.tr/uploads/afisler/discount-1.jpg" download></a>
              <div class="smallArea">
                <a class="small" data-bigimg="https://cdn1.bim.com.tr/uploads/afisler/discount-2.jpg"></a>
              </div>
            </div>
          </div>
        </div>
        """

        brochures = fetch_bim_sources.extract_bim_brochures(
            html,
            listing_url="https://www.bim.com.tr/Categories/680/afisler.aspx",
            discovered_at=datetime(2026, 3, 19, 8, 0, 0),
        )

        self.assertEqual(2, len(brochures))
        self.assertEqual("BİM", brochures[0].market_name)
        self.assertEqual("Aktüel | 13 Mart Cuma", brochures[0].title)
        self.assertEqual(2, brochures[0].image_count)
        self.assertEqual(
            [
                "https://cdn1.bim.com.tr/uploads/afisler/main-1.jpg",
                "https://cdn1.bim.com.tr/uploads/afisler/page-2.jpg",
            ],
            [image.image_url for image in brochures[0].images],
        )
        self.assertEqual("2026-03-13", brochures[0].valid_from)
        self.assertEqual(
            "https://www.bim.com.tr/Categories/100/aktuel-urunler.aspx?Bim_AktuelTarihKey=1531",
            brochures[0].catalog_url,
        )
        self.assertEqual("İndirim | 14-21 Mart Indirim", brochures[1].title)
        self.assertEqual("2026-03-14", brochures[1].valid_from)
        self.assertEqual("2026-03-21", brochures[1].valid_until)
        self.assertEqual(
            "https://www.bim.com.tr/Categories/100/aktuel-urunler.aspx?Bim_AktuelTarihKey=1540",
            brochures[1].catalog_url,
        )


if __name__ == "__main__":
    unittest.main()
