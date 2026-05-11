/*
DAY 4 PURPOSE
-------------

Day 4 focuses on:
1. Building business KPIs
2. Advanced SQL analysis
3. Customer analytics
4. RFM analysis
5. Data quality validation
6. README preparation queries
7. Portfolio-ready outputs

Main goal:
Transform the warehouse into a professional analytics project.
*/


-- =====================================================
-- STEP 1: USE DATABASE
-- =====================================================

USE olist_dw;


-- =====================================================
-- STEP 2: GENERAL BUSINESS OVERVIEW
-- =====================================================

/*
Why:
This gives a quick executive summary of the business.

Questions answered:
- How many orders exist?
- How much revenue exists?
- What is the AOV?
- What period does the data cover?
*/

SELECT
    COUNT(DISTINCT order_id) AS total_orders,

    ROUND(SUM(total_revenue), 2) AS total_revenue,

    ROUND(
        SUM(total_revenue) /
        COUNT(DISTINCT order_id),
        2
    ) AS aov,

    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date

FROM fact_orders;


-- =====================================================
-- STEP 3: REVENUE BY ORDER STATUS
-- =====================================================

/*
Why:
Not all orders are completed.

This helps understand:
- delivered orders
- canceled orders
- processing orders
- unavailable orders

Business insight:
Most revenue should come from delivered orders.
*/

SELECT
    order_status,

    COUNT(*) AS total_orders,

    ROUND(SUM(total_revenue), 2) AS total_revenue,

    ROUND(AVG(total_revenue), 5) AS avg_order_value

FROM fact_orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- =====================================================
-- STEP 4: MONTHLY REVENUE TREND
-- =====================================================

/*
Why:
Businesses track trends over time.

Questions answered:
- Which months generated the most revenue?
- Was the business growing?
- Which months were weak?
*/

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


-- =====================================================
-- STEP 5: TOP CUSTOMER STATES
-- =====================================================

/*
Why:
Location analysis helps businesses understand:
- strongest markets
- customer concentration
- regional performance
*/

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
-- STEP 6: TOP PRODUCT CATEGORIES
-- =====================================================

/*
Why:
Businesses need to know:
- best-selling categories
- strongest revenue generators
- product performance

Important:
fact_orders is order-level,
so we must use raw_olist_order_items
to analyze product-level data.
*/

SELECT
    p.product_category_name,

    COUNT(*) AS total_items_sold,

    ROUND(
        SUM(
            CAST(NULLIF(TRIM(oi.price), '') AS DECIMAL(10,2))
        ),
        2
    ) AS total_product_revenue

FROM raw_olist_order_items oi

LEFT JOIN dim_products p
    ON TRIM(oi.product_id) = p.product_id

GROUP BY p.product_category_name
ORDER BY total_product_revenue DESC
LIMIT 20;


-- =====================================================
-- STEP 7: TOP CUSTOMERS BY REVENUE
-- =====================================================

/*
Why:
Customer ranking helps identify:
- high-value customers
- repeat buyers
- VIP customers
*/

SELECT
    c.customer_unique_id,

    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.total_revenue), 2) AS total_revenue,

    ROUND(AVG(f.total_revenue), 2) AS avg_order_value

FROM fact_orders f

LEFT JOIN dim_customers c
    ON f.customer_id = c.customer_id

GROUP BY c.customer_unique_id
ORDER BY total_revenue DESC
LIMIT 20;


-- =====================================================
-- STEP 8: REPEAT CUSTOMER RATE
-- =====================================================

/*
Why:
Repeat customers are extremely important.

Formula:
customers with more than one order
/
total customers
*/

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT f.order_id) AS total_orders
    FROM fact_orders f

    LEFT JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS total_customers,

    SUM(total_orders > 1) AS repeat_customers,

    ROUND(
        100 * SUM(total_orders > 1) / COUNT(*),
        2
    ) AS repeat_customer_rate_pct

FROM customer_orders;


-- =====================================================
-- STEP 9: CUSTOMER RETENTION ANALYSIS
-- =====================================================

/*
Why:
Retention measures whether customers come back.

Simple retention logic:
Customers with multiple purchases
are considered retained customers.
*/

SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,

    COUNT(*) AS total_customers

FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT f.order_id) AS total_orders
    FROM fact_orders f

    LEFT JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY c.customer_unique_id
) customer_summary

GROUP BY customer_type;


-- =====================================================
-- STEP 10: RFM ANALYSIS
-- =====================================================

