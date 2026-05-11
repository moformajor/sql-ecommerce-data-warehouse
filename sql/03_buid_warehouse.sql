-- =====================================================
-- PROJECT 1: OLIST SQL E-COMMERCE DATA WAREHOUSE
-- DAY 3: CONVERT RAW TABLES TO CLEAN WAREHOUSE TABLES
-- Database: MySQL
-- =====================================================

/*
DAY 3 PURPOSE
-------------

Raw tables currently contain data imported directly from CSV files.

Raw tables:
raw_olist_orders
raw_olist_order_items
raw_olist_customers
raw_olist_products

Clean warehouse tables to create:
dim_customers
dim_products
dim_date
fact_orders

Why we are doing this:
- Raw tables are mostly TEXT.
- Missing values are stored as empty strings ('').
- Dates are stored as text.
- Numeric values are stored as text.
- We need clean tables for reliable analysis.

Main Day 3 outcome:
Build clean dimension and fact tables ready for KPI analysis.
*/


-- =====================================================
-- STEP 1: SELECT DATABASE
-- =====================================================

/*
Why:
MySQL needs to know which database we are working inside.
*/

USE olist_dw;


-- =====================================================
-- STEP 2: CREATE CLEAN CUSTOMER DIMENSION
-- =====================================================

/*
Why:
dim_customers stores descriptive customer information.

This table helps answer questions like:
- Where are customers located?
- Which states have the most customers?
- Which customer_unique_id represents repeat customers?

Important:
customer_id = order-level customer identifier
customer_unique_id = real customer identity across orders
*/

DROP TABLE IF EXISTS dim_customers;

CREATE TABLE dim_customers AS
SELECT
    TRIM(customer_id) AS customer_id,
    TRIM(customer_unique_id) AS customer_unique_id,
    TRIM(customer_state) AS customer_state,
    TRIM(customer_city) AS customer_city,
    TRIM(customer_zip_code_prefix) AS customer_zip_code_prefix
FROM raw_olist_customers;


-- Check customer dimension

SELECT *
FROM dim_customers
LIMIT 100;

SELECT COUNT(*) AS dim_customers_count
FROM dim_customers;


-- Check duplicate customer_id

SELECT
    customer_id,
    COUNT(*) AS row_count
FROM dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- =====================================================
-- STEP 3: CREATE CLEAN PRODUCT DIMENSION
-- =====================================================

/*
Why:
dim_products stores descriptive product information.

This table helps answer:
- Which product categories sell the most?
- Which products generate the most revenue?
- Which product fields have missing information?

Cleaning rules:
- TRIM() removes unwanted spaces.
- NULLIF(value, '') converts empty strings to real NULL.
- CAST() converts text values into proper numeric data types.
*/

DROP TABLE IF EXISTS dim_products;

CREATE TABLE dim_products AS
SELECT
    TRIM(product_id) AS product_id,

    NULLIF(TRIM(product_category_name), '') AS product_category_name,

    CAST(NULLIF(TRIM(product_name_length), '') AS UNSIGNED) AS product_name_length,
    CAST(NULLIF(TRIM(product_description_length), '') AS UNSIGNED) AS product_description_length,
    CAST(NULLIF(TRIM(product_photos_qty), '') AS UNSIGNED) AS product_photos_qty,

    CAST(NULLIF(TRIM(product_weight_g), '') AS DECIMAL(10,2)) AS product_weight_g,
    CAST(NULLIF(TRIM(product_length_cm), '') AS DECIMAL(10,2)) AS product_length_cm,
    CAST(NULLIF(TRIM(product_height_cm), '') AS DECIMAL(10,2)) AS product_height_cm,
    CAST(NULLIF(TRIM(product_width_cm), '') AS DECIMAL(10,2)) AS product_width_cm

FROM raw_olist_products;


/*
Function notes:

NULLIF(product_weight_g, '')
- If product_weight_g is empty, convert it to NULL.
- Otherwise keep the original value.

TRIM()
- Removes unwanted spaces before and after a value.

CAST()
- Converts one datatype into another datatype.
- Example: text to integer, decimal, date, etc.

DECIMAL(10,2)
- 10 total digits.
- 2 digits after the decimal point.
*/


-- Check product dimension

SELECT *
FROM dim_products
LIMIT 100;


