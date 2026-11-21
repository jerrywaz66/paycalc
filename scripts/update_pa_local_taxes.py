#!/usr/bin/env python3
"""Rebuild PayCalc's Pennsylvania local tax data from the official DCED register.

Downloads the PA DCED "EIT / PIT / LST Tax Register" for all counties and writes
PayCalcCore/Sources/PayCalcCore/Resources/pa_local_taxes.json.

Run it once a year after DCED posts the new tax year (usually December/January):

    python3 scripts/update_pa_local_taxes.py

Or convert a register CSV you already downloaded:

    python3 scripts/update_pa_local_taxes.py --csv path/to/register.csv

Philadelphia is left out: it uses its own wage tax instead of the Act 32 EIT.
"""
import argparse
import csv
import html
import http.cookiejar
import io
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

BASE = "https://apps.dced.pa.gov"
REPORT = BASE + "/munstats-public/ReportInformation2.aspx?report=EitWithCollector_Dyn_Excel&type=O"
OUTPUT = Path(__file__).resolve().parent.parent / "PayCalcCore/Sources/PayCalcCore/Resources/pa_local_taxes.json"
EXCLUDED_COUNTIES = {"PHILADELPHIA"}

# Column positions in the register CSV (its header row only has internal names).
YEAR, COUNTY, MUNI_NAME, SD_NAME = 0, 1, 3, 5
MUNI_NONRESIDENT_EIT, MUNI_RESIDENT_EIT, SD_EIT = 6, 8, 10
TOTAL_LST = 20
PSD = -3


def download_csv() -> str:
    """Click "Display Report" for all counties, then export the report as CSV."""
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    opener.addheaders = [("User-Agent", "Mozilla/5.0 (Macintosh) PayCalc data refresh")]

    page = opener.open(REPORT, timeout=120).read().decode("utf-8", "replace")
    form = {}
    for tag in re.findall(r'<input[^>]*type="hidden"[^>]*>', page):
        name = re.search(r'name="([^"]+)"', tag)
        value = re.search(r'value="([^"]*)"', tag)
        if name:
            form[html.unescape(name.group(1))] = html.unescape(value.group(1)) if value else ""
    form["ctl00$ContentPlaceHolder1$ddCountyId"] = "NULL"
    form["ctl00$ContentPlaceHolder1$btnDisplay"] = "Display Report"
    for field in ("ddMunicipalityId", "ddSdId", "ddClass"):
        selected = re.search(
            r'name="ctl00\$ContentPlaceHolder1\$%s".*?<option selected="selected" value="([^"]*)"' % field, page, re.S)
        if selected:
            form["ctl00$ContentPlaceHolder1$" + field] = selected.group(1)

    shown = opener.open(REPORT, data=urllib.parse.urlencode(form).encode(), timeout=300)
    shown = shown.read().decode("utf-8", "replace")
    export = re.search(r'"ExportUrlBase":"([^"]+)"', shown)
    if not export:
        sys.exit("Could not find the export link on the DCED page. The site may have changed.")
    url = BASE + export.group(1).encode().decode("unicode_escape") + "CSV"
    return opener.open(url, timeout=300).read().decode("utf-8-sig")


def percent(value: str) -> float:
    return float(value) if value.strip() else 0.0


def title_case(name: str) -> str:
    """"WEST READING BORO" -> "West Reading Borough"."""
    words = []
    for word in name.split():
        if word == "TWP":
            words.append("Township")
        elif word == "BORO":
            words.append("Borough")
        elif word in ("S", "D") and name.endswith(" S D"):
            words.append(word)
        elif "-" in word:
            words.append("-".join(part.capitalize() for part in word.split("-")))
        elif word.startswith("MC") and len(word) > 2:
            words.append("Mc" + word[2:].capitalize())
        else:
            words.append(word.capitalize())
    text = " ".join(words)
    return re.sub(r"\bS D$", "SD", text)


def convert(text: str) -> dict:
    rows = list(csv.reader(io.StringIO(text)))
    header, rows = rows[0], [r for r in rows[1:] if r and r[0].strip()]
    if len(header) < 60:
        sys.exit(f"Unexpected register format ({len(header)} columns).")

    years = {r[YEAR] for r in rows}
    if len(years) != 1:
        sys.exit(f"Expected one tax year, found {sorted(years)}.")

    # A town that straddles two counties (e.g. Bethlehem) appears once per county with the
    # same PSD code and the same rates. Keep both so it shows under either county.
    areas, rates_by_psd, seen = [], {}, set()
    for r in rows:
        county = r[COUNTY].strip().upper()
        if county in EXCLUDED_COUNTIES:
            continue
        psd = r[PSD].strip()
        if not re.fullmatch(r"\d{6}", psd):
            sys.exit(f"Bad PSD code {psd!r} for {r[MUNI_NAME]}.")
        if (county, psd) in seen:
            sys.exit(f"Duplicate PSD code {psd} in {county}.")
        seen.add((county, psd))
        resident = round(percent(r[MUNI_RESIDENT_EIT]) + percent(r[SD_EIT]), 4)
        nonresident = round(percent(r[MUNI_NONRESIDENT_EIT]), 4)
        lst = percent(r[TOTAL_LST])
        # LST is capped at $52, except $156 for distressed (Act 47) cities such as Harrisburg.
        if not (0 <= resident <= 5 and 0 <= nonresident <= 5 and 0 <= lst <= 156):
            sys.exit(f"Out-of-range rate for {psd} {r[MUNI_NAME]}: {resident}, {nonresident}, {lst}.")
        if rates_by_psd.setdefault(psd, (resident, nonresident, lst)) != (resident, nonresident, lst):
            sys.exit(f"PSD {psd} has different rates in different counties.")
        areas.append({
            "psd": psd,
            "county": county.title(),
            "municipality": title_case(r[MUNI_NAME].strip()),
            "schoolDistrict": title_case(r[SD_NAME].strip()),
            "resident": resident,
            "nonresident": nonresident,
            "lst": lst,
        })

    areas.sort(key=lambda a: (a["county"], a["municipality"], a["schoolDistrict"]))
    return {"taxYear": int(years.pop()), "source": "PA DCED EIT/PIT/LST Tax Register",
            "areas": areas}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", help="Use a register CSV you already downloaded instead of downloading it.")
    args = parser.parse_args()

    text = Path(args.csv).read_text(encoding="utf-8-sig") if args.csv else download_csv()
    data = convert(text)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    # One town per line, so a yearly update shows up as a readable diff.
    lines = [json.dumps(a, separators=(",", ":")) for a in data["areas"]]
    OUTPUT.write_text(
        '{"taxYear":%d,"source":%s,"areas":[\n%s\n]}\n'
        % (data["taxYear"], json.dumps(data["source"]), ",\n".join(lines)))
    counties = len({a["county"] for a in data["areas"]})
    print(f"Tax year {data['taxYear']}: {len(data['areas'])} areas in {counties} counties -> {OUTPUT}")


if __name__ == "__main__":
    main()
