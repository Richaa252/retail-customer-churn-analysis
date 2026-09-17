/* ==========================================================================
   RETAIL CUSTOMER RETENTION & CHURN ANALYSIS
   Script 1 of 2 — TABLE SETUP + SYNTHETIC DATA GENERATION
   Written for MySQL 8.0+ (uses window functions in script 2 and RAND()).
   Run this once to create and populate `customer_churn_data` before
   running 02_data_cleaning_and_analysis.sql.
   ========================================================================== */

DROP TABLE IF EXISTS customer_churn_data;

CREATE TABLE customer_churn_data (
    RowID                           INT AUTO_INCREMENT PRIMARY KEY,  -- surrogate key, lets us safely create real duplicate CustomerIDs below
    CustomerID                      INT,
    Tenure                          DECIMAL(6,2),
    PreferredLoginDevice            VARCHAR(50),
    CityTier                        INT,
    WarehouseToHome                 DECIMAL(6,2),
    PreferredPaymentMode            VARCHAR(50),
    Gender                          VARCHAR(10),
    HourSpendOnApp                  DECIMAL(4,2),
    NumberOfDeviceRegistered        INT,
    PreferedOrderCat                VARCHAR(50),
    SatisfactionScore               INT,
    MaritalStatus                   VARCHAR(20),
    NumberOfAddress                 INT,
    Complain                        INT,
    OrderAmountHikeFromlastYear     DECIMAL(6,2),
    CouponUsed                      DECIMAL(6,2),
    OrderCount                      DECIMAL(6,2),
    DaySinceLastOrder               DECIMAL(6,2),
    CashbackAmount                  DECIMAL(8,2),
    Churn                           INT
);

/* --------------------------------------------------------------------------
   STEP 1 — Build a disposable "numbers" table (1 to 4,200) using a classic
   MySQL tally-table trick: cross-joining a 10-row digits table with itself
   generates 10,000 combinations, which we cap with LIMIT. This avoids
   relying on recursive CTEs, so it works on older MySQL 5.7 installs too.
   -------------------------------------------------------------------------- */
DROP TEMPORARY TABLE IF EXISTS digits;
CREATE TEMPORARY TABLE digits (d INT);
INSERT INTO digits VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

DROP TEMPORARY TABLE IF EXISTS seq_numbers;
CREATE TEMPORARY TABLE seq_numbers AS
SELECT (a.d + b.d * 10 + c.d * 100 + e.d * 1000 + 1) AS n
FROM digits a, digits b, digits c, digits e
ORDER BY n
LIMIT 4200;

/* --------------------------------------------------------------------------
   STEP 2 — Generate 4,200 base customer records with random attributes.
   Churn is left NULL here and computed in Step 3, since it depends on
   several of the columns generated in this step.
   -------------------------------------------------------------------------- */
