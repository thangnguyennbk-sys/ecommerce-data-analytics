-- ============================================================
-- E-COMMERCE SALES & CUSTOMER ANALYTICS
-- File: 05_sales_analysis.sql
--
-- Purpose:
--   Analyze overall sales performance, revenue trends,
--   order growth, customer volume, and sales contribution.
--
-- BUSINESS RULES:
--   1. Core sales KPIs only include delivered orders.
--
--   2. Revenue is calculated from product price.
--      Freight value is NOT included in revenue.
--
--   3. Monetary values are taken from the cleaned view:
--      dbo.vw_order_items_clean
--
--   4. customer_unique_id represents a real unique customer.
--
--   5. Early 2016 months contain extremely low order volume
--      and are treated as boundary / incomplete periods.
--
--   6. MoM growth analysis therefore starts from 2017-01.
--
--   7. Raw tables remain unchanged.
-- ============================================================

USE ecommerce_analytics;
GO



-- ============================================================
-- 1. TOTAL REVENUE
-- ============================================================
-- Business question:
-- How much product revenue was generated from delivered orders?
--
-- Grain:
-- One row in vw_order_items_clean = one item in an order.
--
-- Revenue:
-- SUM(item price)
-- ============================================================

SELECT
    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS total_revenue

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered';
GO


-- RESULT:
-- Total Revenue = 13,221,498.11



-- ============================================================
-- 2. TOTAL DELIVERED ORDERS
-- ============================================================
-- Business question:
-- How many successfully delivered orders were completed?
--
-- orders table grain:
-- One row = one order.
-- ============================================================

SELECT
    COUNT(*) AS total_orders

FROM dbo.orders

WHERE order_status = 'delivered';
GO


-- RESULT:
-- Total Delivered Orders = 96,478



-- ============================================================
-- 3. TOTAL UNIQUE CUSTOMERS
-- ============================================================
-- Business question:
-- How many unique customers completed at least one order?
--
-- IMPORTANT:
-- customer_id is associated with an order/customer record.
--
-- customer_unique_id identifies the same customer across
-- multiple orders.
-- ============================================================

SELECT
    COUNT(DISTINCT c.customer_unique_id)
        AS total_customers

FROM dbo.orders AS o

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered';
GO


-- RESULT:
-- Total Unique Customers = 93,358



-- ============================================================
-- 4. AVERAGE ORDER VALUE (AOV)
-- ============================================================
-- Business question:
-- How much product revenue does an average delivered order
-- generate?
--
-- Formula:
--
-- AOV = Total Revenue / Total Orders
--
-- IMPORTANT:
-- AVG(price) would calculate average item price,
-- NOT average order value.
-- ============================================================

SELECT
    CAST(
        SUM(oi.price)
        /
        NULLIF(
            COUNT(DISTINCT o.order_id),
            0
        )
        AS DECIMAL(18,2)
    ) AS average_order_value

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered';
GO


-- RESULT:
-- Average Order Value = 137.04



-- ============================================================
-- 5. SALES KPI SUMMARY
-- ============================================================
-- Business question:
-- What are the main overall sales KPIs?
--
-- Useful later for:
--   Power BI KPI cards
--   README
--   Portfolio summary
-- ============================================================

SELECT
    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS total_revenue,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    COUNT(DISTINCT c.customer_unique_id)
        AS total_customers,

    CAST(
        SUM(oi.price)
        /
        NULLIF(
            COUNT(DISTINCT o.order_id),
            0
        )
        AS DECIMAL(18,2)
    ) AS average_order_value

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered';
GO


-- EXPECTED:
--
-- total_revenue       = 13,221,498.11
-- total_orders        = 96,478
-- total_customers     = 93,358
-- average_order_value = 137.04



-- ============================================================
-- 6. MONTHLY SALES PERFORMANCE
-- ============================================================
-- Business questions:
--
-- How does revenue change over time?
-- How many orders are generated each month?
-- How many customers purchase each month?
-- What is monthly AOV?
--
-- order_month uses the first day of each month.
--
-- Example:
-- 2018-05-01 = May 2018
-- ============================================================

SELECT
    DATEFROMPARTS(
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp),
        1
    ) AS order_month,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS revenue,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    COUNT(DISTINCT c.customer_unique_id)
        AS total_customers,

    CAST(
        SUM(oi.price)
        /
        NULLIF(
            COUNT(DISTINCT o.order_id),
            0
        )
        AS DECIMAL(18,2)
    ) AS average_order_value

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'

