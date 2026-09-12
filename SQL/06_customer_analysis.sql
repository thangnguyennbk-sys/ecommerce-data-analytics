-- ============================================================
-- E-COMMERCE SALES & CUSTOMER ANALYTICS
-- File: 06_customer_analysis.sql
--
-- Purpose:
--   Analyze customer purchase behavior, repeat purchases,
--   customer value, geographic distribution, and RFM
--   segmentation.
--
-- BUSINESS RULES:
--
--   1. Only delivered orders are used for completed-purchase
--      customer analysis.
--
--   2. customer_unique_id is used to identify a real customer
--      across multiple orders.
--
--   3. Revenue is calculated from cleaned item prices in:
--      dbo.vw_order_items_clean
--
--   4. Freight is NOT included in product revenue.
--
--   5. RFM analysis uses:
--
--      R = Recency
--      F = Frequency
--      M = Monetary
--
--   6. Higher R/F/M scores represent stronger customer
--      behavior.
--
--   7. Raw source tables remain unchanged.
--
-- ============================================================

USE ecommerce_analytics;
GO



-- ============================================================
-- 1. ORDERS PER CUSTOMER
-- ============================================================
-- Business question:
--
-- How many delivered orders has each customer completed?
--
-- IMPORTANT:
--
-- customer_id identifies a customer record associated with
-- an order.
--
-- customer_unique_id is used to identify the same real
-- customer across multiple orders.
-- ============================================================

SELECT
    c.customer_unique_id,

    COUNT(DISTINCT o.order_id)
        AS total_orders

FROM dbo.orders AS o

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'

GROUP BY
    c.customer_unique_id

ORDER BY
    total_orders DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 1
-- ============================================================
--
-- 1. Repeat purchasing exists in the dataset, although it is
--    relatively uncommon compared with one-time purchasing.
--
-- 2. The most active customer completed:
--
--    15 delivered orders.
--
-- 3. The second-most active customer completed:
--
--    9 delivered orders.
--
-- 4. Several customers completed between 4 and 7 orders,
--    confirming that customer_unique_id successfully captures
--    repeat purchasing across different orders.
--
-- 5. Purchase frequency varies substantially across customers,
--    but the highest-frequency customers represent only a
--    very small portion of the total customer base.



-- ============================================================
-- 2. CUSTOMER PURCHASE FREQUENCY DISTRIBUTION
-- ============================================================
-- Business question:
--
-- How many customers purchased once, twice, three times,
-- and so on?
-- ============================================================

WITH customer_orders AS (

    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id)
            AS total_orders

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
)

SELECT
    total_orders,

    COUNT(*) AS customer_count

FROM customer_orders

GROUP BY
    total_orders

ORDER BY
    total_orders;
GO


-- ============================================================
-- RESULTS - SECTION 2
-- ============================================================
--
-- 1 order   = 90,557 customers
-- 2 orders  =  2,573 customers
-- 3 orders  =    181 customers
-- 4 orders  =     28 customers
-- 5 orders  =      9 customers
-- 6 orders  =      5 customers
-- 7 orders  =      3 customers
-- 9 orders  =      1 customer
-- 15 orders =      1 customer
--
--
-- FINDINGS:
--
-- 1. Customer purchase frequency is extremely skewed toward
--    one-time purchasing.
--
-- 2. 90,557 out of 93,358 customers completed only one
--    delivered order.
--
-- 3. Only 2,801 customers completed two or more orders.
--
-- 4. The number of customers drops sharply as purchase
--    frequency increases.
--
-- 5. Customers with very high purchase frequency are rare.
--
-- 6. This highly skewed distribution is important later
--    when designing the Frequency score for RFM analysis.
--
-- 7. Using NTILE(5) directly for Frequency would be
--    inappropriate because customers with identical
--    frequency values could receive different scores.



-- ============================================================
-- 3. ONE-TIME VS REPEAT CUSTOMERS
-- ============================================================
-- Business question:
--
-- How many customers purchased once versus more than once?
--
-- Definition:
--
-- 1 delivered order   = One-time Customer
-- 2+ delivered orders = Repeat Customer
-- ============================================================

WITH customer_orders AS (

    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id)
            AS total_orders

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
)

SELECT
    CASE
        WHEN total_orders = 1
            THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,

    COUNT(*) AS customer_count

FROM customer_orders

GROUP BY
    CASE
        WHEN total_orders = 1
            THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END;
GO


-- ============================================================
-- RESULTS - SECTION 3
-- ============================================================
--
-- One-time Customers = 90,557
-- Repeat Customers   =  2,801
--
--
-- FINDINGS:
--
-- 1. One-time customers dominate the customer base.
--
-- 2. Repeat customers represent only a small minority
--    of customers.
--
-- 3. The large difference between one-time and repeat
--    customers indicates that repeat purchasing is limited
--    during the observed dataset period.
--
-- 4. Comparing total orders with total customers alone would
--    not be sufficient to identify repeat buyers.
--
-- 5. Customer-level aggregation using customer_unique_id is
--    required to measure repeat purchasing correctly.



-- ============================================================
-- 4. REPEAT PURCHASE RATE
-- ============================================================
-- Business question:
--
-- What percentage of customers completed more than one
-- delivered order?
--
-- Formula:
--
-- Repeat Purchase Rate
-- =
-- Repeat Customers / Total Customers * 100
-- ============================================================

WITH customer_orders AS (

    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id)
            AS total_orders

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
)

