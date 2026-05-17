# SQL E-Commerce Data Warehouse Project

## Overview

This project demonstrates the design and implementation of a modern SQL-based data warehouse using the Brazilian E-Commerce Public Dataset by Olist.

The solution transforms raw transactional CSV data into a clean analytical warehouse structure that supports business intelligence, reporting, KPI analysis, and decision-making.

The project follows real-world data engineering and analytics workflows including:

- Raw data ingestion
- Data cleaning
- Data transformation
- Dimensional modeling
- Star schema design
- KPI analysis
- Customer analytics
- Revenue analysis

---

# Business Problem

E-commerce companies generate large volumes of transactional data from customers, orders, products, and logistics systems.

However, raw operational data is often:

- fragmented
- inconsistent
- difficult to analyze
- poorly optimized for reporting

This creates several business challenges:

- Limited visibility into revenue trends
- Difficulty analyzing customer behavior
- Challenges identifying top-performing products
- Slow analytical querying
- Inability to perform scalable reporting
- Poor understanding of order performance

This project solves these problems by transforming raw CSV data into a structured dimensional warehouse optimized for analytics.

---

# Project Objectives

The main objectives of this project were to:

- Build a professional SQL data warehouse
- Clean and transform raw e-commerce data
- Design a dimensional star schema
- Create fact and dimension tables
- Enable analytical reporting
- Generate business insights from transactional data

---

# Dataset

Dataset Used:

- Brazilian E-Commerce Public Dataset by Olist

Dataset Source:

- Kaggle

The dataset contains information about:

- Customers
- Orders
- Order Items
- Products
- Delivery Information

---

# Technologies Used

| Technology | Purpose |
|---|---|
| MySQL | Database Management |
| SQL | Data Transformation & Analysis |
| Git & GitHub | Version Control |
| CSV Files | Raw Data Source |
| MySQL Workbench | Database Modeling & Querying |

---

# Data Warehouse Architecture

The project follows a layered warehouse architecture.

## 1. Raw Layer

Stores imported CSV datasets exactly as received.

Raw tables created:

- raw_olist_orders
- raw_olist_order_items
- raw_olist_customers
- raw_olist_products

Purpose:
- preserve original data
- support repeatable transformations
- prevent accidental data corruption

---

## 2. Warehouse Layer

Cleaned and transformed analytical tables.

### Fact Table

#### `fact_orders`

Stores measurable business events.

Grain:

```text
One row per order_id
```

Contains:

- revenue
- freight revenue
- item counts
- order dates
- order status
- customer references

---

### Dimension Tables

#### `dim_customers`

Stores customer information including:

- customer IDs
- city
- state
- zip code

---

#### `dim_products`

Stores product information including:

- product category
- product dimensions
- product weight

---

#### `dim_date`

Stores reusable calendar attributes including:

- year
- month
- quarter
- weekday
- month name

---

# Star Schema Design

The warehouse follows a star schema design.

Relationships:

```text
dim_customers ─── fact_orders ─── dim_date
```

The fact table acts as the center of the warehouse while dimension tables provide descriptive analytical context.

---

# ETL Process

The ETL pipeline included:

1. Extract raw CSV files
2. Load raw data into staging tables
3. Clean and standardize values
4. Convert text values into proper datatypes
5. Aggregate item-level revenue
6. Load transformed data into warehouse tables

---

# Real-World Challenges Solved

## 1. Missing Values Stored as Empty Strings

### Problem

The imported CSV files did not contain proper SQL NULL values.

Missing values appeared as:

```sql
''
```

This caused:
- incorrect null detection
- datatype conversion problems
- inaccurate aggregations

### Solution

Used:

```sql
NULLIF(TRIM(column_name), '')
```

to convert empty strings into proper SQL NULL values.

---

## 2. Revenue Grain Mismatch

### Problem

Revenue existed at order-item level while the warehouse fact table was designed at order level.

This created a grain mismatch problem.

### Solution

Revenue was aggregated using:

```sql
GROUP BY order_id
SUM(price + freight_value)
```

before loading into `fact_orders`.

This preserved the warehouse grain:

```text
one row per order_id
```

---

## 3. Date Conversion Challenges

### Problem

Order timestamps were imported as TEXT values.

This prevented:
- date analysis
- month grouping
- trend analysis
- date calculations

### Solution

Used:

```sql
STR_TO_DATE()
```

