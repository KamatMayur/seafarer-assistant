"""PDF text extraction: pdfplumber first, Tesseract OCR fallback for scanned PDFs (if installed)."""

from __future__ import annotations

import io
import logging
import re
import shutil
from dataclasses import dataclass

import pdfplumber

log = logging.getLogger(__name__)

MIN_CHARS_PER_PAGE = 100  # below this the PDF is probably a scan
MAX_PAGES = 60  # circulars are short; very long PDFs are annexure dumps, we index the start only
_SPACES = re.compile(r"[ \t ]+")
_CID = re.compile(r"\(cid:\d+\)")  # unmapped glyphs, mostly from Hindi header fonts
_WORD = re.compile(r"[A-Za-z][A-Za-z'’]+")
# Signs of a bad OCR text layer: case flips or digits inside words ("endorsemenVsignature", "lndia", "Merchanl").
_GARBLED = re.compile(r"^(?=.*[a-z][A-Z])|[a-z]\d|\d[a-z]{2}|^l[bcdfghjkmnpqrstvwxz]")


@dataclass
class ExtractResult:
    text: str
    pages: int
    method: str  # 'pdfplumber' | 'ocr' | 'none'
    quality: float = 1.0  # 0..1, share of English words that look well-formed


def _clean_page(text: str) -> str:
    text = _CID.sub("", text).replace("�", "'")
    lines = [_SPACES.sub(" ", ln).strip() for ln in text.splitlines()]
    return "\n".join(ln for ln in lines if ln)


def text_quality(text: str, title: str | None = None) -> float:
    """0..1. Combines (a) the share of well-formed words and (b) how many of the listing title's words appear
    in the text. The title is typed by DGMA staff, so a clean PDF contains nearly all of them, while a bad OCR
    layer misspells them ('resardins', 'sisnatures')."""
    words = _WORD.findall(text)
    if len(words) < 30:
        return 0.0 if not words else 0.5
    bad = sum(1 for w in words if _GARBLED.search(w) and not w.isupper())
    score = 1 - bad / len(words)
    if title:
        title_words = {w.lower() for w in _WORD.findall(title) if len(w) >= 5}
        if len(title_words) >= 3:
            text_words = {w.lower() for w in words}
            recall = sum(1 for w in title_words if w in text_words) / len(title_words)
            # recall 1.0 -> no penalty; recall 0.6 -> score capped at 0.6
            score = min(score, 0.5 + recall / 2) if recall >= 0.8 else min(score, recall)
    return round(score, 3)


def ocr_available() -> bool:
    try:
        import pytesseract  # noqa: F401
    except ImportError:
        return False
    return shutil.which("tesseract") is not None


def _ocr(pdf: pdfplumber.PDF, langs: str = "eng+hin") -> str:
    import pytesseract

    out = []
    for page in pdf.pages[:MAX_PAGES]:
        image = page.to_image(resolution=250).original
        try:
            out.append(pytesseract.image_to_string(image, lang=langs))
        except pytesseract.TesseractError:
            out.append(pytesseract.image_to_string(image, lang="eng"))
    return "\f".join(_clean_page(t) for t in out)


def extract_text(pdf_bytes: bytes) -> ExtractResult:
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        n = len(pdf.pages)
        texts = []
        for page in pdf.pages[:MAX_PAGES]:
            try:
                texts.append(_clean_page(page.extract_text() or ""))
            except Exception as e:  # malformed page; keep going
                log.warning("page extract failed: %s", e)
                texts.append("")
        text = "\f".join(texts)
        if len(text.replace("\f", "")) >= MIN_CHARS_PER_PAGE * min(n, MAX_PAGES) * 0.5:
            return ExtractResult(text, n, "pdfplumber", text_quality(text))
        if ocr_available():
            ocr_text = _ocr(pdf)
            if len(ocr_text) > len(text):
                return ExtractResult(ocr_text, n, "ocr", text_quality(ocr_text))
        return ExtractResult(text, n, "pdfplumber" if text.strip() else "none", text_quality(text))
