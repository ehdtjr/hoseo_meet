"""Validate the complete rental seed before the importer opens a transaction."""
import csv
import math
from pathlib import Path

FIELDS = (
    "name", "address", "contact", "price", "fee", "options", "gas_type",
    "comment", "place", "latitude", "longitude",
)


def read_rentals(path: str | Path) -> list[dict[str, str]]:
    with open(path, encoding="utf-8-sig", newline="") as source:
        reader = csv.reader(source, strict=True)
        if next(reader, None) != list(FIELDS):
            raise ValueError("Rental CSV must have the canonical 11-column header")
        rows = []
        seen = set()
        for values in reader:
            if not values:
                continue
            line = reader.line_num
            if len(values) != len(FIELDS):
                raise ValueError(f"Rental CSV line {line}: expected 11 columns")
            row = dict(zip(FIELDS, values))
            for field in ("name", "address", "place"):
                if not row[field].strip():
                    raise ValueError(f"Rental CSV line {line}: empty {field}")
            key = (row["name"].strip(), row["address"].strip())
            if key in seen:
                raise ValueError(f"Rental CSV line {line}: duplicate name/address")
            seen.add(key)
            for field, limit in (("latitude", 90), ("longitude", 180)):
                try:
                    coordinate = float(row[field])
                except ValueError:
                    raise ValueError(f"Rental CSV line {line}: invalid {field}") from None
                if not math.isfinite(coordinate) or not -limit <= coordinate <= limit:
                    raise ValueError(f"Rental CSV line {line}: invalid {field}")
            rows.append(row)
        if not rows:
            raise ValueError("Rental CSV must contain at least one data row")
        return rows


if __name__ == "__main__":
    import sys

    rows = read_rentals(sys.argv[1])
    print(f"Rental CSV validated: {len(rows)} unique rows, {len(FIELDS)} columns")