-- Check missing values after cleaning

SELECT
    COUNT(*) AS total_products,
    SUM(product_category_name IS NULL) AS null_category,
    SUM(product_weight_g IS NULL) AS null_weight,
    SUM(product_length_cm IS NULL) AS null_length,
    SUM(product_height_cm IS NULL) AS null_height,
    SUM(product_width_cm IS NULL) AS null_width
FROM dim_products;


-- Check duplicate product_id

SELECT
    product_id,
    COUNT(*) AS row_count
FROM dim_products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- =====================================================
-- STEP 4: CREATE DATE DIMENSION
-- =====================================================

/*
Why:
dim_date helps analyze orders by time.

It helps answer:
- Revenue by year
- Orders by month
- Sales by quarter
- Busiest day of week
- Trend over time

Important:
Your imported date format appears to be:
%d/%m/%Y %H:%i

Example:
23/01/2018 10:32

So we use:
STR_TO_DATE(value, '%d/%m/%Y %H:%i')
*/

DROP TABLE IF EXISTS dim_date;

CREATE TABLE dim_date AS
SELECT DISTINCT
    DATE(parsed_ts) AS date_key,
    YEAR(parsed_ts) AS year,
    QUARTER(parsed_ts) AS quarter,
    MONTH(parsed_ts) AS month,
    MONTHNAME(parsed_ts) AS month_name,
    DAY(parsed_ts) AS day,
    DAYNAME(parsed_ts) AS day_name,
    DAYOFWEEK(parsed_ts) AS day_of_week
FROM (
    SELECT 
        STR_TO_DATE(
            NULLIF(TRIM(order_purchase_timestamp), ''),
            '%d/%m/%Y %H:%i'
        ) AS parsed_ts
    FROM raw_olist_orders
) temp_table
WHERE parsed_ts IS NOT NULL;


-- Check date dimension

SELECT *
FROM dim_date
ORDER BY date_key
LIMIT 100;

SELECT COUNT(*) AS dim_date_count
FROM dim_date;


-- Check date range

SELECT
    MIN(date_key) AS first_date,
    MAX(date_key) AS last_date
FROM dim_date;


-- =====================================================
-- STEP 5: TEST ORDER-LEVEL REVENUE
-- =====================================================

/*
Why:
Revenue is stored in raw_olist_order_items.

But raw_olist_order_items has multiple rows per order.

Our final fact_orders table should have:
one row per order_id

So before creating fact_orders, we first test revenue aggregation.

Revenue formula:
revenue = price + freight_value
*/

SELECT
    order_id,
    COUNT(*) AS total_items,
    SUM(CAST(NULLIF(TRIM(price), '') AS DECIMAL(10,2))) AS product_revenue,
    SUM(CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(10,2))) AS freight_revenue,
    SUM(
        CAST(NULLIF(TRIM(price), '') AS DECIMAL(10,2)) +
        CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(10,2))
    ) AS total_revenue
FROM raw_olist_order_items
GROUP BY order_id
LIMIT 10;


-- =====================================================
-- STEP 6: CREATE FACT_ORDERS
-- =====================================================

/*
Why:
A fact table stores measurable business events.

For this project:
Business event = an order was placed.

Grain:
fact_orders = one row per order_id

This supports:
- revenue
- AOV
- repeat customer analysis
- retention
- RFM analysis

Why LEFT JOIN:
We want to keep all orders from raw_olist_orders,
even if an order has no matching item record.

Why COALESCE:
If revenue is missing after the join, convert NULL to 0.
*/

DROP TABLE IF EXISTS fact_orders;

