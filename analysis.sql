-- SQL used in used_car_price_analysis.ipynb (SQLite)
-- Tables:
--   raw_cars : the original file as it is (old row number renamed to listing_index)
--   cars     : cleaned listings (see the notebook for the cleaning steps)
-- SQLite has no MEDIAN function, so medians use ROW_NUMBER() and pick the middle row(s).

-- 1. Data quality: problem counts
SELECT COUNT(*)                                  AS total_rows,
       SUM(seats = 0)                            AS zero_seats,
       SUM(km_driven > 500000)                   AS km_over_500k,
       SUM(selling_price > 10000000)             AS price_over_1_crore,
       SUM(vehicle_age = 0)                      AS age_zero,
       SUM(mileage < 8)                          AS mileage_under_8,
       COUNT(DISTINCT brand)                     AS distinct_brand_spellings
FROM raw_cars;

-- 2. Data quality: duplicate rows
SELECT SUM(cnt - 1) AS extra_duplicate_rows
FROM (
    SELECT COUNT(*) AS cnt
    FROM raw_cars
    GROUP BY car_name, brand, model, vehicle_age, km_driven, seller_type, fuel_type,
             transmission_type, mileage, engine, max_power, seats, selling_price
    HAVING COUNT(*) > 1
);

-- 3. Data quality: brand spelling
SELECT brand, COUNT(*) AS listings
FROM raw_cars
WHERE LOWER(brand) IN (SELECT LOWER(brand) FROM raw_cars GROUP BY LOWER(brand) HAVING COUNT(DISTINCT brand) > 1)
GROUP BY brand;

-- 4. Data quality: cars labelled Electric
SELECT car_name, fuel_type, engine, max_power, COUNT(*) AS listings
FROM raw_cars
WHERE fuel_type = 'Electric'
GROUP BY car_name, fuel_type, engine, max_power;

-- 5. Data quality: mileage by fuel type
SELECT fuel_type, COUNT(*) AS listings, MIN(mileage) AS min_mileage, ROUND(AVG(mileage), 1) AS avg_mileage, MAX(mileage) AS max_mileage
FROM raw_cars
GROUP BY fuel_type
ORDER BY listings DESC;

-- 6. Clean row count
WITH ranked AS (
    SELECT vehicle_age, selling_price,
           ROW_NUMBER() OVER (PARTITION BY vehicle_age ORDER BY selling_price) AS rn,
           COUNT(*)     OVER (PARTITION BY vehicle_age)                        AS cnt
    FROM cars
),
med AS (
    SELECT vehicle_age, MAX(cnt) AS listings, AVG(selling_price) AS median_price
    FROM ranked
    WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
    GROUP BY vehicle_age
)
SELECT vehicle_age, listings, ROUND(median_price, 0) AS median_price,
       ROUND(100.0 * (median_price - LAG(median_price) OVER (ORDER BY vehicle_age))
             / LAG(median_price) OVER (ORDER BY vehicle_age), 1) AS pct_change_vs_previous_age
FROM med
WHERE vehicle_age <= 15
ORDER BY vehicle_age;

-- 7. Median price by age (median with ROW_NUMBER, change with LAG)
WITH ranked AS (
    SELECT brand, selling_price,
           ROW_NUMBER() OVER (PARTITION BY brand ORDER BY selling_price) AS rn,
           COUNT(*)     OVER (PARTITION BY brand)                        AS cnt
    FROM cars
),
med AS (
    SELECT brand, MAX(cnt) AS listings, AVG(selling_price) AS median_price
    FROM ranked
    WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
    GROUP BY brand
)
SELECT m.brand, m.listings, ROUND(m.median_price, 0) AS median_price,
       ROUND(AVG(c.vehicle_age), 1) AS avg_age, ROUND(AVG(c.km_driven), 0) AS avg_km,
       ROUND(100.0 * m.listings / (SELECT COUNT(*) FROM cars), 1) AS pct_of_listings
FROM med m JOIN cars c ON c.brand = m.brand
WHERE m.listings >= 100
GROUP BY m.brand
ORDER BY m.listings DESC;

-- 8. Brand summary with median price
WITH base AS (
    SELECT car_name,
           CASE WHEN vehicle_age <= 2 THEN '0-2' WHEN vehicle_age <= 5 THEN '3-5'
                WHEN vehicle_age <= 8 THEN '6-8' ELSE '9+' END AS age_band,
           selling_price
    FROM cars
),
band_avg AS (
    SELECT car_name, age_band, COUNT(*) AS n, AVG(selling_price) AS avg_price
    FROM base
    GROUP BY car_name, age_band
),
eligible AS (
    SELECT car_name FROM band_avg GROUP BY car_name HAVING COUNT(*) = 4 AND MIN(n) >= 15
),
with_pct AS (
    SELECT b.car_name, b.age_band, b.n, b.avg_price,
           100.0 * b.avg_price / FIRST_VALUE(b.avg_price) OVER (PARTITION BY b.car_name ORDER BY b.age_band) AS pct_of_newest
    FROM band_avg b JOIN eligible e ON e.car_name = b.car_name
)
SELECT car_name, ROUND(avg_price, 0) AS avg_price_9_plus_years, ROUND(pct_of_newest, 0) AS pct_of_price_when_0_to_2_years_old
FROM with_pct
WHERE age_band = '9+'
ORDER BY pct_of_newest DESC;