INSERT INTO customer_churn_data (
    CustomerID, Tenure, PreferredLoginDevice, CityTier, WarehouseToHome,
    PreferredPaymentMode, Gender, HourSpendOnApp, NumberOfDeviceRegistered,
    PreferedOrderCat, SatisfactionScore, MaritalStatus, NumberOfAddress,
    Complain, OrderAmountHikeFromlastYear, CouponUsed, OrderCount,
    DaySinceLastOrder, CashbackAmount
)
SELECT
    50000 + n                                                          AS CustomerID,
    ROUND(POWER(RAND(), 2) * 60, 0)                                     AS Tenure,          -- skewed toward low tenure
    CASE
        WHEN RAND() < 0.55 THEN 'Mobile Phone'                                               -- intentionally messy label
        WHEN RAND() < 0.80 THEN 'Computer'
        ELSE 'Phone'
    END                                                                 AS PreferredLoginDevice,
    CASE
        WHEN RAND() < 0.45 THEN 1
        WHEN RAND() < 0.65 THEN 2
        ELSE 3
    END                                                                 AS CityTier,
    ROUND(5 + RAND() * 30, 0)                                           AS WarehouseToHome,
    CASE
        WHEN RAND() < 0.17 THEN 'Credit Card'
        WHEN RAND() < 0.34 THEN 'Debit Card'
        WHEN RAND() < 0.51 THEN 'E wallet'
        WHEN RAND() < 0.68 THEN 'UPI'
        WHEN RAND() < 0.84 THEN 'COD'
        ELSE 'Cash on Delivery'
    END                                                                 AS PreferredPaymentMode,
    CASE WHEN RAND() < 0.6 THEN 'Male' ELSE 'Female' END                AS Gender,
    ROUND(LEAST(GREATEST((RAND() + RAND() + RAND()) / 3 * 6, 0), 6), 1) AS HourSpendOnApp,   -- averaged randoms ~ bell curve
    FLOOR(RAND() * 6 + 1)                                               AS NumberOfDeviceRegistered,
    CASE
        WHEN RAND() < 0.17 THEN 'Laptop & Accessory'
        WHEN RAND() < 0.34 THEN 'Mobile'
        WHEN RAND() < 0.51 THEN 'Mobile Phone'
        WHEN RAND() < 0.68 THEN 'Fashion'
        WHEN RAND() < 0.84 THEN 'Grocery'
        ELSE 'Others'
    END                                                                 AS PreferedOrderCat,
    FLOOR(RAND() * 5 + 1)                                               AS SatisfactionScore,
    CASE
        WHEN RAND() < 0.35 THEN 'Single'
        WHEN RAND() < 0.70 THEN 'Married'
        ELSE 'Divorced'
    END                                                                 AS MaritalStatus,
    FLOOR(RAND() * 8 + 1)                                               AS NumberOfAddress,
    CASE WHEN RAND() < 0.28 THEN 1 ELSE 0 END                           AS Complain,
    ROUND(11 + RAND() * 14, 0)                                          AS OrderAmountHikeFromlastYear,
    FLOOR(RAND() * 8)                                                   AS CouponUsed,
    FLOOR(RAND() * 9 + 1)                                               AS OrderCount,
    FLOOR(RAND() * 16)                                                  AS DaySinceLastOrder,
    ROUND(LEAST(GREATEST(180 + (RAND() - 0.5) * 240, 20), 400), 2)      AS CashbackAmount
FROM seq_numbers;

/* --------------------------------------------------------------------------
   STEP 3 — Compute Churn from a weighted probability score built out of
   the attributes above (higher score = higher chance of churning), so the
   dataset has realistic, explainable correlations instead of pure noise.
   -------------------------------------------------------------------------- */
UPDATE customer_churn_data
SET Churn = CASE
    WHEN RAND() < (
        0.03
        + CASE
            WHEN Tenure <= 6  THEN 0.22
            WHEN Tenure <= 12 THEN 0.13
            WHEN Tenure <= 24 THEN 0.06
            ELSE 0.01
          END
        + CASE WHEN Complain = 1 THEN 0.10 ELSE 0 END
        + CASE WHEN CityTier = 3 THEN 0.04 ELSE 0 END
        + CASE WHEN MaritalStatus = 'Single' THEN 0.05 ELSE 0 END
        + (NumberOfDeviceRegistered * 0.010)
        + (WarehouseToHome * 0.0015)
        + (DaySinceLastOrder * 0.004)
        - CASE WHEN CashbackAmount > 200 THEN 0.03 ELSE 0 END
    )
    THEN 1
    ELSE 0
END;

/* --------------------------------------------------------------------------
   STEP 4 — Introduce the messy-data artifacts the cleaning script expects:
   a few TRUE duplicate rows (same CustomerID, different RowID), some
   missing values, and a handful of outlier WarehouseToHome entries
   (simulating a data-entry typo).

   Note: MySQL won't let an UPDATE/DELETE target the same table it's
   selecting FROM in a plain subquery ("can't specify target table for
   update in FROM clause"). Wrapping each subquery in an extra derived
   table (SELECT * FROM (...) AS x) is the standard MySQL workaround used
   throughout this script.
   -------------------------------------------------------------------------- */

