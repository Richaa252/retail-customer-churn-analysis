/* ==========================================================================
   RETAIL CUSTOMER RETENTION & CHURN ANALYSIS
   Script 2 of 2 — DATA CLEANING + BUSINESS-QUESTION ANALYSIS
   Written for MySQL 8.0+ syntax (uses multi-table DELETE, and derived-table
   workarounds where MySQL won't allow a subquery to reference the same
   table being updated).
   Run 01_generate_data.sql first to create and populate the
   `customer_churn_data` table this script operates on.
   ========================================================================== */

/* ==========================================================================
   PART 1 — DATA CLEANING
   ========================================================================== */

-- 1.1 Total number of customer records loaded
SELECT COUNT(*) AS TotalRows
FROM customer_churn_data;

-- 1.2 Check for duplicate CustomerIDs (the raw export shipped a handful of
--     accidental double-uploads from a warehouse export job)
SELECT CustomerID, COUNT(*) AS RecordCount
FROM customer_churn_data
GROUP BY CustomerID
HAVING COUNT(*) > 1;

-- 1.3 Remove duplicate rows, keeping the one with the lowest RowID
--     (the surrogate key created in 01_generate_data.sql — MySQL has no
--     equivalent to Postgres's ctid, so a real surrogate key is needed to
--     tell two otherwise-identical rows apart)
DELETE t1 FROM customer_churn_data t1
JOIN customer_churn_data t2
  ON t1.CustomerID = t2.CustomerID
 AND t1.RowID > t2.RowID;

-- 1.4 Count NULLs in every column that can legitimately contain them
SELECT 'Tenure' AS ColumnName, COUNT(*) AS NullCount FROM customer_churn_data WHERE Tenure IS NULL
UNION ALL
SELECT 'WarehouseToHome', COUNT(*) FROM customer_churn_data WHERE WarehouseToHome IS NULL
UNION ALL
SELECT 'HourSpendOnApp', COUNT(*) FROM customer_churn_data WHERE HourSpendOnApp IS NULL
UNION ALL
SELECT 'OrderAmountHikeFromlastYear', COUNT(*) FROM customer_churn_data WHERE OrderAmountHikeFromlastYear IS NULL
UNION ALL
SELECT 'CouponUsed', COUNT(*) FROM customer_churn_data WHERE CouponUsed IS NULL
UNION ALL
SELECT 'OrderCount', COUNT(*) FROM customer_churn_data WHERE OrderCount IS NULL
UNION ALL
SELECT 'DaySinceLastOrder', COUNT(*) FROM customer_churn_data WHERE DaySinceLastOrder IS NULL;

-- 1.5 Impute missing numeric values with the column mean
-- (MySQL blocks "UPDATE tbl SET col = (SELECT AVG(col) FROM tbl)" outright —
--  it won't let an UPDATE's subquery read from the same table being
--  updated. Wrapping the aggregate in an extra derived table, as below,
--  is the standard MySQL workaround.)
UPDATE customer_churn_data
SET Tenure = (SELECT avg_val FROM (SELECT AVG(Tenure) AS avg_val FROM customer_churn_data) AS t)
WHERE Tenure IS NULL;

UPDATE customer_churn_data
SET WarehouseToHome = (SELECT avg_val FROM (SELECT AVG(WarehouseToHome) AS avg_val FROM customer_churn_data) AS t)
WHERE WarehouseToHome IS NULL;

UPDATE customer_churn_data
SET HourSpendOnApp = (SELECT avg_val FROM (SELECT AVG(HourSpendOnApp) AS avg_val FROM customer_churn_data) AS t)
WHERE HourSpendOnApp IS NULL;

UPDATE customer_churn_data
SET OrderAmountHikeFromlastYear = (SELECT avg_val FROM (SELECT AVG(OrderAmountHikeFromlastYear) AS avg_val FROM customer_churn_data) AS t)
WHERE OrderAmountHikeFromlastYear IS NULL;

UPDATE customer_churn_data
SET CouponUsed = (SELECT avg_val FROM (SELECT AVG(CouponUsed) AS avg_val FROM customer_churn_data) AS t)
WHERE CouponUsed IS NULL;

UPDATE customer_churn_data
SET OrderCount = (SELECT avg_val FROM (SELECT AVG(OrderCount) AS avg_val FROM customer_churn_data) AS t)
WHERE OrderCount IS NULL;

UPDATE customer_churn_data
SET DaySinceLastOrder = (SELECT avg_val FROM (SELECT AVG(DaySinceLastOrder) AS avg_val FROM customer_churn_data) AS t)
WHERE DaySinceLastOrder IS NULL;

-- 1.6 Standardize inconsistent category labels
-- "Mobile Phone" and "Phone" refer to the same login device
UPDATE customer_churn_data
SET PreferredLoginDevice = 'Phone'
WHERE PreferredLoginDevice = 'Mobile Phone';

-- "Mobile" and "Mobile Phone" refer to the same order category
UPDATE customer_churn_data
SET PreferedOrderCat = 'Mobile Phone'
WHERE PreferedOrderCat = 'Mobile';