GROUP BY
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp)

ORDER BY
    order_month;
GO


-- FINDINGS:
--
-- 1. Early 2016 months contain extremely low order volume
--    and should be treated as boundary / incomplete periods.
--
-- 2. Revenue increased substantially throughout 2017.
--
-- 3. November 2017 shows a strong revenue spike.
--
-- 4. November 2017 revenue increased while AOV decreased,
--    suggesting higher order volume was the main driver.
--
-- 5. Revenue remained relatively high during 2018.
--
-- 6. Monthly AOV remained comparatively stable, suggesting
--    that changes in order volume were an important driver
--    of revenue growth.



-- ============================================================
-- 7. MONTH-OVER-MONTH REVENUE GROWTH
-- ============================================================
-- Business question:
-- How quickly is monthly revenue growing or declining?
--
-- Formula:
--
-- Current Revenue - Previous Revenue
-- ----------------------------------- x 100
--        Previous Revenue
--
-- MoM analysis begins in January 2017 because early 2016
-- months contain insufficient order volume.
--
-- LAG() retrieves the previous row's month and revenue.
--
-- DATEDIFF() confirms that the previous row is actually
-- the previous calendar month.
-- ============================================================

WITH monthly_revenue AS (

    SELECT
        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS order_month,

        SUM(oi.price) AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'

    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
),

revenue_with_previous AS (

    SELECT
        order_month,
        revenue,

        LAG(order_month) OVER (
            ORDER BY order_month
        ) AS previous_month,

        LAG(revenue) OVER (
            ORDER BY order_month
        ) AS previous_month_revenue

    FROM monthly_revenue
)

SELECT
    order_month,

    CAST(
        revenue
        AS DECIMAL(18,2)
    ) AS revenue,

    CAST(
        previous_month_revenue
        AS DECIMAL(18,2)
    ) AS previous_month_revenue,

    CASE
        WHEN DATEDIFF(
            MONTH,
            previous_month,
            order_month
        ) = 1

        THEN CAST(
            100.0 *
            (revenue - previous_month_revenue)
            /
            NULLIF(previous_month_revenue, 0)
            AS DECIMAL(10,2)
        )

        ELSE NULL
    END AS mom_growth_pct

FROM revenue_with_previous

ORDER BY
    order_month;
GO


-- FINDINGS:
--
-- 1. Revenue grew rapidly during early 2017.
--
-- 2. November 2017 recorded approximately
--    +52.37% MoM revenue growth.
--
-- 3. Revenue declined approximately -26.50% in
--    December 2017.
--
-- 4. Revenue recovered approximately +27.36%
--    in January 2018.
--
-- 5. During 2018, monthly revenue growth became
--    relatively more stable than the rapid expansion
--    observed during 2017.



-- ============================================================
-- 8. MONTH-OVER-MONTH ORDER GROWTH
-- ============================================================
-- Business question:
-- Is revenue growth mainly associated with increasing
-- order volume?
--
-- Analysis begins in January 2017 for consistency
-- with MoM revenue analysis.
-- ============================================================

WITH monthly_orders AS (

    SELECT
        DATEFROMPARTS(
            YEAR(order_purchase_timestamp),
            MONTH(order_purchase_timestamp),
            1
        ) AS order_month,

        COUNT(*) AS total_orders

    FROM dbo.orders

    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= '2017-01-01'

    GROUP BY
        YEAR(order_purchase_timestamp),
        MONTH(order_purchase_timestamp)
),

orders_with_previous AS (

    SELECT
        order_month,
        total_orders,

        LAG(order_month) OVER (
            ORDER BY order_month
        ) AS previous_month,

        LAG(total_orders) OVER (
            ORDER BY order_month
        ) AS previous_month_orders

    FROM monthly_orders
)

SELECT
    order_month,
    total_orders,
    previous_month_orders,

    CASE
        WHEN DATEDIFF(
            MONTH,
            previous_month,
            order_month
        ) = 1

        THEN CAST(
            100.0 *
            (total_orders - previous_month_orders)
            /
            NULLIF(previous_month_orders, 0)
            AS DECIMAL(10,2)
        )

        ELSE NULL
    END AS mom_order_growth_pct

FROM orders_with_previous

ORDER BY
    order_month;
GO


