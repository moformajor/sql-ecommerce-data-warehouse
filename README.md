# SQL E-Commerce Data Warehouse Project

## Overview

This project demonstrates the design and implementation of a modern SQL-based data warehouse using the Brazilian E-Commerce Public Dataset by Olist. The solution transforms raw transactional data into a structured analytical environment that supports business intelligence, reporting, and decision-making.

The project follows real-world data engineering and analytics workflows including data ingestion, data modeling, ETL processes, dimensional modeling, and SQL analytics.

---

# Business Problem

E-commerce companies generate large volumes of transactional data from customers, orders, payments, products, sellers, and logistics. However, raw operational data is often fragmented and difficult to analyze efficiently.

This project solves the following business challenges:

- Lack of centralized reporting
- Difficulty tracking customer purchasing behavior
- Limited visibility into sales performance
- Poor insight into delivery efficiency
- Challenges identifying top-performing products and sellers
- Inability to perform scalable analytical queries

The data warehouse consolidates and organizes the data into analytical structures that support faster and more reliable business insights.

---

# Project Objectives

- Build a scalable SQL data warehouse
- Clean and transform raw e-commerce data
- Design star schema dimensional models
- Create fact and dimension tables
- Enable analytical querying and reporting
- Generate business insights from transactional data

---

# Dataset

Dataset Used:

- Brazilian E-Commerce Public Dataset by Olist

The dataset contains information about:

- Customers
- Orders
- Order items
- Payments
- Products
- Sellers
- Reviews
- Geolocation
- Delivery information

---

# Technologies Used

| Technology | Purpose |
|---|---|
| SQL Server / PostgreSQL | Database Management |
| SQL | Data Transformation & Analysis |
| Git & GitHub | Version Control |
| Power BI (Optional) | Data Visualization |
| CSV Files | Raw Data Source |

---

# Data Warehouse Architecture

The project follows a layered architecture:

## 1. Raw Layer
Stores original imported CSV datasets.

## 2. Staging Layer
Cleans and standardizes raw data.

## 3. Data Warehouse Layer
Implements dimensional models using:

- Fact Tables
- Dimension Tables
- Star Schema

---

# Data Model

## Fact Tables

- FactOrders
- FactPayments
- FactSales

## Dimension Tables

- DimCustomers
- DimProducts
- DimSellers
- DimDate
- DimGeolocation

---

# ETL Process

The ETL pipeline includes:

1. Extract raw CSV data
2. Transform and clean data
3. Remove duplicates and null values
4. Standardize formats
5. Load transformed data into warehouse tables

---

# Key Business Questions Solved

This project helps answer important business questions such as:

- What are the top-selling product categories?
- Which sellers generate the highest revenue?
- What are customer purchasing trends?
- Which regions generate the most sales?
- What is the average delivery time?
- Which payment methods are most used?
- How do customer reviews impact sales?

---

# Sample SQL Analysis

## Top Revenue Generating Products

```sql
SELECT product_category_name,
       SUM(payment_value) AS total_revenue
FROM fact_sales
GROUP BY product_category_name
ORDER BY total_revenue DESC;
```

## Monthly Sales Trend

```sql
SELECT order_month,
       SUM(payment_value) AS monthly_sales
FROM fact_sales
GROUP BY order_month
ORDER BY order_month;
```

---

# Project Structure

```bash
sql-ecommerce-data-warehouse/
│
├── data/
├── sql/
├── staging/
├── warehouse/
├── analytics/
├── screenshots/
├── README.md
```

---

# Key Skills Demonstrated

- Data Warehousing
- SQL Development
- ETL Pipeline Design
- Data Cleaning
- Dimensional Modeling
- Business Intelligence
- Analytical Querying
- Database Optimization
- Git Version Control

---

# Future Improvements

- Automate ETL pipeline
- Add Power BI dashboard
- Implement incremental loading
- Deploy to cloud platform
- Add data quality monitoring

---

# Author

## Uzochukwu Constantine Umejiofor

Data Analyst | SQL Developer | Business Intelligence Enthusiast

Portfolio:
https://moformajor.github.io

GitHub:
https://github.com/moformajor

---

# Conclusion

This project demonstrates how raw e-commerce data can be transformed into a structured analytical data warehouse capable of supporting strategic business decisions and scalable reporting solutions.