-- "COD" and "Cash on Delivery" refer to the same payment mode
UPDATE customer_churn_data
SET PreferredPaymentMode = 'Cash on Delivery'
WHERE PreferredPaymentMode = 'COD';

-- 1.7 Fix outlier data-entry errors in WarehouseToHome (values > 40 miles
--     turned out to be a stray leading "1" typo, e.g. 126 -> 26)
SELECT DISTINCT WarehouseToHome
FROM customer_churn_data
WHERE WarehouseToHome > 40
ORDER BY WarehouseToHome;

UPDATE customer_churn_data
SET WarehouseToHome = WarehouseToHome - 100
WHERE WarehouseToHome > 40;

-- 1.8 Add a readable CustomerStatus column from the binary Churn flag
ALTER TABLE customer_churn_data ADD COLUMN CustomerStatus VARCHAR(10);

UPDATE customer_churn_data
SET CustomerStatus = CASE
    WHEN Churn = 1 THEN 'Churned'
    WHEN Churn = 0 THEN 'Stayed'
END;

-- 1.9 Add a readable ComplainReceived column from the binary Complain flag
ALTER TABLE customer_churn_data ADD COLUMN ComplainReceived VARCHAR(5);

UPDATE customer_churn_data
SET ComplainReceived = CASE
    WHEN Complain = 1 THEN 'Yes'
    WHEN Complain = 0 THEN 'No'
END;

/* ==========================================================================
   PART 2 — EXPLORATORY ANALYSIS: BUSINESS QUESTIONS
   ========================================================================== */

-- Q1. What is the overall churn rate?
SELECT
    COUNT(*)                                                         AS TotalCustomers,
    SUM(Churn)                                                       AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2))          AS ChurnRatePct
FROM customer_churn_data;
-- Expected pattern: overall churn rate should land in the mid-teens (percent range)

-- Q2. How does churn vary by preferred login device?
SELECT
    PreferredLoginDevice,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY PreferredLoginDevice
ORDER BY ChurnRatePct DESC;
-- Expected pattern: login device alone shouldn't show a strong split, since
--         PreferredLoginDevice isn't wired into the churn formula

-- Q3. How is churn distributed across city tiers?
SELECT
    CityTier,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY CityTier
ORDER BY ChurnRatePct DESC;
-- Expected pattern: Tier-3 cities churn somewhat more than Tier-1/2, since
--         CityTier = 3 adds a small positive weight in the churn formula

-- Q4. Does warehouse-to-home distance correlate with churn?
ALTER TABLE customer_churn_data ADD COLUMN WarehouseToHomeRange VARCHAR(30);

UPDATE customer_churn_data
SET WarehouseToHomeRange = CASE
    WHEN WarehouseToHome <= 10 THEN 'Very Close (<=10)'
    WHEN WarehouseToHome <= 20 THEN 'Close (11-20)'
    WHEN WarehouseToHome <= 30 THEN 'Moderate (21-30)'
    ELSE 'Far (>30)'
END;

SELECT
    WarehouseToHomeRange,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY WarehouseToHomeRange
ORDER BY ChurnRatePct DESC;
-- Expected pattern: churn rises steadily as WarehouseToHome increases, since
--         distance carries a small positive weight per mile in the formula

-- Q5. Which payment mode is most common among churned customers?
SELECT
    PreferredPaymentMode,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY PreferredPaymentMode
ORDER BY ChurnRatePct DESC;
-- Expected pattern: payment mode differences should be modest, since payment
--         mode isn't wired into the churn formula

-- Q6. What tenure range sees the most churn?
ALTER TABLE customer_churn_data ADD COLUMN TenureRange VARCHAR(20);

UPDATE customer_churn_data
SET TenureRange = CASE
    WHEN Tenure <= 6  THEN '0-6 Months'
    WHEN Tenure <= 12 THEN '7-12 Months'
    WHEN Tenure <= 24 THEN '1-2 Years'
    ELSE 'Over 2 Years'
END;

SELECT
    TenureRange,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY TenureRange
ORDER BY ChurnRatePct DESC;
-- Expected pattern: churn should be heavily front-loaded in early tenure,
--         dropping off sharply for customers with 2+ years of history

-- Q7. Is there a churn gap between genders?
SELECT
    Gender,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY Gender
ORDER BY ChurnRatePct DESC;
-- Expected pattern: only a small gap between genders, since Gender isn't
--         wired into the churn formula

-- Q8. Does average app usage differ between churned and retained customers?
SELECT
    CustomerStatus,
    CAST(AVG(HourSpendOnApp) AS DECIMAL(5,2)) AS AvgHoursOnApp
FROM customer_churn_data
GROUP BY CustomerStatus;
-- Expected pattern: near-identical averages, since HourSpendOnApp isn't
--         wired into the churn formula — usage alone doesn't predict churn here

-- Q9. Does the number of registered devices affect churn likelihood?
SELECT
    NumberOfDeviceRegistered,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY NumberOfDeviceRegistered
ORDER BY NumberOfDeviceRegistered;
-- Expected pattern: churn climbs as the number of registered devices rises,
--         since device count carries a positive weight in the churn formula