SELECT
    COUNT(*) AS total_customers,

    SUM(
        CASE
            WHEN total_orders > 1
            THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN total_orders > 1
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS repeat_purchase_rate_pct

FROM customer_orders;
GO


-- ============================================================
-- RESULTS - SECTION 4
-- ============================================================
--
-- Total Customers      = 93,358
-- Repeat Customers     =  2,801
-- Repeat Purchase Rate = 3.00%
--
--
-- FINDINGS:
--
-- 1. Approximately 3% of customers completed more than
--    one delivered order.
--
-- 2. Approximately 97% completed only one delivered order.
--
-- 3. Repeat purchasing is therefore limited within the
--    observed dataset period.
--
-- 4. The low repeat purchase rate makes conversion from
--    first purchase to second purchase an important area
--    for deeper customer analysis.
--
--
-- CAUTION:
--
-- The 3% repeat purchase rate should NOT automatically be
-- described as "poor retention."
--
-- Customers entered the dataset at different times and
-- therefore had different opportunities to make another
-- purchase.
--
-- Cohort analysis would provide a stronger measurement of
-- customer retention over time.



-- ============================================================
-- 5. REVENUE BY CUSTOMER TYPE
-- ============================================================
-- Business question:
--
-- How much revenue is generated by one-time customers
-- versus repeat customers?
-- ============================================================

WITH customer_orders AS (

    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id)
            AS total_orders

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
),

customer_revenue AS (

    SELECT
        c.customer_unique_id,

        co.total_orders,

        SUM(oi.price)
            AS customer_revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN customer_orders AS co
        ON c.customer_unique_id =
           co.customer_unique_id

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id,
        co.total_orders
),

customer_type_summary AS (

    SELECT
        CASE
            WHEN total_orders = 1
                THEN 'One-time Customer'
            ELSE 'Repeat Customer'
        END AS customer_type,

        COUNT(*) AS customer_count,

        SUM(customer_revenue)
            AS revenue

    FROM customer_revenue

    GROUP BY
        CASE
            WHEN total_orders = 1
                THEN 'One-time Customer'
            ELSE 'Repeat Customer'
        END
)

SELECT
    customer_type,

    customer_count,

    CAST(
        revenue
        AS DECIMAL(18,2)
    ) AS revenue,

    CAST(
        revenue /
        NULLIF(customer_count, 0)
        AS DECIMAL(18,2)
    ) AS avg_revenue_per_customer,

    CAST(
        100.0 * revenue /
        NULLIF(
            SUM(revenue) OVER (),
            0
        )
        AS DECIMAL(10,2)
    ) AS revenue_share_pct

FROM customer_type_summary

ORDER BY
    revenue DESC;
GO


-- ============================================================
-- RESULTS - SECTION 5
-- ============================================================
--
-- ONE-TIME CUSTOMERS:
--
-- Customer Count       = 90,557
-- Revenue              = 12,493,089.36
-- Avg Revenue/Customer = 137.96
-- Revenue Share        = 94.49%
--
--
-- REPEAT CUSTOMERS:
--
-- Customer Count       = 2,801
-- Revenue              = 728,408.75
-- Avg Revenue/Customer = 260.05
-- Revenue Share        = 5.51%
--
--
-- FINDINGS:
--
-- 1. One-time customers generate most total revenue because
--    they represent the overwhelming majority of customers.
--
-- 2. Repeat customers account for only about 3% of customers
--    but contribute 5.51% of total revenue.
--
-- 3. Average revenue per repeat customer is:
--
--    260.05
--
--    compared with:
--
--    137.96
--
--    for one-time customers.
--
-- 4. Repeat customers therefore generate substantially more
--    revenue per customer than one-time buyers.
--
-- 5. Although repeat customers are relatively rare, they are
--    more valuable on a per-customer basis.
--
-- 6. Increasing repeat purchasing may therefore represent
--    an important customer-growth opportunity.



-- ============================================================
-- 6. TOP CUSTOMERS BY REVENUE
-- ============================================================
-- Business question:
--
-- Which customers generated the highest product revenue?
-- ============================================================

SELECT TOP 20
    c.customer_unique_id,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS total_revenue,

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

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    c.customer_unique_id

ORDER BY
    total_revenue DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 6
-- ============================================================
--
-- 1. The highest-revenue customer generated:
--
--    13,440.00
--
-- 2. That revenue came from only one delivered order.
--
-- 3. Several of the highest-revenue customers are one-time
--    buyers with unusually high order values.
--
-- 4. The customer with the highest purchase frequency is
--    NOT the customer with the highest total revenue.
--
-- 5. Purchase frequency and monetary value therefore measure
--    different aspects of customer value.
--
-- 6. Customer value should not be evaluated using order
--    count alone.
--
-- 7. This result provides a strong reason to use a
--    multidimensional customer framework such as RFM.



-- ============================================================
-- 7. CUSTOMER REVENUE CONCENTRATION
-- ============================================================
-- Business question:
--
-- How concentrated is revenue among the highest-value
-- individual customers?
--
-- This section measures the share of total revenue generated
-- by the top 20 customers.
-- ============================================================

WITH customer_revenue AS (

    SELECT
        c.customer_unique_id,

        SUM(oi.price)
            AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
),

ranked_customers AS (

    SELECT
        customer_unique_id,
        revenue,

        ROW_NUMBER() OVER (
            ORDER BY revenue DESC
        ) AS revenue_rank

    FROM customer_revenue
)

SELECT
    CAST(
        SUM(
            CASE
                WHEN revenue_rank <= 20
                THEN revenue
                ELSE 0
            END
        )
        AS DECIMAL(18,2)
    ) AS top_20_customer_revenue,

    CAST(
        SUM(revenue)
        AS DECIMAL(18,2)
    ) AS total_revenue,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN revenue_rank <= 20
                THEN revenue
                ELSE 0
            END
        )
        /
        NULLIF(SUM(revenue), 0)
        AS DECIMAL(10,2)
    ) AS top_20_revenue_share_pct

