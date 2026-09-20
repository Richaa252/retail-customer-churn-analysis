
Retail Customer Retention & Churn Analysis

📌 Project Overview

This project analyzes customer churn and retention patterns for a retail/e-commerce business using MySQL.

The project focuses on transforming raw customer-level data into meaningful business insights by:

Cleaning duplicate and inconsistent records

Handling missing values

Correcting data-entry errors

Standardizing categorical values

Calculating overall and segment-wise churn rates

Exploring customer behavior across multiple dimensions

Identifying high-risk customer segments

Creating a rule-based customer RiskTier

Note: The customer dataset used in this project is synthetically generated. Therefore, the observed relationships describe the patterns intentionally created in this dataset and should not be interpreted as proof of real-world causation.

 Business Objective

Customer churn is an important problem for retail businesses because losing existing customers can affect revenue and long-term customer relationships.

The main objective of this project is to answer:

Which types of customers are more likely to churn, and how can customers be segmented based on their potential churn risk?

The analysis investigates factors such as:

Customer tenure

City tier

Warehouse-to-home distance

Preferred payment mode

Login device

Number of registered devices

Order category

Satisfaction score

Marital status

Complaint history

Coupon usage

Days since last order

Cashback amount

 Tools & Technologies

MySQL 8.0+

SQL

Aggregate Functions

GROUP BY

HAVING

CASE

JOIN

Self Join

UPDATE

DELETE

ALTER TABLE

UNION ALL

NULL handling

Data cleaning

Customer segmentation

 Project Structure

Retail-Customer-Retention-Churn-Analysis/
│
├── 01_generate_data.sql
├── 02_cleaning_analysis.sql
└── README.md

Script 1 — 01_generate_data.sql

Creates and populates the customer churn dataset with 4,200 synthetic customer records.

The script also introduces realistic data-quality issues such as:

Duplicate CustomerIDs

Missing numeric values

Category inconsistencies

Warehouse-to-home distance outliers/data-entry errors

It also generates the binary Churn variable.

Script 2 — 02_cleaning_analysis.sql

Performs:

Data cleaning

Missing-value treatment

Category standardization

Outlier/data-entry correction

Exploratory business analysis

Customer segmentation

Risk-tier classification

 Data Cleaning

1. Duplicate Detection and Removal

Duplicate customers are identified using:

GROUP BY CustomerID
HAVING COUNT(*) > 1

Duplicate records are removed using a self-join while retaining the record with the lowest RowID.

RowID acts as a surrogate key that allows duplicate CustomerIDs to be distinguished.

2. Missing Value Treatment

NULL values are checked in important numeric columns such as:

Tenure

WarehouseToHome

HourSpendOnApp

OrderAmountHikeFromlastYear

CouponUsed

OrderCount

DaySinceLastOrder

For this project, missing numeric values are replaced using column mean imputation.

Example:

Values: 10, 20, NULL, 30

Mean = (10 + 20 + 30) / 3
     = 20

NULL → 20

3. Categorical Data Standardization

Inconsistent labels are standardized so that the same category is not counted separately.

Examples:

Mobile Phone → Phone
Mobile       → Mobile Phone
COD          → Cash on Delivery

This ensures more accurate grouping and analysis.

4. Data-Entry Error Correction

The project checks unusually high WarehouseToHome values.

Based on the dataset's generation logic, values above 40 are treated as data-entry errors caused by an extra leading 1.

Example:

126 → 26

The correction is performed by subtracting 100 from affected values.

5. Readable Business Columns

Two readable columns are created from binary fields:

CustomerStatus

Churn = 1 → Churned
Churn = 0 → Stayed

ComplainReceived

Complain = 1 → Yes
Complain = 0 → No

These columns make the analysis easier to understand from a business perspective.

Churn Rate

The basic churn-rate calculation used throughout the project is:

Churn Rate (%) =
Churned Customers / Total Customers × 100

Since Churn is binary:

1 = Churned
0 = Stayed

SUM(Churn) gives the number of churned customers.

For example:

Total Customers = 1,000
Churned Customers = 150

Churn Rate = 150 / 1,000 × 100
           = 15%

 Business Questions

The project answers 19 business questions.

Q1. What is the overall churn rate?

Calculates:

Total customers

Churned customers

Overall churn percentage

Q2. How does churn vary by preferred login device?

Compares churn across different login-device categories.

Q3. How is churn distributed across city tiers?

Compares churn rates for:

Tier 1

Tier 2

Tier 3

Q4. Does warehouse-to-home distance relate to churn?

Customers are segmented into:

Very Close  → ≤10
Close       → 11–20
Moderate    → 21–30
Far         → >30

Churn rates are then compared across distance groups.

Q5. Which payment mode has the highest churn rate?

Compares churn across different payment modes.

Note: The SQL query orders results by ChurnRatePct, so it identifies the payment mode with the highest churn rate, rather than necessarily the largest absolute number of churned customers.

Q6. What tenure range sees the most churn?

Customers are grouped into:

0–6 Months
7–12 Months
1–2 Years
Over 2 Years

This helps identify whether churn is concentrated among newer or older customers.

Q7. Is there a churn gap between genders?

Compares churn rates across gender categories.

Q8. Does average app usage differ between churned and retained customers?

Compares:

Churned → Average hours spent on app
Stayed  → Average hours spent on app

Q9. Does the number of registered devices relate to churn?