/*
RFM = Recency, Frequency, Monetary

Why:
One of the most important customer analytics techniques.

Measures:
R = How recently customer purchased
F = How often customer purchased
M = How much customer spent
*/

WITH customer_rfm AS (

    SELECT
        c.customer_unique_id,

        MAX(f.order_date) AS last_order_date,

        DATEDIFF(
            (SELECT MAX(order_date) FROM fact_orders),
            MAX(f.order_date)
        ) AS recency_days,

        COUNT(DISTINCT f.order_id) AS frequency,

        ROUND(SUM(f.total_revenue), 2) AS monetary

    FROM fact_orders f

    LEFT JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY c.customer_unique_id
)

SELECT *
FROM customer_rfm
ORDER BY monetary DESC
LIMIT 20;


-- =====================================================
-- STEP 11: ADVANCED RFM SEGMENTATION
-- =====================================================

/*
Why:
Businesses classify customers into groups.

Examples:
- Champions
- Loyal Customers
- At Risk
- Big Spenders
*/

WITH customer_rfm AS (

    SELECT
        c.customer_unique_id,

        DATEDIFF(
            (SELECT MAX(order_date) FROM fact_orders),
            MAX(f.order_date)
        ) AS recency_days,

        COUNT(DISTINCT f.order_id) AS frequency,

        ROUND(SUM(f.total_revenue), 2) AS monetary

    FROM fact_orders f

    LEFT JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,

    recency_days,
    frequency,
    monetary,

    CASE
        WHEN monetary >= 1000 THEN 'High Value'
        WHEN monetary >= 500 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment

FROM customer_rfm
ORDER BY monetary DESC
LIMIT 50;


-- =====================================================
-- STEP 12: BEST SALES DAYS
-- =====================================================

/*
Why:
Businesses analyze weekday performance.

Questions answered:
- Which day performs best?
- Which days are weakest?
*/

SELECT
    d.day_name,

    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.total_revenue), 2) AS total_revenue,

    ROUND(AVG(f.total_revenue), 2) AS avg_order_value

FROM fact_orders f

LEFT JOIN dim_date d
    ON f.order_date = d.date_key

GROUP BY d.day_name
ORDER BY total_revenue DESC;


-- =====================================================
-- STEP 13: DATA QUALITY VALIDATION
-- =====================================================

/*
Why:
Professional projects validate data quality.

Checks:
- duplicate orders
- missing joins
- negative revenue
- missing dates
*/


-- Duplicate orders check

SELECT
    order_id,
    COUNT(*) AS row_count
FROM fact_orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- Missing customer joins

SELECT COUNT(*) AS missing_customer_joins
FROM fact_orders f
LEFT JOIN dim_customers c
    ON f.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- Missing date joins

SELECT COUNT(*) AS missing_date_joins
FROM fact_orders f
LEFT JOIN dim_date d
    ON f.order_date = d.date_key
WHERE d.date_key IS NULL;


-- Negative revenue check

SELECT *
FROM fact_orders
WHERE total_revenue < 0;


-- Missing order dates

SELECT COUNT(*) AS missing_order_dates
FROM fact_orders
WHERE order_date IS NULL;


-- =====================================================
-- STEP 14: FINAL EXECUTIVE SUMMARY
-- =====================================================

/*
Why:
This becomes your README business summary.
*/

SELECT
    COUNT(DISTINCT order_id) AS total_orders,

    ROUND(SUM(total_revenue), 2) AS total_revenue,

    ROUND(
        SUM(total_revenue) /
        COUNT(DISTINCT order_id),
        2
    ) AS aov,

    ROUND(AVG(total_revenue), 2) AS avg_order_value,

    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date

FROM fact_orders;


-- =====================================================
-- DAY 4 FINAL NOTES
-- =====================================================

/*

DAY 4 SUMMARY
-------------

Built professional KPI analysis queries including:

1. Revenue analysis
2. AOV analysis
3. Monthly trend analysis
4. Product category analysis
5. Customer revenue ranking
6. Repeat customer rate
7. Customer retention analysis
8. RFM analysis
9. Day-of-week performance
10. Data quality validation

Main KPIs created:
- Total Revenue
- Average Order Value (AOV)
- Repeat Customer Rate
- Monthly Revenue
- Top Customer Revenue
- Top Product Category Revenue

Advanced SQL concepts used:
- CTEs (WITH)
- CASE WHEN
- DATEDIFF
- GROUP BY
- Aggregate functions
- Multi-table joins
- RFM segmentation

Business insight:
The dataset is heavily dominated by delivered orders,
which explains why overall AOV and delivered AOV
are extremely close in value.

*/