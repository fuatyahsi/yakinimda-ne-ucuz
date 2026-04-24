from __future__ import annotations

import unittest

import extract_items


class _Payload:
    def __init__(self, txts=None, scores=None) -> None:
        self.txts = txts
        self.scores = scores


class ExtractItemsTest(unittest.TestCase):
    def test_run_reader_handles_none_payload_fields(self) -> None:
        def engine(_image):
            return (_Payload(txts=None, scores=None), None)

        text, confidence = extract_items.run_reader(engine, image=None)

        self.assertEqual("", text)
        self.assertEqual(0.0, confidence)

    def test_run_reader_merges_texts_and_scores(self) -> None:
        def engine(_image):
            return (_Payload(txts=["BİM", "Kaşar", None], scores=[0.9, 0.7, None]), None)

        text, confidence = extract_items.run_reader(engine, image=None)

        self.assertEqual("BİM Kaşar", text)
        self.assertAlmostEqual(0.8, confidence, places=2)

    def test_should_ocr_crop_rejects_blank_crop(self) -> None:
        cv2 = extract_items.ensure_cv_stack()
        import numpy as np  # type: ignore

        blank = np.full((40, 80, 3), 255, dtype=np.uint8)

        self.assertFalse(
            extract_items.should_ocr_crop(
                cv2,
                blank,
                min_stddev=10.0,
                min_foreground_ratio=0.01,
            )
        )


if __name__ == "__main__":
    unittest.main()