-- 9. Value kept by model after 9+ years (FIRST_VALUE)
-- Uses MEDIAN prices (same method as the Python headline number), not averages
WITH ranked AS (
    SELECT car_name, transmission_type, selling_price,
           ROW_NUMBER() OVER (PARTITION BY car_name, transmission_type ORDER BY selling_price) AS rn,
           COUNT(*)     OVER (PARTITION BY car_name, transmission_type)                        AS n
    FROM cars
    WHERE transmission_type IN ('Automatic', 'Manual')
),
m AS (   -- median price of each model for each transmission (models need 50+ listings per transmission)
    SELECT car_name, transmission_type, MAX(n) AS n, AVG(selling_price) AS median_price
    FROM ranked
    WHERE n >= 50 AND rn IN ((n + 1) / 2, (n + 2) / 2)
    GROUP BY car_name, transmission_type
)
SELECT a.car_name, a.n AS automatic_listings, b.n AS manual_listings,
       ROUND(a.median_price, 0) AS automatic_median, ROUND(b.median_price, 0) AS manual_median,
       ROUND(a.median_price / b.median_price, 2) AS automatic_vs_manual
FROM m a JOIN m b ON a.car_name = b.car_name
WHERE a.transmission_type = 'Automatic' AND b.transmission_type = 'Manual'
ORDER BY automatic_vs_manual DESC;

-- Median of the per-model ratios above (this is the 'same model' number, about 1.42x)
WITH ranked AS (
    SELECT car_name, transmission_type, selling_price,
           ROW_NUMBER() OVER (PARTITION BY car_name, transmission_type ORDER BY selling_price) AS rn,
           COUNT(*)     OVER (PARTITION BY car_name, transmission_type)                        AS n
    FROM cars
    WHERE transmission_type IN ('Automatic', 'Manual')
),
m AS (
    SELECT car_name, transmission_type, MAX(n) AS n, AVG(selling_price) AS median_price
    FROM ranked
    WHERE n >= 50 AND rn IN ((n + 1) / 2, (n + 2) / 2)
    GROUP BY car_name, transmission_type
),
r AS (
    SELECT a.median_price / b.median_price AS ratio
    FROM m a JOIN m b ON a.car_name = b.car_name
    WHERE a.transmission_type = 'Automatic' AND b.transmission_type = 'Manual'
),
o AS (
    SELECT ratio, ROW_NUMBER() OVER (ORDER BY ratio) AS rn, COUNT(*) OVER () AS cnt FROM r
)
SELECT MAX(cnt) AS models_compared, ROUND(AVG(ratio), 2) AS median_of_ratios
FROM o
WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2);

-- 10. Automatic vs manual within the same model
WITH t AS (
    SELECT *, NTILE(4) OVER (ORDER BY selling_price) AS price_quartile
    FROM cars
)
SELECT price_quartile, COUNT(*) AS listings,
       MIN(selling_price) AS min_price, MAX(selling_price) AS max_price,
       ROUND(AVG(vehicle_age), 1) AS avg_age, ROUND(AVG(km_driven), 0) AS avg_km,
       ROUND(AVG(max_power), 0) AS avg_power, ROUND(AVG(engine), 0) AS avg_engine_cc,
       ROUND(100.0 * SUM(transmission_type = 'Automatic') / COUNT(*), 1) AS pct_automatic
FROM t
GROUP BY price_quartile
ORDER BY price_quartile;

-- 11. Price quartiles (NTILE)
WITH model_avg AS (
    SELECT brand, model, COUNT(*) AS n, AVG(selling_price) AS avg_price,
           RANK() OVER (PARTITION BY brand ORDER BY AVG(selling_price) DESC) AS rk
    FROM cars
    WHERE brand IN (SELECT brand FROM cars GROUP BY brand HAVING COUNT(*) >= 300)
    GROUP BY brand, model
    HAVING COUNT(*) >= 10
)
SELECT brand, model, n AS listings, ROUND(avg_price, 0) AS avg_price
FROM model_avg
WHERE rk = 1
ORDER BY avg_price DESC;

-- 12. Most expensive model in each popular brand (RANK)
SELECT fuel_type, COUNT(*) AS listings,
       ROUND(AVG(km_driven * 1.0 / MAX(vehicle_age, 1)), 0) AS avg_km_per_year,
       ROUND(AVG(vehicle_age), 1) AS avg_age
FROM cars
GROUP BY fuel_type
ORDER BY listings DESC;