FROM ranked_customers;
GO


-- ============================================================
-- RESULTS - SECTION 7
-- ============================================================
--
-- Top 20 Customer Revenue = 107,712.36
-- Total Revenue           = 13,221,498.11
-- Top 20 Revenue Share    = 0.81%
--
--
-- FINDINGS:
--
-- 1. The 20 highest-revenue customers generate only
--    approximately 0.81% of total product revenue.
--
-- 2. Revenue is therefore not heavily concentrated among
--    a very small number of individual customers.
--
-- 3. The historical revenue base is broadly distributed
--    across many customers.
--
-- 4. The business does not appear strongly dependent on
--    a small number of individual high-value customers.
--
-- 5. Customer segmentation at scale is therefore likely
--    more informative than focusing only on a few top
--    customers.



-- ============================================================
-- 8. CUSTOMER GEOGRAPHY BY STATE
-- ============================================================
-- Business questions:
--
-- Which states contain the largest customer base?
--
-- Which states generate the most revenue?
--
-- How does AOV differ across geographic markets?
-- ============================================================

SELECT
    c.customer_state,

    COUNT(DISTINCT c.customer_unique_id)
        AS total_customers,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS revenue,

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

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    c.customer_state

ORDER BY
    revenue DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 8
-- ============================================================
--
-- SP:
--
-- Customers = 39,156
-- Orders    = 40,501
-- Revenue   = 5,067,633.16
-- AOV       = 125.12
--
--
-- 1. SP is clearly the largest market by:
--
--    customer count
--    order volume
--    total revenue
--
-- 2. RJ and MG are the next largest revenue-generating
--    states.
--
-- 3. Geographic revenue is strongly associated with market
--    size: the largest customer markets also generate the
--    highest total revenue.
--
-- 4. However, total revenue and AOV tell different stories.
--
-- 5. SP has very high scale but an AOV of:
--
--    125.12
--
-- 6. Several smaller markets show much higher AOV:
--
--    PB = 217.77
--    AP = 199.62
--    AC = 199.14
--    AL = 198.63
--    RO = 187.99
--    PA = 184.43
--
-- 7. A small geographic market can therefore have high
--    spending intensity despite low order volume.
--
-- 8. Market size and average order value should be evaluated
--    separately when assessing geographic performance.



-- ============================================================
-- 9. CUSTOMER GEOGRAPHY BY CITY
-- ============================================================
-- Business questions:
--
-- Which cities contain the largest customer base?
--
-- Which cities generate the most product revenue?
-- ============================================================

SELECT TOP 20
    c.customer_city,

    c.customer_state,

    COUNT(DISTINCT c.customer_unique_id)
        AS total_customers,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS revenue,

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

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    c.customer_city,
    c.customer_state

ORDER BY
    revenue DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 9
-- ============================================================
--
-- SAO PAULO:
--
-- Customers = 14,528
-- Orders    = 15,045
-- Revenue   = 1,859,556.83
-- AOV       = 123.60
--
--
-- RIO DE JANEIRO:
--
-- Customers = 6,361
-- Orders    = 6,601
-- Revenue   = 955,573.97
-- AOV       = 144.76
--
--
-- 1. Sao Paulo is the largest city market by:
--
--    customers
--    orders
--    revenue
--
-- 2. Rio de Janeiro is the second-largest city by revenue.
--
-- 3. Belo Horizonte, Brasilia, Curitiba, Campinas,
--    Porto Alegre, and Salvador also represent important
--    city markets.
--
-- 4. Large metropolitan areas dominate customer and
--    revenue volume.
--
-- 5. Sao Paulo's scale is much larger than other cities,
--    but its AOV is not the highest.
--
-- 6. Belem, for example, generated an AOV of:
--
--    182.25
--
--    despite having only:
--
--    428 delivered orders.
--
-- 7. Geographic market size and average customer spending
--    are therefore different analytical dimensions.



-- ============================================================
-- 10. RFM PREPARATION
-- ============================================================
-- Business question:
--
-- How can each customer be summarized using:
--
-- R = Recency
--
--     Number of days since the customer's latest purchase.
--
-- F = Frequency
--
--     Number of delivered orders completed by the customer.
--
-- M = Monetary
--
--     Total product revenue generated by the customer.
--
--
-- Analysis Date:
--
-- One day after the latest delivered purchase date in
-- the dataset.
--
-- Using a dataset-based analysis date avoids calculating
-- recency relative to today's real-world date.
-- ============================================================

WITH analysis_date AS (

    SELECT
        DATEADD(
            DAY,
            1,
            CAST(
                MAX(order_purchase_timestamp)
                AS DATE
            )
        ) AS analysis_date

    FROM dbo.orders

    WHERE order_status = 'delivered'
),

customer_rfm AS (

    SELECT
        c.customer_unique_id,

        MIN(o.order_purchase_timestamp)
            AS first_purchase_date,

        MAX(o.order_purchase_timestamp)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(oi.price)
            AS monetary

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
)

SELECT
    r.customer_unique_id,

    r.first_purchase_date,

    r.last_purchase_date,

    DATEDIFF(
        DAY,
        CAST(r.last_purchase_date AS DATE),
        a.analysis_date
    ) AS recency_days,

    r.frequency,

    CAST(
        r.monetary
        AS DECIMAL(18,2)
    ) AS monetary

FROM customer_rfm AS r

CROSS JOIN analysis_date AS a

ORDER BY
    monetary DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 10
