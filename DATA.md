# Raw data (needed to re-run the notebook)

The raw file is **not** in this repo, because it is someone else's data. The cleaned data is in `outputs/cars_cleaned.csv`.

- **Dataset:** CarDekho used car listings, downloaded from Kaggle (file name `cardekho_dataset.csv`). Search Kaggle for "CarDekho used car dataset" and check the dataset page for its licence and terms.
- **Save it as** `cardekho_dataset.csv` in the same folder as the notebook.
- **Expected:** 15,411 rows and 14 columns (the first column is an old row number called `Unnamed: 0`): car_name, brand, model, vehicle_age, km_driven, seller_type, fuel_type, transmission_type, mileage, engine, max_power, seats, selling_price
- **SHA-256 of the file I used:** `72481e7f9dbe00166742504d68fa5be466a0f271271c536316e1bf1af96a38b0`
- **Check you have the right file:** run `python check_raw_data.py`
- **Prices are asking prices** from listings, not final sale prices.

## What is already in this repo
- `outputs/cars_cleaned.csv` (15,229 rows after cleaning), cleaning log, value loss by model, same-model price gaps
- The notebook and `analysis.sql` need the raw file to run end to end.