-- FINDINGS:
--
-- 1. November 2017 order volume increased by
--    approximately 62.77% MoM.
--
-- 2. Revenue increased by approximately 52.37%
--    during the same period.
--
-- 3. AOV decreased from October to November 2017.
--
-- 4. Therefore, November 2017 revenue growth was
--    primarily driven by a sharp increase in order volume
--    rather than higher spending per order.
--
-- 5. Revenue growth and order growth generally move
--    in the same direction.
--
-- 6. However, order growth does not always guarantee
--    revenue growth because changes in AOV can offset it.



-- ============================================================
-- 9. CUMULATIVE REVENUE
-- ============================================================
-- Business question:
-- How does accumulated revenue grow over time?
--
-- Unlike MoM analysis, all dataset months are included
-- because valid historical revenue should contribute to
-- the cumulative total.
--
-- Window function:
-- SUM() OVER()
-- ============================================================

WITH monthly_revenue AS (

    SELECT
        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS order_month,

        SUM(oi.price) AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
)

SELECT
    order_month,

    CAST(
        revenue
        AS DECIMAL(18,2)
    ) AS monthly_revenue,

    CAST(
        SUM(revenue) OVER (
            ORDER BY order_month

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        )
        AS DECIMAL(18,2)
    ) AS cumulative_revenue

FROM monthly_revenue

ORDER BY
    order_month;
GO


-- FINDINGS:
--
-- 1. Cumulative revenue increased steadily throughout
--    the dataset period.
--
-- 2. Revenue accumulation accelerated significantly
--    during 2017.
--
-- 3. By August 2018, cumulative delivered-order revenue
--    reached approximately 13.22 million.
--
-- 4. The final cumulative revenue matches the overall
--    Total Revenue KPI, confirming calculation consistency.



-- ============================================================
-- 10. BEST REVENUE MONTH
-- ============================================================
-- Business question:
-- Which month generated the highest product revenue?
-- ============================================================

WITH monthly_revenue AS (

    SELECT
        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS order_month,

        SUM(oi.price) AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
)

SELECT TOP 1
    order_month,

    CAST(
        revenue
        AS DECIMAL(18,2)
    ) AS revenue

FROM monthly_revenue

ORDER BY
    revenue DESC;
GO


-- FINDING:
--
-- November 2017 generated the highest monthly revenue
-- in the dataset:
--
-- Revenue = 987,765.37



-- ============================================================
-- 11. LOWEST REVENUE MONTH - STABLE PERIOD
-- ============================================================
-- Business question:
-- Which month generated the lowest revenue during the
-- stable analysis period?
--
-- IMPORTANT:
-- Early 2016 boundary months are excluded because
-- they contain extremely low order volume and should
-- not be treated as normal operating periods.
-- ============================================================

WITH monthly_revenue AS (

    SELECT
        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS order_month,

        SUM(oi.price) AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'

    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
)

SELECT TOP 1
    order_month,

    CAST(
        revenue
        AS DECIMAL(18,2)
    ) AS revenue

FROM monthly_revenue

ORDER BY
    revenue ASC;
GO


-- FINDING:
--
-- January 2017 recorded the lowest monthly revenue
-- within the stable analysis period:
--
-- Revenue = 111,798.36
--
-- This should be interpreted as an early-stage baseline
-- rather than necessarily poor business performance.



-- ============================================================
-- 12. YEARLY SALES PERFORMANCE
-- ============================================================
-- Business question:
-- How does sales performance compare across years?
--
-- IMPORTANT:
-- 2016 and 2018 are partial years.
--
-- 2018 only contains data through approximately August,
-- so year-over-year comparisons must be interpreted
-- carefully.
-- ============================================================

SELECT
    YEAR(o.order_purchase_timestamp)
        AS order_year,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS revenue,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    COUNT(DISTINCT c.customer_unique_id)
        AS total_customers,

    CAST(
        SUM(oi.price)
        /
        NULLIF(
            COUNT(DISTINCT o.order_id),
            0
        )
        AS DECIMAL(18,2)
    ) AS average_order_value

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'

GROUP BY
    YEAR(o.order_purchase_timestamp)

ORDER BY
    order_year;
GO


-- RESULTS:
--
-- 2016:
-- Revenue     = 40,470.98
-- Orders      = 267
-- Customers   = 264
-- AOV         = 151.58
--
-- 2017:
-- Revenue     = 5,962,902.01
-- Orders      = 43,428
-- Customers   = 42,136
-- AOV         = 137.31
--
-- 2018:
-- Revenue     = 7,218,125.12
-- Orders      = 52,783
-- Customers   = 51,612
-- AOV         = 136.75
--
-- FINDINGS:
--
-- 1. 2016 is a partial boundary year with very limited data.
--
-- 2. 2018 is also a partial year and contains data only
--    through approximately August.
--
-- 3. Despite being incomplete, 2018 already generated
--    higher revenue, orders, and customers than 2017.
--
-- 4. AOV remained almost unchanged between 2017 and 2018
--    (137.31 vs 136.75).
--
-- 5. This suggests sales growth was primarily driven by
--    higher order and customer volume rather than higher
--    spending per order.



