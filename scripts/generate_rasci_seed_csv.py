#!/usr/bin/env python3
"""Regenerate RASCI template CSV seed rows from the ISO27001 workbook."""

from __future__ import annotations

import csv
import re
import uuid
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ISO27001_ROOT = Path(
    __import__("os").environ.get("ISO27001_ROOT", ROOT.parent / "ISO27001")
)
FULL_XLSX = (
    ISO27001_ROOT
    / "2 Information Security Management System"
    / "ISMS RASCI Matrix - FULL.xlsx"
)
TEMPLATE_ROOT = ROOT / "data" / "templates" / "voca" / "documents"
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def format_clause(clause: str) -> str:
    clause = clause.strip()
    if not clause:
        return clause
    try:
        value = float(clause)
        if abs(value - round(value)) < 0.001:
            return str(int(round(value)))
        return re.sub(r"\.?0+$", "", f"{value:.10f}")
    except ValueError:
        return clause


def sheet_target(z: zipfile.ZipFile, sheet_name: str) -> str:
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    rid_to_target = {
        rel.get("Id"): rel.get("Target")
        for rel in rels
        if rel.tag.endswith("Relationship")
    }
    for sheet in wb.findall(".//m:sheet", NS):
        if sheet.get("name") != sheet_name:
            continue
        rid = sheet.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
        return "xl/" + rid_to_target[rid].lstrip("/")
    raise SystemExit(f"Sheet not found: {sheet_name}")


def shared_strings(z: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in z.namelist():
        return []
    root = ET.fromstring(z.read("xl/sharedStrings.xml"))
    strings: list[str] = []
    for item in root.findall("m:si", NS):
        strings.append(
            "".join(
                text.text or ""
                for text in item.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t")
            )
        )
    return strings


def extract_labels(xlsx_path: Path, sheet_name: str) -> list[str]:
    with zipfile.ZipFile(xlsx_path) as z:
        shared = shared_strings(z)
        sheet = ET.fromstring(z.read(sheet_target(z, sheet_name)))
        labels: list[str] = []
        for row in sheet.findall(".//m:sheetData/m:row", NS):
            values: list[str] = []
            for cell in row.findall("m:c", NS):
                value = cell.find("m:v", NS)
                if value is None:
                    values.append("")
                elif cell.get("t") == "s":
                    values.append(shared[int(value.text)])
                else:
                    values.append(value.text or "")
            if len(values) < 2:
                continue
            clause, title = values[0].strip(), values[1].strip()
            if "Responsible Named Person" in title:
                continue
            if clause.startswith("[") or "ISO27001" in clause or "Classification" in clause:
                continue
            if not title and not clause:
                continue
            if title:
                if clause and re.fullmatch(r"[\d.]+", clause):
                    label = f"{format_clause(clause)} {title}"
                elif clause and not title:
                    label = clause
                elif not clause:
                    label = title
                else:
                    label = f"{clause} {title}".strip()
            else:
                label = clause
            label = label.strip()
            if label:
                labels.append(label)
        return labels


def write_csv(path: Path, headers: list[str], labels: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(headers)
        blanks = [""] * (len(headers) - 3)
        for label in labels:
            writer.writerow([label, *blanks, str(uuid.uuid4()), ""])
    print(f"Wrote {len(labels)} rows to {path}")


def main() -> None:
    if not FULL_XLSX.is_file():
        raise SystemExit(f"Missing workbook: {FULL_XLSX}")

    isms = extract_labels(FULL_XLSX, "ISO 27001 2022 ISMS RASCI")
    annex = extract_labels(FULL_XLSX, "ISO 27001 2022 Annex A RASCI")

    write_csv(
        TEMPLATE_ROOT
        / "isms-rasci-matrix-basic-accountability-matrix"
        / "isms-rasci-matrix-basic-accountability-matrix.csv",
        [
            "iso270012022_isms_accountability",
            "responsible_named_person",
            "accountable_named_person",
            "_row_id",
            "_deleted_at",
        ],
        isms,
    )
    write_csv(
        TEMPLATE_ROOT / "isms-rasci-matrix-full" / "isms-rasci-matrix-full.csv",
        [
            "iso270012022_isms_accountability",
            "responsible_named_person",
            "accountable_named_person",
            "consulted_named_person",
            "informed_named_person",
            "support_named_person",
            "_row_id",
            "_deleted_at",
        ],
        isms + annex,
    )


if __name__ == "__main__":
    main()
