import sys, hashlib, pandas as pd
FILE = "cardekho_dataset.csv"
SHA256 = "72481e7f9dbe00166742504d68fa5be466a0f271271c536316e1bf1af96a38b0"
COLS = ["Unnamed: 0", "car_name", "brand", "model", "vehicle_age", "km_driven", "seller_type", "fuel_type",
        "transmission_type", "mileage", "engine", "max_power", "seats", "selling_price"]
try:
    raw = open(FILE, "rb").read()
except FileNotFoundError:
    sys.exit(f"{FILE} not found. Download it (see DATA.md) and save it next to this script.")
d = pd.read_csv(FILE)
print(f"{FILE}: {len(d):,} rows, {len(d.columns)} columns ->", "PASS" if len(d) == 15411 and list(d.columns) == COLS else "FAIL (expected 15,411 rows and the 14 columns in DATA.md)")
print("Same file as the one I used (SHA-256):", "yes" if hashlib.sha256(raw).hexdigest() == SHA256 else "no (a different version of the file; results may differ slightly)")