-- ============================================================
-- 13. REVENUE CONTRIBUTION BY MONTH
-- ============================================================
-- Business question:
-- What percentage of total dataset revenue is contributed
-- by each month?
--
-- Window function:
-- SUM(revenue) OVER ()
-- gives total revenue across all months.
-- ============================================================

WITH monthly_revenue AS (

    SELECT
        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS order_month,

        SUM(oi.price) AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
)

SELECT
    order_month,

    CAST(
        revenue
        AS DECIMAL(18,2)
    ) AS revenue,

    CAST(
        100.0 * revenue
        /
        NULLIF(
            SUM(revenue) OVER (),
            0
        )
        AS DECIMAL(10,2)
    ) AS revenue_contribution_pct

FROM monthly_revenue

ORDER BY
    order_month;
GO


-- FINDINGS:
--
-- 1. November 2017 contributed the largest share of
--    total dataset revenue, at approximately 7.47%.
--
-- 2. Several months in 2018 individually contributed
--    more than 6% of total revenue.
--
-- 3. This reflects the significantly higher sales volume
--    reached during the later period of the dataset.
--
-- 4. Early boundary months in 2016 contributed almost
--    no revenue and should not be treated as normal
--    operating periods.



-- ============================================================
-- 14. SALES KPI CONSISTENCY VALIDATION
-- ============================================================
-- Purpose:
-- Validate that monthly revenue aggregates back to the
-- same overall Total Revenue KPI.
--
-- This is useful as a final quality check.
-- ============================================================

WITH monthly_revenue AS (

    SELECT
        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS order_month,

        SUM(oi.price) AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
)

SELECT
    CAST(
        SUM(revenue)
        AS DECIMAL(18,2)
    ) AS monthly_revenue_total

FROM monthly_revenue;
GO


-- EXPECTED:
--
-- monthly_revenue_total = 13,221,498.11
--
-- This should match Section 1 Total Revenue.



-- ============================================================
-- FINAL SALES ANALYSIS SUMMARY
-- ============================================================
--
-- MAIN KPIs:
--
-- Total Revenue:
-- 13,221,498.11
--
-- Delivered Orders:
-- 96,478
--
-- Unique Customers:
-- 93,358
--
-- Average Order Value:
-- 137.04
--
--
-- MAIN BUSINESS INSIGHTS:
--
-- 1. Sales expanded strongly throughout 2017.
--
-- 2. November 2017 was the highest-revenue month,
--    generating 987,765.37 and contributing approximately
--    7.47% of total dataset revenue.
--
-- 3. November 2017 revenue increased approximately
--    52.37% MoM while order volume increased 62.77%.
--
-- 4. AOV declined during the same period, indicating
--    that the November revenue surge was driven primarily
--    by increased order volume.
--
-- 5. 2018 had already exceeded 2017 in revenue, orders,
--    and customer volume despite being a partial year.
--
-- 6. AOV remained relatively stable between 2017 and 2018,
--    suggesting business growth was driven primarily by
--    customer and order volume rather than increased
--    spending per order.
--
-- 7. Early 2016 data contains extremely low order volume
--    and should not be interpreted as representative
--    business performance.
--
-- ============================================================



-- ============================================================
-- IMPORTANT ANALYTICAL NOTE:
-- MANY-TO-MANY JOIN RISK
-- ============================================================
--
-- DO NOT directly join:
--
-- dbo.vw_order_items_clean
--
-- with
--
-- dbo.vw_payments_clean
--
-- and then calculate:
--
-- SUM(price)
--
-- because one order can contain:
--
--   multiple order items
--   multiple payment records
--
-- Example:
--
-- 1 order
-- ├── 3 items
-- └── 2 payment records
--
-- Direct join could produce:
--
-- 3 x 2 = 6 rows
--
-- causing revenue or payment values to be duplicated.
--
-- CORRECT APPROACH:
--
-- 1. Aggregate order_items to one row per order.
--
-- 2. Aggregate payments to one row per order.
--
-- 3. Join the two aggregated datasets.
--
-- This prevents double counting.
--
-- ============================================================