-- ============================================================
--
-- 1. Recency, Frequency, and Monetary capture three
--    different dimensions of customer behavior.
--
--
-- EXAMPLE 1:
--
-- A top-revenue customer:
--
-- Recency   = 335 days
-- Frequency = 1
-- Monetary  = 13,440.00
--
-- This customer generated very high revenue but purchased
-- only once and had not purchased recently.
--
--
-- EXAMPLE 2:
--
-- Another customer:
--
-- Recency   = 22 days
-- Frequency = 4
-- Monetary  = 4,080.00
--
-- This customer has lower monetary value but is significantly
-- more recent and has completed multiple purchases.
--
--
-- 2. High Monetary value does not necessarily imply:
--
--    high Frequency
--    recent customer activity
--
-- 3. Some repeat customers show stronger combinations of
--    recency and frequency despite lower monetary value.
--
-- 4. Customer value should therefore be evaluated using
--    all three RFM dimensions rather than Monetary alone.



-- ============================================================
-- 11. RFM SCORING
-- ============================================================
-- Purpose:
--
-- Convert Recency, Frequency, and Monetary metrics into
-- scores from 1 to 5.
--
-- Higher score = stronger customer behavior.
--
--
-- ------------------------------------------------------------
-- R SCORE
-- ------------------------------------------------------------
--
-- Lower recency_days is better.
--
-- NTILE(5) separates customers into approximately five
-- distribution-based groups.
--
-- Most recent customer group receives:
--
-- R = 5
--
-- Least recent customer group receives:
--
-- R = 1
--
--
-- ------------------------------------------------------------
-- F SCORE
-- ------------------------------------------------------------
--
-- Frequency is extremely skewed because most customers
-- purchased only once.
--
-- Therefore explicit business rules are used instead of
-- NTILE().
--
-- 1 order    -> F = 1
-- 2 orders   -> F = 2
-- 3 orders   -> F = 3
-- 4-5 orders -> F = 4
-- 6+ orders  -> F = 5
--
--
-- ------------------------------------------------------------
-- M SCORE
-- ------------------------------------------------------------
--
-- Higher monetary value is better.
--
-- NTILE(5) divides customers into five monetary-value
-- groups.
--
-- Highest monetary quintile receives:
--
-- M = 5
--
-- Lowest monetary quintile receives:
--
-- M = 1
-- ============================================================

WITH analysis_date AS (

    SELECT
        DATEADD(
            DAY,
            1,
            CAST(
                MAX(order_purchase_timestamp)
                AS DATE
            )
        ) AS analysis_date

    FROM dbo.orders

    WHERE order_status = 'delivered'
),

customer_metrics AS (

    SELECT
        c.customer_unique_id,

        MAX(o.order_purchase_timestamp)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(oi.price)
            AS monetary

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
),

rfm_metrics AS (

    SELECT
        cm.customer_unique_id,

        DATEDIFF(
            DAY,
            CAST(cm.last_purchase_date AS DATE),
            ad.analysis_date
        ) AS recency_days,

        cm.frequency,

        cm.monetary

    FROM customer_metrics AS cm

    CROSS JOIN analysis_date AS ad
),

rfm_scores AS (

    SELECT
        customer_unique_id,

        recency_days,

        frequency,

        monetary,

        -- Lower recency is better.
        -- DESC means older customers receive lower NTILE
        -- values, while more recent customers receive 5.

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS r_score,

        -- Frequency uses explicit rules because the
        -- distribution is extremely skewed.

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS f_score,

        -- Higher monetary value is better.

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM rfm_metrics
)

SELECT
    customer_unique_id,

    recency_days,

    frequency,

    CAST(
        monetary
        AS DECIMAL(18,2)
    ) AS monetary,

    r_score,

    f_score,

    m_score,

    r_score + f_score + m_score
        AS rfm_total_score,

    CONCAT(
        r_score,
        f_score,
        m_score
    ) AS rfm_code

FROM rfm_scores

ORDER BY
    rfm_total_score DESC,
    monetary DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 11
-- ============================================================
--
-- 1. R and M are scored using five distribution-based
--    customer groups.
--
-- 2. For Recency:
--
--    lower recency_days = better
--
--    R = 5 represents the most recent customer group.
--
-- 3. For Monetary:
--
--    higher monetary = better
--
--    M = 5 represents the highest monetary-value group.
--
-- 4. Frequency requires a separate rule because:
--
--    90,557 customers purchased exactly once.
--
-- 5. Explicit Frequency scoring prevents identical
--    one-order customers from being arbitrarily assigned
--    different scores by NTILE().
--
-- 6. Customers with:
--
--    R = 5
--    F = 5
--    M = 5
--
--    receive:
--
--    RFM code = 555
--
-- 7. A 555 customer combines:
--
--    recent activity
--    high purchase frequency
--    high monetary value
--
-- 8. The customer with 15 delivered orders received a
--    555 score because the customer was also recent and
--    belonged to the highest Monetary quintile.
--
-- 9. RFM total score is useful as a summary, but the
--    individual R/F/M scores should also be retained.
--
-- 10. Different RFM combinations can produce the same total
--     score while representing different customer behavior.



-- ============================================================
-- 12. RFM CUSTOMER SEGMENTATION
-- ============================================================
-- Purpose:
--
-- Convert numerical RFM scores into business-friendly
-- customer segments.
--
--
-- IMPORTANT:
--
-- CASE expressions are evaluated from top to bottom.
--
-- The FIRST matching condition determines the final
-- customer segment.
--
--
-- High-Value One-Time customers are limited to:
--
-- F = 1
-- M = 5
--
-- Therefore only one-time customers in the highest
-- Monetary quintile receive this label.
-- ============================================================

WITH analysis_date AS (

    SELECT
        DATEADD(
            DAY,
            1,
            CAST(
                MAX(order_purchase_timestamp)
                AS DATE
            )
        ) AS analysis_date

    FROM dbo.orders

    WHERE order_status = 'delivered'
),