CREATE TABLE fact_orders AS
SELECT
    TRIM(o.order_id) AS order_id,
    TRIM(o.customer_id) AS customer_id,

    DATE(
        STR_TO_DATE(
            NULLIF(TRIM(o.order_purchase_timestamp), ''),
            '%d/%m/%Y %H:%i'
        )
    ) AS order_date,

    TRIM(o.order_status) AS order_status,

    STR_TO_DATE(NULLIF(TRIM(o.order_purchase_timestamp), ''), '%d/%m/%Y %H:%i') AS order_purchase_timestamp,
    STR_TO_DATE(NULLIF(TRIM(o.order_approved_at), ''), '%d/%m/%Y %H:%i') AS order_approved_at,
    STR_TO_DATE(NULLIF(TRIM(o.order_delivered_carrier_date), ''), '%d/%m/%Y %H:%i') AS order_delivered_carrier_date,
    STR_TO_DATE(NULLIF(TRIM(o.order_delivered_customer_date), ''), '%d/%m/%Y %H:%i') AS order_delivered_customer_date,
    STR_TO_DATE(NULLIF(TRIM(o.order_estimated_delivery_date), ''), '%d/%m/%Y %H:%i') AS order_estimated_delivery_date,

    COALESCE(oi.total_items, 0) AS total_items,
    COALESCE(oi.product_revenue, 0) AS product_revenue,
    COALESCE(oi.freight_revenue, 0) AS freight_revenue,
    COALESCE(oi.total_revenue, 0) AS total_revenue

FROM raw_olist_orders o

LEFT JOIN (
    SELECT
        TRIM(order_id) AS order_id,
        COUNT(*) AS total_items,

        SUM(CAST(NULLIF(TRIM(price), '') AS DECIMAL(10,2))) AS product_revenue,

        SUM(CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(10,2))) AS freight_revenue,

        SUM(
            CAST(NULLIF(TRIM(price), '') AS DECIMAL(10,2)) +
            CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(10,2))
        ) AS total_revenue

    FROM raw_olist_order_items
    GROUP BY TRIM(order_id)
) oi
    ON TRIM(o.order_id) = oi.order_id;


-- Check fact table

SELECT *
FROM fact_orders
LIMIT 100;


-- =====================================================
-- STEP 7: VALIDATE FACT_ORDERS
-- =====================================================

/*
Why:
After building a fact table, we must prove:
- row count is correct
- no duplicate orders exist
- revenue looks reasonable
- grain is preserved
*/


-- Compare raw orders count to fact_orders count

SELECT COUNT(*) AS raw_orders_count
FROM raw_olist_orders;

SELECT COUNT(*) AS fact_orders_count
FROM fact_orders;


-- Check duplicate orders in fact_orders

SELECT
    order_id,
    COUNT(*) AS row_count
FROM fact_orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- Check total revenue

SELECT
    ROUND(SUM(product_revenue), 2) AS total_product_revenue,
    ROUND(SUM(freight_revenue), 2) AS total_freight_revenue,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM fact_orders;


-- Revenue by order status

SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(AVG(total_revenue), 5) AS avg_order_value
FROM fact_orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- Check if any order has negative revenue

SELECT *
FROM fact_orders
WHERE total_revenue < 0;


-- Check if any order has missing order_date

SELECT COUNT(*) AS missing_order_dates
FROM fact_orders
WHERE order_date IS NULL;


-- =====================================================
-- STEP 8: ADD INDEXES
-- =====================================================

/*
Why:
CREATE TABLE AS SELECT does not create primary keys or indexes.

Indexes help:
- speed up joins
- speed up filters
- make the model more professional

Note:
Because IDs came from TEXT columns, we use prefix indexes like customer_id(50).
In a later improvement, we can rebuild IDs as VARCHAR(50)
and add proper primary keys.
*/


CREATE INDEX idx_dim_customers_customer_id
ON dim_customers(customer_id(50));

CREATE INDEX idx_dim_customers_unique_customer
ON dim_customers(customer_unique_id(50));

CREATE INDEX idx_dim_products_product_id
ON dim_products(product_id(50));

CREATE INDEX idx_dim_date_date_key
ON dim_date(date_key);

CREATE INDEX idx_fact_orders_order_id
ON fact_orders(order_id(50));

CREATE INDEX idx_fact_orders_customer_id
ON fact_orders(customer_id(50));

CREATE INDEX idx_fact_orders_order_date
ON fact_orders(order_date);

CREATE INDEX idx_fact_orders_order_status
ON fact_orders(order_status(30));


-- =====================================================
-- STEP 9: TEST STAR SCHEMA JOINS
-- =====================================================

/*
Why:
A warehouse works only if fact tables can join correctly to dimensions.

Relationship:
fact_orders.customer_id → dim_customers.customer_id
*/


-- Join fact orders to customers

SELECT
    f.order_id,
    f.order_date,
    f.total_revenue,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state
FROM fact_orders f
LEFT JOIN dim_customers c
    ON f.customer_id = c.customer_id