-- Q10. Which order category is most popular among churned customers?
SELECT
    PreferedOrderCat,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY PreferedOrderCat
ORDER BY ChurnRatePct DESC;
-- Expected pattern: differences across order categories should be modest,
--         since PreferedOrderCat isn't wired into the churn formula

-- Q11. How does satisfaction score relate to churn?
SELECT
    SatisfactionScore,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY SatisfactionScore
ORDER BY ChurnRatePct DESC;
-- Expected pattern: little to no clean trend, since SatisfactionScore isn't
--         wired into the churn formula — a reminder that satisfaction surveys
--         alone can mislead

-- Q12. Does marital status influence churn?
SELECT
    MaritalStatus,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY MaritalStatus
ORDER BY ChurnRatePct DESC;
-- Expected pattern: Single customers churn more than Married/Divorced, since
--         MaritalStatus = 'Single' adds a small positive weight in the formula

-- Q13. How many addresses do churned vs. retained customers have on average?
SELECT
    CustomerStatus,
    CAST(AVG(NumberOfAddress) AS DECIMAL(5,2)) AS AvgAddressesOnFile
FROM customer_churn_data
GROUP BY CustomerStatus;
-- Expected pattern: near-identical averages, since NumberOfAddress isn't
--         wired into the churn formula

-- Q14. Do complaints influence churn behavior?
SELECT
    ComplainReceived,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY ComplainReceived
ORDER BY ChurnRatePct DESC;
-- Expected pattern: customers who filed a complaint churn noticeably more,
--         since Complain carries one of the largest weights in the formula

-- Q15. How does coupon usage differ between churned and retained customers?
SELECT
    CustomerStatus,
    SUM(CouponUsed) AS TotalCouponsUsed
FROM customer_churn_data
GROUP BY CustomerStatus;
-- Expected pattern: no strong built-in relationship here — CouponUsed isn't
--         wired into the churn formula

-- Q16. What's the average days-since-last-order for churned customers?
SELECT
    CAST(AVG(DaySinceLastOrder) AS DECIMAL(5,2)) AS AvgDaysSinceLastOrder
FROM customer_churn_data
WHERE CustomerStatus = 'Churned';
-- Expected pattern: churned customers show a somewhat higher average, since
--         DaySinceLastOrder carries a small positive weight in the formula

-- Q17. Is there a relationship between cashback amount and churn?
ALTER TABLE customer_churn_data ADD COLUMN CashbackRange VARCHAR(30);

UPDATE customer_churn_data
SET CashbackRange = CASE
    WHEN CashbackAmount <= 100 THEN 'Low (<=100)'
    WHEN CashbackAmount <= 200 THEN 'Moderate (101-200)'
    WHEN CashbackAmount <= 300 THEN 'High (201-300)'
    ELSE 'Very High (>300)'
END;

SELECT
    CashbackRange,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY CashbackRange
ORDER BY ChurnRatePct DESC;
-- Expected pattern: customers with cashback over 200 churn somewhat less,
--         since the formula applies a small negative weight above that threshold

/* ==========================================================================
   PART 3 — RISK SEGMENTATION (bonus queries beyond the standard question set)
   ========================================================================== */

-- Q18. Which combination of tenure and complaint history carries the
--      highest churn rate? (interaction effect, not just each factor alone)
SELECT
    TenureRange,
    ComplainReceived,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY TenureRange, ComplainReceived
ORDER BY ChurnRatePct DESC;
-- Expected pattern: new customers (0-6 months) who also filed a complaint
--         should show the highest combined churn rate of any segment,
--         since both factors carry independent weight in the churn formula

-- Q19. Build a simple rule-based RiskTier label for each customer, combining
--      the strongest individual churn signals into one field the business
--      could plug straight into a retention dashboard.
ALTER TABLE customer_churn_data ADD COLUMN RiskTier VARCHAR(20);

UPDATE customer_churn_data
SET RiskTier = CASE
    WHEN Tenure <= 6 AND ComplainReceived = 'Yes'                THEN 'Critical'
    WHEN Tenure <= 6 OR ComplainReceived = 'Yes'                 THEN 'High'
    WHEN DaySinceLastOrder > 10 OR WarehouseToHomeRange = 'Far (>30)' THEN 'Medium'
    ELSE 'Low'
END;

SELECT
    RiskTier,
    COUNT(*)                                                AS TotalCustomers,
    SUM(Churn)                                              AS ChurnedCustomers,
    CAST(SUM(Churn) * 1.0 / COUNT(*) * 100 AS DECIMAL(5,2)) AS ChurnRatePct
FROM customer_churn_data
GROUP BY RiskTier
ORDER BY
    CASE RiskTier
        WHEN 'Critical' THEN 1
        WHEN 'High'     THEN 2
        WHEN 'Medium'   THEN 3
        ELSE 4
    END;
-- Expected pattern: churn rate should decrease cleanly from Critical -> Low,
--         confirming the rule-based tiers track real risk and could be
--         handed to a retention/marketing team as-is