Calculates churn rate for different numbers of registered devices.

Q10. Which order category has the highest churn rate?

Compares churn across different order categories.

Q11. How does satisfaction score relate to churn?

Compares churn rates across satisfaction scores.

Q12. Does marital status relate to churn?

Compares churn rates among:

Single

Married

Divorced

Q13. How many addresses do churned vs. retained customers have on average?

Compares average addresses stored for:

Churned customers

Stayed customers

Q14. Do complaints relate to churn behavior?

Compares churn between customers who:

Filed a complaint
Did not file a complaint

This is one of the stronger churn signals intentionally incorporated into the synthetic churn-generation logic.

Q15. How does coupon usage differ between churned and retained customers?

Calculates total coupon usage by customer status.

The current query calculates total coupon usage, not average coupon usage per customer.

Q16. What is the average days-since-last-order for churned customers?

Calculates the average DaySinceLastOrder only for customers classified as churned.

Q17. Is cashback amount related to churn?

Customers are divided into:

Low         → ≤100
Moderate    → 101–200
High        → 201–300
Very High   → >300

Churn rates are compared across cashback ranges.

🎯 Risk Segmentation

Q18. Which combination of tenure and complaint history has the highest churn rate?

Instead of studying tenure and complaints separately, the project studies their combination.

For example:

0–6 Months + Complaint = Yes
0–6 Months + Complaint = No
7–12 Months + Complaint = Yes
7–12 Months + Complaint = No
...

This helps identify higher-risk customer combinations.

🚦 Q19. Rule-Based Customer RiskTier

A final RiskTier column is created using business rules.

Critical

Tenure ≤ 6 months
AND
Complaint = Yes

High

Tenure ≤ 6 months
OR
Complaint = Yes

Medium

DaySinceLastOrder > 10
OR
WarehouseToHomeRange = Far (>30)

Low

All remaining customers.

Risk hierarchy

Critical
   ↓
High
   ↓
Medium
   ↓
Low

The purpose is to convert multiple customer signals into a simple business-friendly risk segment.

RiskTier is rule-based segmentation, not a machine-learning model.

Key Analytical Patterns

Because the dataset is synthetically generated, several patterns are intentionally built into the churn-generation logic.

Expected patterns include:

Higher churn probability among customers with shorter tenure

Higher churn probability among customers who filed complaints

Some increase in churn for City Tier 3

Higher churn probability with greater warehouse-to-home distance

Higher churn probability with more registered devices

Higher churn probability with more days since the last order

Slightly lower churn probability for cashback above a specified threshold

Higher churn probability for the Single marital-status group

Other variables such as login device, gender, app usage, satisfaction score, order category and payment mode were not directly wired into the synthetic churn formula, so strong relationships are not intentionally expected from those variables.

 Business Interpretation

The analysis can help a business move from:

Raw Customer Data
        ↓
Data Cleaning
        ↓
Churn Analysis
        ↓
Customer Segmentation
        ↓
Risk Identification
        ↓
Retention Strategy

For example, a customer classified as Critical based on the project rules has:

Short tenure
+
Complaint history

Such customers can be prioritized for further retention analysis or customer-service intervention.

The project therefore demonstrates how SQL can transform raw customer-level data into business-oriented customer segments and churn insights.

 Important SQL Concepts Demonstrated

Data Cleaning

Duplicate detection

Duplicate removal

NULL detection

Mean imputation

Category standardization

Data-entry error correction

SQL

SELECT

WHERE

GROUP BY

HAVING

ORDER BY

COUNT()

SUM()

AVG()

CASE

JOIN

Self Join

UPDATE

DELETE

ALTER TABLE

UNION ALL

IS NULL

Type casting

Analytics

Churn rate calculation

Customer segmentation

Group-wise analysis

Interaction analysis

Rule-based risk classification

 Important Project Limitation

This project uses synthetically generated data.

The churn variable was generated using predefined rules and weighted factors. Therefore:

The relationships found in the analysis are specific to this generated dataset.

They should not be interpreted as causal relationships in a real customer population.

A real-world churn project would require validated business data and additional statistical/modeling techniques.

 Interview Explanation

Short Version

"I built a Retail Customer Retention and Churn Analysis project using MySQL. I first cleaned the customer dataset by handling duplicates, missing values, inconsistent categories and data-entry errors. Then I analyzed churn rates across different customer segments such as tenure, complaints, city tier, distance, devices and customer behavior. Finally, I created a rule-based RiskTier that classified customers into Critical, High, Medium and Low risk based on selected churn signals."

One-Line Version

"The project converts raw customer data into clean, segment-wise churn insights and rule-based customer risk categories using SQL."

 How to Run

Open MySQL 8.0+.

Run:

01_generate_data.sql

Then run:

02_cleaning_analysis.sql

Review the results of the data-cleaning queries and the 19 business-analysis queries.

 Skills Demonstrated

SQL | MySQL | Data Cleaning | Exploratory Data Analysis | Customer Segmentation | Churn Analysis | Business Analytics | Risk Segmentation

 Project Takeaway

This project demonstrates the complete SQL analytics workflow:

Generate Data
     ↓
Clean Data
     ↓
Validate Data
     ↓
Explore Customer Behavior
     ↓
Calculate Churn
     ↓
Identify Patterns
     ↓
Segment Customers
     ↓
Create Risk Tiers
     ↓
Support Retention Decisions