LIMIT 10;


-- Check missing customer joins

SELECT COUNT(*) AS missing_customer_joins
FROM fact_orders f
LEFT JOIN dim_customers c
    ON f.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- Join fact orders to date dimension

SELECT
    f.order_id,
    f.order_date,
    d.year,
    d.month,
    d.month_name,
    d.day_name,
    f.total_revenue
FROM fact_orders f
LEFT JOIN dim_date d
    ON f.order_date = d.date_key
LIMIT 10;


-- Check missing date joins

SELECT COUNT(*) AS missing_date_joins
FROM fact_orders f
LEFT JOIN dim_date d
    ON f.order_date = d.date_key
WHERE d.date_key IS NULL;


-- =====================================================
-- STEP 10: FIRST KPI FROM WAREHOUSE - AOV
-- =====================================================

/*
AOV means Average Order Value.

Formula:
AOV = total revenue / number of orders

Important:
Use more decimal places when debugging.
ROUND(..., 2) can hide small differences.
*/


-- Overall AOV

SELECT
    ROUND(SUM(total_revenue) / COUNT(DISTINCT order_id), 5) AS aov
FROM fact_orders;


-- Delivered orders only AOV

SELECT
    ROUND(SUM(total_revenue) / COUNT(DISTINCT order_id), 5) AS delivered_aov
FROM fact_orders
WHERE order_status = 'delivered';


-- Compare AOV by order status

SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(AVG(total_revenue), 8) AS avg_order_value
FROM fact_orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- Compare delivered vs non-delivered

SELECT
    CASE
        WHEN order_status = 'delivered' THEN 'delivered'
        ELSE 'not_delivered'
    END AS status_group,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(AVG(total_revenue), 5) AS avg_order_value
FROM fact_orders
GROUP BY status_group;


-- =====================================================
-- STEP 11: FIRST BUSINESS SUMMARY
-- =====================================================

/*
Why:
This gives a clean executive-style summary of the warehouse.
This can later go into README or dashboard.
*/

SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(total_revenue) / COUNT(DISTINCT order_id), 2) AS aov,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM fact_orders;


-- Monthly revenue trend

SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    ROUND(SUM(f.total_revenue), 2) AS total_revenue,
    ROUND(AVG(f.total_revenue), 2) AS avg_order_value
FROM fact_orders f
LEFT JOIN dim_date d
    ON f.order_date = d.date_key
GROUP BY
    d.year,
    d.month,
    d.month_name
ORDER BY
    d.year,
    d.month;


-- Revenue by customer state

SELECT
    c.customer_state,
    COUNT(DISTINCT f.order_id) AS total_orders,
    ROUND(SUM(f.total_revenue), 2) AS total_revenue,
    ROUND(AVG(f.total_revenue), 2) AS avg_order_value
FROM fact_orders f
LEFT JOIN dim_customers c
    ON f.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- =====================================================
-- DAY 3 FINAL NOTES
-- =====================================================

/*

DAY 3 SUMMARY
-------------

Built clean warehouse tables:

1. dim_customers
   - customer descriptive table
   - supports location, repeat customer, retention, and RFM analysis

2. dim_products
   - product descriptive table
   - empty strings converted to NULL
   - numeric fields converted from TEXT to proper numeric types

3. dim_date
   - calendar/date table
   - supports time-based analysis by year, month, quarter, and weekday

4. fact_orders
   - main business event table
   - grain: one row per order_id
   - revenue aggregated from raw_olist_order_items
   - supports AOV, revenue, order count, retention, and RFM

Key SQL functions learned:

TRIM()
NULLIF()
CAST()
STR_TO_DATE()
COALESCE()
LEFT JOIN
GROUP BY
CREATE TABLE AS SELECT
ROUND()
AVG()
SUM()
COUNT(DISTINCT)

Key modeling decision:

fact_orders = one row per order_id

Reason:

This supports:
- Average Order Value
- total revenue
- repeat customer analysis
- retention analysis
- RFM segmentation

It also avoids duplicate order problems caused by using raw order_items directly.

Important data quality discovery:

The raw product table did not show SQL NULLs after import,
but it did contain missing values stored as empty strings ('').

These were cleaned in dim_products using:
NULLIF(TRIM(column_name), '')

*/