to convert timestamps into proper MySQL date formats.

---

## 4. Investigating AOV Similarities

### Problem

Overall AOV and delivered-order AOV initially appeared identical.

This seemed mathematically suspicious.

### Investigation

Performed:
- order status distribution analysis
- weighted average analysis
- precision comparison

### Finding

Discovered that:
- approximately 97% of orders were delivered
- delivered orders dominated revenue
- rounding to 2 decimal places hid small differences

This demonstrated the importance of:
- precision handling
- weighted averages
- distribution analysis

---

# Key Business Questions Solved

This project helps answer important business questions such as:

- What are the top-selling product categories?
- What are customer purchasing trends?
- Which regions generate the most sales?
- What is the Average Order Value (AOV)?
- What is the repeat customer rate?
- Which months generate the highest revenue?
- Which customers generate the highest revenue?
- How does order status affect revenue?

---

# Sample SQL Analysis

## 1. Revenue & AOV Analysis

### Business Question

```text
What is the total revenue and average order value?
```

### SQL Query

```sql
SELECT
    COUNT(DISTINCT order_id) AS total_orders,

    ROUND(SUM(total_revenue), 2) AS total_revenue,

    ROUND(
        SUM(total_revenue) /
        COUNT(DISTINCT order_id),
        2
    ) AS aov

FROM fact_orders;
```

---

## 2. Monthly Revenue Trend

### Business Question

```text
How does revenue change over time?
```

### SQL Query

```sql
SELECT
    d.year,
    d.month,
    d.month_name,

    ROUND(SUM(f.total_revenue), 2) AS total_revenue

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
```

---

## 3. Revenue by Customer State

### Business Question

```text
Which regions generate the most sales?
```

### SQL Query

```sql
SELECT
    c.customer_state,

    ROUND(SUM(f.total_revenue), 2) AS total_revenue

FROM fact_orders f

LEFT JOIN dim_customers c
    ON f.customer_id = c.customer_id

GROUP BY c.customer_state
ORDER BY total_revenue DESC;
```

---

## 4. Top Product Categories

### Business Question

```text
Which product categories generate the most revenue?
```

### SQL Query

```sql
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
```

---

## 5. RFM Customer Analysis

### Business Question

```text
Who are the highest-value customers?
```

### SQL Query

```sql
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

SELECT *
FROM customer_rfm
ORDER BY monetary DESC
LIMIT 20;
```

---

# Key Project Outcomes

The final warehouse successfully enabled:

- Revenue analysis
- Customer behavior analysis
- Time-series reporting
- Regional sales analysis
- Product performance analysis
- Repeat customer analysis
- RFM customer segmentation
- Analytical SQL reporting

The project also demonstrated real-world solutions to:
- datatype inconsistencies
- missing values
- warehouse grain mismatches
- timestamp conversion issues
- analytical debugging challenges

---

# Project Structure

```text
sql-ecommerce-data-warehouse/
│
├── sql/
│   ├── 01_raw_ingestion.sql
│   ├── 02_data_understanding.sql
│   ├── 03_build_warehouse.sql
│   └── 04_kpi_analysis.sql
│
├── screenshots/
│   ├── erd_schema.png
│   ├── kpi_summary.png
│   ├── monthly_revenue_trend.png
│   ├── rfm_analysis.png
│   └── top_product_categories.png
│
├── docs/
│   └── project_notes.md
│
└── README.md
```

---

# Key Skills Demonstrated

This project demonstrates practical skills in:

- SQL Development
- Data Cleaning
- Data Transformation
- Data Warehousing
- Dimensional Modeling
- Star Schema Design
- KPI Reporting
- Revenue Analytics
- Customer Analytics
- RFM Segmentation
- Data Engineering
- Analytical Querying
- Git & GitHub

---

# Future Improvements

Possible future improvements include:

- Building Power BI dashboards
- Automating ETL workflows
- Adding product-level fact tables
- Implementing incremental loading
- Deploying warehouse to cloud infrastructure



# Conclusion

This project demonstrates how raw e-commerce transactional data can be transformed into a clean dimensional warehouse capable of supporting business intelligence, KPI reporting, customer analytics, and scalable SQL analysis.

The final solution reflects real-world data engineering and analytics practices including:
- ETL workflows
- dimensional modeling
- warehouse design
- data cleaning
- KPI reporting
- analytical problem solving