customer_metrics AS (

    SELECT
        c.customer_unique_id,

        MAX(o.order_purchase_timestamp)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(oi.price)
            AS monetary

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
),

rfm_metrics AS (

    SELECT
        cm.customer_unique_id,

        DATEDIFF(
            DAY,
            CAST(cm.last_purchase_date AS DATE),
            ad.analysis_date
        ) AS recency_days,

        cm.frequency,

        cm.monetary

    FROM customer_metrics AS cm

    CROSS JOIN analysis_date AS ad
),

rfm_scores AS (

    SELECT
        customer_unique_id,

        recency_days,

        frequency,

        monetary,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS f_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM rfm_metrics
),

customer_segments AS (

    SELECT
        customer_unique_id,

        recency_days,

        frequency,

        monetary,

        r_score,

        f_score,

        m_score,

        CASE

            -- Recent + frequent + high monetary value.

            WHEN r_score >= 4
             AND f_score >= 4
             AND m_score >= 4
                THEN 'Champions'


            -- Frequent customers who remain reasonably active.

            WHEN r_score >= 3
             AND f_score >= 4
                THEN 'Loyal Customers'


            -- Recent repeat customers that may develop
            -- into stronger long-term customers.

            WHEN r_score >= 4
             AND f_score BETWEEN 2 AND 3
                THEN 'Potential Loyalists'


            -- Recent customers with only one purchase.

            WHEN r_score = 5
             AND f_score = 1
                THEN 'Recent Customers'


            -- Repeat buyers who have not purchased recently.

            WHEN r_score <= 2
             AND f_score >= 2
                THEN 'At Risk'


            -- One-time buyers in the highest monetary quintile.

            WHEN f_score = 1
             AND m_score = 5
                THEN 'High-Value One-Time'


            -- Older customers who purchased only once.

            WHEN r_score <= 2
             AND f_score = 1
                THEN 'Inactive One-Time'


            -- Remaining customers not captured by the more
            -- specific behavioral rules.

            ELSE 'Needs Attention'

        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_unique_id,

    recency_days,

    frequency,

    CAST(
        monetary
        AS DECIMAL(18,2)
    ) AS monetary,

    r_score,

    f_score,

    m_score,

    customer_segment

FROM customer_segments

ORDER BY
    monetary DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 12
-- ============================================================
--
-- 1. RFM scores have been converted into business-friendly
--    customer labels.
--
-- 2. Champions represent customers that combine:
--
--    strong recent activity
--    strong repeat behavior
--    high monetary value
--
-- 3. Potential Loyalists are recent repeat customers that
--    may develop into stronger long-term customers.
--
-- 4. Recent Customers purchased recently but have completed
--    only one delivered order so far.
--
-- 5. At Risk customers previously demonstrated repeat
--    purchasing but have not purchased recently.
--
-- 6. High-Value One-Time customers:
--
--    purchased only once
--
--    AND
--
--    belong to the highest Monetary quintile.
--
-- 7. These customers demonstrate high spending but have not
--    yet demonstrated repeat behavior.
--
-- 8. Inactive One-Time customers purchased once and have
--    remained inactive for a relatively long period.
--
-- 9. Needs Attention is a residual segment containing
--    customers that do not satisfy the more specific
--    segment definitions.
--
-- 10. Needs Attention is therefore less behaviorally
--     homogeneous than the explicitly defined segments.
--
-- 11. CASE order matters because SQL assigns the first
--     matching segment.
--
-- 12. These segment definitions are analytical rules created
--     for this project and are not universal classifications.



-- ============================================================
-- 13. RFM SEGMENT SUMMARY
-- ============================================================
-- Business questions:
--
-- How large is each customer segment?
--
-- How much revenue does each segment generate?
--
-- What are the average behavioral characteristics of
-- each segment?
-- ============================================================

WITH analysis_date AS (

    SELECT
        DATEADD(
            DAY,
            1,
            CAST(
                MAX(order_purchase_timestamp)
                AS DATE
            )
        ) AS analysis_date

    FROM dbo.orders

    WHERE order_status = 'delivered'
),

customer_metrics AS (

    SELECT
        c.customer_unique_id,

        MAX(o.order_purchase_timestamp)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(oi.price)
            AS monetary

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
),

rfm_metrics AS (

    SELECT
        cm.customer_unique_id,

        DATEDIFF(
            DAY,
            CAST(cm.last_purchase_date AS DATE),
            ad.analysis_date
        ) AS recency_days,

        cm.frequency,

        cm.monetary

    FROM customer_metrics AS cm

    CROSS JOIN analysis_date AS ad
),

rfm_scores AS (

    SELECT
        customer_unique_id,

        recency_days,

        frequency,

        monetary,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS f_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM rfm_metrics
),

customer_segments AS (

    SELECT
        *,

        CASE

            WHEN r_score >= 4
             AND f_score >= 4
             AND m_score >= 4
                THEN 'Champions'

            WHEN r_score >= 3
             AND f_score >= 4
                THEN 'Loyal Customers'

            WHEN r_score >= 4
             AND f_score BETWEEN 2 AND 3
                THEN 'Potential Loyalists'

            WHEN r_score = 5
             AND f_score = 1
                THEN 'Recent Customers'

            WHEN r_score <= 2
             AND f_score >= 2
                THEN 'At Risk'

            WHEN f_score = 1
             AND m_score = 5
                THEN 'High-Value One-Time'

            WHEN r_score <= 2
             AND f_score = 1
                THEN 'Inactive One-Time'

            ELSE 'Needs Attention'

        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_segment,

    COUNT(*) AS customer_count,

    CAST(
        100.0 * COUNT(*)
        /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(10,2)
    ) AS customer_share_pct,

    CAST(
        SUM(monetary)
        AS DECIMAL(18,2)
    ) AS revenue,

    CAST(
        100.0 * SUM(monetary)
        /
        SUM(SUM(monetary)) OVER ()
        AS DECIMAL(10,2)
    ) AS revenue_share_pct,

    CAST(
        AVG(monetary)
        AS DECIMAL(18,2)
    ) AS avg_revenue_per_customer,

    CAST(
        AVG(1.0 * frequency)
        AS DECIMAL(10,2)
    ) AS avg_frequency,

    CAST(
        AVG(1.0 * recency_days)
        AS DECIMAL(10,2)
    ) AS avg_recency_days

FROM customer_segments

GROUP BY
    customer_segment

ORDER BY
    revenue DESC;
GO


-- ============================================================
-- RESULTS & FINDINGS - SECTION 13
-- ============================================================
--
--
-- ------------------------------------------------------------
-- HIGH-VALUE ONE-TIME
-- ------------------------------------------------------------
--
-- Customers       = 13,904
-- Customer Share  = 14.89%
-- Revenue         = 5,538,139.21
-- Revenue Share   = 41.89%
-- Avg Revenue     = 398.31
-- Avg Frequency   = 1.00
-- Avg Recency     = 289.39 days
--
-- FINDINGS:
--
-- 1. High-Value One-Time customers are one of the most
--    commercially important customer groups.
--
-- 2. They represent only 14.89% of customers but generate
--    41.89% of total product revenue.
--
-- 3. Their average revenue per customer is 398.31.
--
-- 4. Their main limitation is not monetary value but the
--    absence of repeat purchasing.
--
-- 5. Converting even a portion of this group into repeat
--    buyers may represent a significant customer-value
--    opportunity.
--
--
-- ------------------------------------------------------------
-- RECENT CUSTOMERS
-- ------------------------------------------------------------
--
-- Customers       = 18,048
-- Customer Share  = 19.33%
-- Revenue         = 2,499,946.02
-- Revenue Share   = 18.91%
-- Avg Revenue     = 138.52
-- Avg Frequency   = 1.00
-- Avg Recency     = 45.91 days
--
-- FINDINGS:
--
-- 6. Recent Customers represent almost one-fifth of the
--    customer base.
--
-- 7. Their average recency of approximately 46 days means
--    they purchased relatively recently.
--
-- 8. They have purchased only once so far, making them a
--    potential target for second-purchase conversion.
--
--
-- ------------------------------------------------------------
-- NEEDS ATTENTION
-- ------------------------------------------------------------
--
-- Customers       = 29,957
-- Customer Share  = 32.09%
-- Revenue         = 2,416,462.82
-- Revenue Share   = 18.28%
-- Avg Revenue     = 80.66
-- Avg Frequency   = 1.02
-- Avg Recency     = 179.19 days
--
-- FINDINGS:
--
-- 9. Needs Attention is the largest customer segment by
--    customer count.
--
-- 10. Because this is the residual CASE group, it contains
--     multiple behavior patterns.
--
-- 11. It should therefore not automatically receive one
--     identical business treatment.
--
-- 12. Further segmentation of this group could be considered
--     in a more advanced customer analysis.
--
--
-- ------------------------------------------------------------
-- INACTIVE ONE-TIME
-- ------------------------------------------------------------
--
-- Customers       = 29,247
-- Customer Share  = 31.33%
-- Revenue         = 2,190,628.76
-- Revenue Share   = 16.57%
-- Avg Revenue     = 74.90
-- Avg Frequency   = 1.00
-- Avg Recency     = 395.10 days
--
-- FINDINGS:
--
-- 13. Almost one-third of customers belong to the
--     Inactive One-Time segment.
--
-- 14. They completed only one purchase and have an average
--     recency of approximately 395 days.
--
-- 15. Their average revenue per customer is also relatively
--     low at 74.90.
--
-- 16. They may therefore be a lower-priority retention target
--     than recent or high-value one-time customers.
--
--
-- ------------------------------------------------------------
-- POTENTIAL LOYALISTS
-- ------------------------------------------------------------
--
-- Customers       = 1,170
-- Customer Share  = 1.25%
-- Revenue         = 301,824.79
-- Revenue Share   = 2.28%
-- Avg Revenue     = 257.97
-- Avg Frequency   = 2.08
-- Avg Recency     = 89.30 days
--
-- FINDINGS:
--
-- 17. Potential Loyalists are a small but attractive customer
--     segment.
--
-- 18. They already demonstrate repeat purchasing.
--
-- 19. Their average revenue per customer of 257.97 is
--     substantially higher than the average one-time buyer.
--
-- 20. They may represent strong candidates for loyalty or
--     retention programs.
--
--
-- ------------------------------------------------------------
-- AT RISK
-- ------------------------------------------------------------
--
-- Customers       = 993
-- Customer Share  = 1.06%
-- Revenue         = 246,210.66
-- Revenue Share   = 1.86%
-- Avg Revenue     = 247.95
-- Avg Frequency   = 2.08
-- Avg Recency     = 382.25 days
--
-- FINDINGS:
--
-- 21. At Risk customers previously demonstrated repeat
--     purchasing behavior.
--
-- 22. However, they have an average recency of approximately
--     382 days.
--
-- 23. Their historical revenue per customer remains relatively
--     high.
--
-- 24. They may therefore be stronger win-back candidates than
--     ordinary inactive one-time customers.
--
--
-- ------------------------------------------------------------
-- CHAMPIONS
-- ------------------------------------------------------------
--
-- Customers       = 32
-- Customer Share  = 0.03%
-- Revenue         = 23,436.56
-- Revenue Share   = 0.18%
-- Avg Revenue     = 732.39
-- Avg Frequency   = 4.97
-- Avg Recency     = 83.56 days
--
-- FINDINGS:
--
-- 25. Champions are extremely rare.
--
-- 26. However, their average revenue per customer is very high:
--
--     732.39
--
-- 27. Their average purchase frequency is also high at:
--
--     4.97 orders.
--
-- 28. These customers combine strong purchasing frequency,
--     monetary value, and recent activity.
--
--
-- ------------------------------------------------------------
-- LOYAL CUSTOMERS
-- ------------------------------------------------------------
--
-- Customers       = 7
-- Customer Share  = 0.01%
-- Revenue         = 4,849.29
-- Revenue Share   = 0.04%
-- Avg Revenue     = 692.76
-- Avg Frequency   = 5.57
-- Avg Recency     = 206.71 days
--
-- FINDINGS:
--
-- 29. Loyal Customers are extremely rare in this dataset.
--
-- 30. They have the highest average purchase frequency:
--
--     5.57 orders.
--
-- 31. Their average customer revenue is also very high.
--
--
-- ------------------------------------------------------------
-- OVERALL SEGMENT INTERPRETATION
-- ------------------------------------------------------------
--
-- 32. The customer base is dominated by one-time purchasing.
--
-- 33. High-Value One-Time customers generate a
--     disproportionately large share of total revenue.
--
-- 34. Repeat-oriented customer groups remain very small,
--     consistent with the 3.00% repeat purchase rate.
--
-- 35. One of the strongest customer-development opportunities
--     appears to be converting valuable first-time and recent
--     customers into repeat buyers.



-- ============================================================
-- 14. CUSTOMER ANALYSIS CONSISTENCY CHECK
-- ============================================================
-- Purpose:
--
-- Validate that customer-level aggregation returns the
-- same total customers and revenue as the main Sales Analysis.
--
-- This helps detect:
--
-- missing customer rows
-- duplicated revenue
-- incorrect joins
-- row multiplication
-- ============================================================

WITH customer_metrics AS (

    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(oi.price)
            AS monetary

    FROM dbo.orders AS o

    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
)

SELECT
    COUNT(*) AS total_customers,

    CAST(
        SUM(monetary)
        AS DECIMAL(18,2)
    ) AS total_revenue

FROM customer_metrics;
GO


-- ============================================================
-- EXPECTED RESULTS - SECTION 14
-- ============================================================
--
-- Total Customers = 93,358
-- Total Revenue   = 13,221,498.11
--
--
-- FINDINGS:
--
-- 1. Customer-level aggregation returns the same:
--
--    93,358 unique customers
--
--    as the overall Sales Analysis.
--
-- 2. Customer-level Monetary values aggregate back to:
--
--    13,221,498.11
--
--    matching the Total Revenue KPI.
--
-- 3. This confirms that changing the analysis grain from
--    order-item level to customer level does not lose or
--    duplicate product revenue.
--
-- 4. RFM segment customer counts also sum to:
--
--    93,358
--
-- 5. Segment revenue totals sum back to:
--
--    13,221,498.11
--
-- 6. These checks increase confidence that customer-level
--    transformations have not caused unintended row
--    multiplication.



-- ============================================================
-- FINAL CUSTOMER ANALYSIS SUMMARY
-- ============================================================
--
-- MAIN CUSTOMER KPIs:
--
-- Total Unique Customers:
-- 93,358
--
-- One-Time Customers:
-- 90,557
--
-- Repeat Customers:
-- 2,801
--
-- Repeat Purchase Rate:
-- 3.00%
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 1
-- CUSTOMER BEHAVIOR IS DOMINATED BY ONE-TIME PURCHASING
-- ============================================================
--
-- Approximately 97% of customers completed only one
-- delivered order during the observed dataset period.
--
-- Only approximately 3% completed more than one order.
--
-- This indicates limited repeat purchasing within the
-- observed dataset period.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 2
-- REPEAT CUSTOMERS ARE MORE VALUABLE PER CUSTOMER
-- ============================================================
--
-- Average Revenue per Repeat Customer:
--
-- 260.05
--
-- Average Revenue per One-Time Customer:
--
-- 137.96
--
-- Repeat customers therefore generate substantially more
-- revenue per customer.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 3
-- HIGH-VALUE ONE-TIME CUSTOMERS ARE A MAJOR OPPORTUNITY
-- ============================================================
--
-- High-Value One-Time customers represent:
--
-- 14.89% of customers
--
-- but generate:
--
-- 41.89% of total revenue.
--
-- These customers have already demonstrated strong spending
-- but have not demonstrated repeat purchasing.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 4
-- RECENT CUSTOMERS REPRESENT SECOND-PURCHASE POTENTIAL
-- ============================================================
--
-- Recent Customers represent:
--
-- 19.33% of customers
--
-- with average recency of approximately:
--
-- 46 days.
--
-- These customers may still have a relatively strong
-- opportunity to make a second purchase.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 5
-- LARGE INACTIVE ONE-TIME POPULATION
-- ============================================================
--
-- Inactive One-Time customers represent:
--
-- 31.33% of customers
--
-- with average recency of approximately:
--
-- 395 days.
--
-- This indicates a large population that purchased once
-- and did not return during the observed period.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 6
-- REVENUE IS NOT CONCENTRATED IN A FEW INDIVIDUAL CUSTOMERS
-- ============================================================
--
-- The Top 20 customers generate only:
--
-- 0.81% of total revenue.
--
-- Historical revenue is therefore broadly distributed across
-- the customer base rather than concentrated among a few
-- individuals.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 7
-- CUSTOMER VALUE IS MULTIDIMENSIONAL
-- ============================================================
--
-- The highest-frequency customer is not the highest-revenue
-- customer.
--
-- Several one-time customers generated very high revenue.
--
-- Therefore:
--
-- Frequency alone is insufficient.
--
-- Monetary alone is insufficient.
--
-- Recency alone is insufficient.
--
-- RFM provides a more balanced framework for evaluating
-- customer behavior.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 8
-- GEOGRAPHIC PERFORMANCE DIFFERS BY SCALE AND SPENDING
-- ============================================================
--
-- SP dominates:
--
-- customer count
-- order volume
-- revenue
--
-- However, several much smaller states have substantially
-- higher Average Order Value.
--
-- Therefore:
--
-- market size
--
-- and
--
-- spending intensity
--
-- should be analyzed separately.



-- ============================================================
-- BUSINESS RECOMMENDATIONS
-- ============================================================
--
-- ------------------------------------------------------------
-- 1. HIGH-VALUE ONE-TIME CUSTOMERS
-- ------------------------------------------------------------
--
-- Priority:
-- HIGH
--
-- Why:
--
-- 14.89% of customers
-- 41.89% of total revenue
--
-- Opportunity:
--
-- Encourage a second purchase from customers who have already
-- demonstrated strong willingness to spend.
--
-- Possible actions:
--
-- Personalized post-purchase communication
-- Product recommendations
-- Second-purchase incentives
-- Cross-sell / complementary product campaigns
--
--
-- ------------------------------------------------------------
-- 2. RECENT CUSTOMERS
-- ------------------------------------------------------------
--
-- Priority:
-- HIGH
--
-- Why:
--
-- They purchased recently but have only one order.
--
-- Opportunity:
--
-- Convert first-time customers into repeat buyers while the
-- customer relationship is still relatively recent.
--
-- Possible actions:
--
-- Welcome campaigns
-- Second-purchase offers
-- Personalized recommendations
-- Reminder campaigns
--
--
-- ------------------------------------------------------------
-- 3. POTENTIAL LOYALISTS
-- ------------------------------------------------------------
--
-- Priority:
-- HIGH
--
-- Why:
--
-- These customers already demonstrate repeat behavior.
--
-- Opportunity:
--
-- Encourage them toward stronger loyalty.
--
-- Possible actions:
--
-- Loyalty rewards
-- Personalized recommendations
-- Early-access offers
-- Customer engagement campaigns
--
--
-- ------------------------------------------------------------
-- 4. AT RISK CUSTOMERS
-- ------------------------------------------------------------
--
-- Priority:
-- MEDIUM / HIGH
--
-- Why:
--
-- They previously purchased multiple times but have been
-- inactive for a long period.
--
-- Opportunity:
--
-- Recover customers with demonstrated historical value.
--
-- Possible actions:
--
-- Reactivation campaigns
-- Win-back promotions
-- Personalized reminders
--
--
-- ------------------------------------------------------------
-- 5. CHAMPIONS / LOYAL CUSTOMERS
-- ------------------------------------------------------------
--
-- Priority:
-- RETENTION
--
-- Why:
--
-- They represent some of the strongest combinations of
-- purchase frequency and monetary value.
--
-- Opportunity:
--
-- Protect valuable customer relationships.
--
-- Possible actions:
--
-- Loyalty benefits
-- VIP experiences
-- Personalized recommendations
-- Early-access promotions
--
--
-- ------------------------------------------------------------
-- 6. INACTIVE ONE-TIME CUSTOMERS
-- ------------------------------------------------------------
--
-- Priority:
-- LOWER than recent/high-value customer segments
--
-- Why:
--
-- They represent a very large population but have:
--
-- low frequency
-- long inactivity
-- lower average customer revenue
--
-- Possible actions:
--
-- Lower-cost broad reactivation campaigns
-- Promotional messaging
--
-- Expensive personalized campaigns may be less attractive
-- unless additional customer information suggests higher
-- future value.



-- ============================================================
-- ANALYTICAL CAUTIONS
-- ============================================================
--
-- 1. RFM SEGMENTS ARE RULE-BASED
--
-- The segments used in this project are analytical rules,
-- not machine-learning predictions.
--
--
-- 2. RFM RULES ARE NOT UNIVERSAL
--
-- Segment definitions depend on:
--
-- dataset period
-- customer lifecycle
-- business objectives
-- purchase-frequency distribution
-- monetary distribution
--
--
-- 3. REPEAT PURCHASE RATE IS NOT THE SAME AS RETENTION RATE
--
-- Customers entered the dataset at different times.
--
-- A cohort-based retention analysis would provide a better
-- measurement of how customer retention changes over time.
--
--
-- 4. RFM IS RELATIVE TO THIS DATASET
--
-- R and M scores are based on the distribution of customers
-- in this dataset.
--
-- For example:
--
-- R = 5
--
-- does NOT mean a universally fixed number of days.
--
-- It means the customer belongs to one of the most recent
-- customer groups in this dataset.
--
--
-- 5. FREQUENCY USES CUSTOM THRESHOLDS
--
-- Because customer frequency is extremely skewed, Frequency
-- scoring uses explicit thresholds instead of NTILE().
--
--
-- 6. NEEDS ATTENTION IS A RESIDUAL SEGMENT
--
-- It contains multiple behavior patterns and may need further
-- segmentation before being used for targeted campaigns.
--
--
-- 7. BUSINESS RECOMMENDATIONS ARE ANALYTICAL HYPOTHESES
--
-- In a real company, recommendations should be validated
-- using:
--
-- campaign tests
-- conversion rates
-- profitability
-- marketing cost
-- customer lifetime value
-- controlled experiments
--
-- ============================================================