-- 4.1 Duplicate 15 existing customers, keeping their SAME CustomerID so
--     Part 1 of the cleaning script has genuine duplicates to detect.
INSERT INTO customer_churn_data (
    CustomerID, Tenure, PreferredLoginDevice, CityTier, WarehouseToHome,
    PreferredPaymentMode, Gender, HourSpendOnApp, NumberOfDeviceRegistered,
    PreferedOrderCat, SatisfactionScore, MaritalStatus, NumberOfAddress,
    Complain, OrderAmountHikeFromlastYear, CouponUsed, OrderCount,
    DaySinceLastOrder, CashbackAmount, Churn
)
SELECT
    CustomerID, Tenure, PreferredLoginDevice, CityTier, WarehouseToHome,
    PreferredPaymentMode, Gender, HourSpendOnApp, NumberOfDeviceRegistered,
    PreferedOrderCat, SatisfactionScore, MaritalStatus, NumberOfAddress,
    Complain, OrderAmountHikeFromlastYear, CouponUsed, OrderCount,
    DaySinceLastOrder, CashbackAmount, Churn
FROM (
    SELECT * FROM customer_churn_data ORDER BY RAND() LIMIT 15
) AS dupe_source;

-- 4.2 Null out a random sample of values in columns the cleaning script imputes
UPDATE customer_churn_data
SET Tenure = NULL
WHERE RowID IN (SELECT RowID FROM (SELECT RowID FROM customer_churn_data ORDER BY RAND() LIMIT 40) AS t);

UPDATE customer_churn_data
SET WarehouseToHome = NULL
WHERE RowID IN (SELECT RowID FROM (SELECT RowID FROM customer_churn_data ORDER BY RAND() LIMIT 30) AS t);

UPDATE customer_churn_data
SET HourSpendOnApp = NULL
WHERE RowID IN (SELECT RowID FROM (SELECT RowID FROM customer_churn_data ORDER BY RAND() LIMIT 25) AS t);

UPDATE customer_churn_data
SET OrderAmountHikeFromlastYear = NULL
WHERE RowID IN (SELECT RowID FROM (SELECT RowID FROM customer_churn_data ORDER BY RAND() LIMIT 25) AS t);

UPDATE customer_churn_data
SET CouponUsed = NULL
WHERE RowID IN (SELECT RowID FROM (SELECT RowID FROM customer_churn_data ORDER BY RAND() LIMIT 20) AS t);

UPDATE customer_churn_data
SET OrderCount = NULL
WHERE RowID IN (SELECT RowID FROM (SELECT RowID FROM customer_churn_data ORDER BY RAND() LIMIT 20) AS t);

UPDATE customer_churn_data
SET DaySinceLastOrder = NULL
WHERE RowID IN (SELECT RowID FROM (SELECT RowID FROM customer_churn_data ORDER BY RAND() LIMIT 20) AS t);

-- 4.3 Inject outlier WarehouseToHome values (typo: stray leading "1")
UPDATE customer_churn_data
SET WarehouseToHome = WarehouseToHome + 100
WHERE RowID IN (SELECT RowID FROM (SELECT RowID FROM customer_churn_data ORDER BY RAND() LIMIT 12) AS t);

-- 4.4 Guarantee at least a few rows carry the "messy" category labels the
--     standardization step in the cleaning script is designed to fix
--     (some rows already get these naturally from Step 2's random draw).
UPDATE customer_churn_data
SET PreferredPaymentMode = 'COD'
WHERE RowID IN (
    SELECT RowID FROM (
        SELECT RowID FROM customer_churn_data
        WHERE PreferredPaymentMode = 'Cash on Delivery'
        ORDER BY RAND() LIMIT 50
    ) AS t
);

UPDATE customer_churn_data
SET PreferedOrderCat = 'Mobile'
WHERE RowID IN (
    SELECT RowID FROM (
        SELECT RowID FROM customer_churn_data
        WHERE PreferedOrderCat = 'Mobile Phone'
        ORDER BY RAND() LIMIT 50
    ) AS t
);

-- Sanity check
SELECT COUNT(*) AS TotalRows, SUM(Churn) AS TotalChurned FROM customer_churn_data;
