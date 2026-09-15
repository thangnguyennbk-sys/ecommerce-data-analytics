-- ============================================================
-- E-COMMERCE SALES & CUSTOMER ANALYTICS
-- File: 07_product_analysis.sql
--
-- Purpose:
--   Analyze product and product-category performance using
--   revenue, sales volume, selling price, and revenue
--   concentration.
--
-- BUSINESS RULES:
--
--   1. Only delivered orders are included in completed-sales
--      product analysis.
--
--   2. Revenue is calculated from product item price.
--
--   3. Freight is NOT included in product revenue.
--
--   4. Clean monetary values are taken from:
--      dbo.vw_order_items_clean
--
--   5. Clean category names are taken from:
--      dbo.vw_products_clean
--
--   6. Missing product categories are represented as:
--      'Unknown'
--
--   7. One row in vw_order_items_clean represents one
--      item within an order.
--
--   8. Raw source tables remain unchanged.
--
-- ============================================================

USE ecommerce_analytics;
GO



-- ============================================================
-- 1. PRODUCT KPI SUMMARY
-- ============================================================
-- Business questions:
--
-- How many distinct products generated sales?
--
-- How many item units were sold?
--
-- How many product categories generated sales?
--
-- What was the average observed item selling price?
--
-- What was total product revenue?
-- ============================================================

SELECT
    COUNT(DISTINCT oi.product_id)
        AS products_sold,

    COUNT(*)
        AS units_sold,

    COUNT(DISTINCT p.category_name)
        AS categories_sold,

    CAST(
        AVG(oi.price)
        AS DECIMAL(18,2)
    ) AS average_item_price,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS total_revenue

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

LEFT JOIN dbo.vw_products_clean AS p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered';
GO


-- ============================================================
-- RESULTS - SECTION 1
-- ============================================================
--
-- Products Sold      = 32,216
-- Units Sold         = 110,197
-- Categories Sold    = 74
-- Average Item Price = 119.98
-- Total Revenue      = 13,221,498.11
--
--
-- FINDINGS:
--
-- 1. A total of 32,216 distinct products generated sales
--    from successfully delivered orders.
--
-- 2. These products generated 110,197 item-unit sales.
--
-- 3. Sales were distributed across 74 product categories.
--
-- 4. The average observed item selling price was 119.98.
--
-- 5. Total product revenue was:
--
--    13,221,498.11
--
-- 6. This revenue exactly matches the Total Revenue KPI from
--    the Sales Analysis.
--
-- 7. The consistency confirms that the product-level joins
--    do not introduce missing or duplicated revenue.



-- ============================================================
-- 2. CATEGORY PERFORMANCE
-- ============================================================
-- Business questions:
--
-- Which product categories generate the highest revenue?
--
-- Which categories sell the most units?
--
-- How many distinct products generate sales within each
-- category?
--
-- How many delivered orders contain each category?
--
-- What is the average observed item price by category?
--
-- Revenue per Order:
--
-- Category Revenue
-- ----------------
-- Orders containing the category
--
-- IMPORTANT:
--
-- revenue_per_order is NOT the overall business AOV.
--
-- One order can contain items from multiple categories.
-- ============================================================

SELECT
    p.category_name,

    COUNT(DISTINCT oi.product_id)
        AS products_sold,

    COUNT(*)
        AS units_sold,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS revenue,

    CAST(
        AVG(oi.price)
        AS DECIMAL(18,2)
    ) AS average_item_price,

    CAST(
        SUM(oi.price)
        /
        NULLIF(
            COUNT(DISTINCT o.order_id),
            0
        )
        AS DECIMAL(18,2)
    ) AS revenue_per_order

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

LEFT JOIN dbo.vw_products_clean AS p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered'

GROUP BY
    p.category_name

ORDER BY
    revenue DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 2
-- ============================================================
--
-- 1. health_beauty is the highest-revenue category:
--
--    Products Sold      = 2,397
--    Units Sold         = 9,465
--    Orders             = 8,647
--    Revenue            = 1,233,131.72
--    Average Item Price = 130.28
--
-- 2. watches_gifts ranks second in revenue:
--
--    Revenue            = 1,166,176.98
--    Units Sold         = 5,859
--    Average Item Price = 199.04
--
-- 3. bed_bath_table generates the largest unit volume among
--    the leading categories:
--
--    Units Sold = 10,953
--
--    but ranks below health_beauty and watches_gifts in
--    revenue.
--
-- 4. Therefore, the highest-volume category is not
--    necessarily the highest-revenue category.
--
-- 5. watches_gifts demonstrates a relatively high-value
--    sales pattern:
--
--    lower unit volume than several categories
--
--    but
--
--    high average item price
--
--    resulting in strong total revenue.
--
-- 6. computers is a strong example of a low-volume,
--    high-value category:
--
--    Products Sold      = 30
--    Units Sold         = 199
--    Average Item Price = 1,098.92
--    Revenue per Order  = 1,235.50
--
-- 7. Product categories therefore appear to follow different
--    commercial patterns:
--
--    volume-driven
--
--    value-driven
--
--    or combinations of both.
--
-- 8. Products with missing category metadata remain included
--    under:
--
--    Unknown
--
--    so valid sales revenue is not removed from the analysis.
--
-- 9. Unknown-category products generated approximately:
--
--    170,726.63
--
--    in product revenue.



-- ============================================================
-- 3. TOP 10 CATEGORIES BY REVENUE
-- ============================================================
-- Business question:
--
-- Which product categories generate the most revenue?
--
-- This shorter table is useful for:
--
-- dashboard visualizations
-- portfolio reporting
-- category comparison
-- ============================================================

SELECT TOP 10
    p.category_name,

    COUNT(*) AS units_sold,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS revenue

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

LEFT JOIN dbo.vw_products_clean AS p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered'

GROUP BY
    p.category_name

ORDER BY
    revenue DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 3
-- ============================================================
--
-- Top revenue categories include:
--
-- 1. health_beauty
-- 2. watches_gifts
-- 3. bed_bath_table
-- 4. sports_leisure
-- 5. computers_accessories
-- 6. furniture_decor
-- 7. housewares
-- 8. cool_stuff
-- 9. auto
-- 10. toys
--
--
-- 1. health_beauty is the highest-revenue category,
--    generating:
--
--    1,233,131.72
--
-- 2. watches_gifts ranks second with:
--
--    1,166,176.98
--
-- 3. bed_bath_table ranks third with:
--
--    1,023,434.76
--
-- 4. The highest-revenue categories are not necessarily
--    the categories with the highest unit sales.
--
-- 5. watches_gifts is an important value-driven example:
--
--    Units Sold         = 5,859
--    Revenue            = 1,166,176.98
--    Average Item Price = 199.04
--
-- 6. Category revenue is therefore influenced by both:
--
--    number of units sold
--
--    and
--
--    item selling value.



-- ============================================================
-- 4. TOP 10 CATEGORIES BY UNITS SOLD
-- ============================================================
-- Business question:
--
-- Which product categories sell the highest number of
-- individual item units?
--
-- Comparing this result with revenue ranking helps
-- distinguish:
--
-- volume-driven categories
--
-- from
--
-- value-driven categories.
-- ============================================================

SELECT TOP 10
    p.category_name,

    COUNT(*) AS units_sold,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS revenue,

    CAST(
        AVG(oi.price)
        AS DECIMAL(18,2)
    ) AS average_item_price

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

LEFT JOIN dbo.vw_products_clean AS p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered'

GROUP BY
    p.category_name

ORDER BY
    units_sold DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 4
-- ============================================================
--
-- 1. bed_bath_table is the highest-volume category:
--
--    Units Sold = 10,953
--
-- 2. health_beauty ranks second by units:
--
--    Units Sold = 9,465
--
-- 3. sports_leisure and furniture_decor also generate
--    substantial unit volume.
--
-- 4. bed_bath_table leads sales volume but does NOT lead
--    total revenue.
--
-- 5. health_beauty generates more revenue despite selling
--    fewer units because its observed average item price
--    is higher:
--
--    health_beauty  = 130.28
--    bed_bath_table = 93.44
--
-- 6. watches_gifts ranks only seventh among the Top 10
--    categories by units sold but ranks second by revenue.
--
-- 7. Its relatively high average item price:
--
--    199.04
--
--    helps explain the difference.
--
-- 8. telephony is a stronger volume-oriented category:
--
--    Units Sold         = 4,430
--    Average Item Price = 69.95
--
-- 9. Product performance should therefore be evaluated using
--    both unit volume and revenue.
--
-- 10. Units sold alone can undervalue expensive categories,
--     while revenue alone can hide important high-volume
--     categories.



-- ============================================================
-- 5. CATEGORY REVENUE CONTRIBUTION
-- ============================================================
-- Business questions:
--
-- What percentage of total product revenue is generated
-- by each category?
--
-- Is revenue concentrated in a small number of categories?
--
-- cumulative_revenue_share_pct shows how much total revenue
-- is accounted for as categories are added from highest to
-- lowest revenue.
-- ============================================================

WITH category_revenue AS (

    SELECT
        p.category_name,

        SUM(oi.price)
            AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    LEFT JOIN dbo.vw_products_clean AS p
        ON oi.product_id = p.product_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        p.category_name
),

category_contribution AS (

    SELECT
        category_name,

        revenue,

        100.0 * revenue
        /
        NULLIF(
            SUM(revenue) OVER (),
            0
        ) AS revenue_share_pct

    FROM category_revenue
)

SELECT
    category_name,

    CAST(
        revenue
        AS DECIMAL(18,2)
    ) AS revenue,

    CAST(
        revenue_share_pct
        AS DECIMAL(10,2)
    ) AS revenue_share_pct,

    CAST(
        SUM(revenue_share_pct) OVER (
            ORDER BY revenue DESC
            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        )
        AS DECIMAL(10,2)
    ) AS cumulative_revenue_share_pct

FROM category_contribution

ORDER BY
    revenue DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 5
-- ============================================================
--
-- 1. health_beauty is the largest category contributor:
--
--    Revenue Share = 9.33%
--
-- 2. watches_gifts contributes:
--
--    8.82%
--
-- 3. bed_bath_table contributes:
--
--    7.74%
--
-- 4. The Top 5 categories together generate approximately:
--
--    39.83%
--
--    of total product revenue.
--
-- 5. The Top 10 categories generate approximately:
--
--    62.43%
--
--    of total product revenue.
--
-- 6. The Top 20 categories generate approximately:
--
--    84.06%
--
--    of total product revenue.
--
-- 7. Product revenue is therefore moderately concentrated
--    among the major categories.
--
-- 8. However, no single category dominates the business.
--
-- 9. The highest-revenue category contributes less than:
--
--    10%
--
--    of total revenue.
--
-- 10. This suggests category-level diversification rather
--     than dependence on one dominant category.
--
-- 11. Unknown-category products contribute approximately:
--
--     1.29%
--
--     of total revenue.
--
-- 12. They remain included so valid sales are not discarded
--     because of incomplete product metadata.



-- ============================================================
-- 6. TOP 20 PRODUCTS BY REVENUE
-- ============================================================
-- Business questions:
--
-- Which individual products generate the most revenue?
--
-- Are the highest-revenue products also the products
-- with the highest sales volume?
-- ============================================================

SELECT TOP 20
    oi.product_id,

    p.category_name,

    COUNT(*)
        AS units_sold,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS revenue,

    CAST(
        AVG(oi.price)
        AS DECIMAL(18,2)
    ) AS average_item_price

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

LEFT JOIN dbo.vw_products_clean AS p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered'

GROUP BY
    oi.product_id,
    p.category_name

ORDER BY
    revenue DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 6
-- ============================================================
--
-- 1. The highest-revenue individual product belongs to:
--
--    health_beauty
--
-- 2. It generated:
--
--    Revenue            = 63,560.00
--    Units Sold         = 194
--    Average Item Price = 327.63
--
-- 3. The second-highest-revenue product is also from
--    health_beauty:
--
--    Revenue = 53,652.30
--
-- 4. Several high-revenue products generate strong revenue
--    despite relatively low unit volume because of higher
--    selling prices.
--
-- 5. A computers product generated:
--
--    Revenue            = 45,949.35
--    Units Sold         = 33
--    Average Item Price = 1,392.40
--
-- 6. A musical_instruments product generated:
--
--    Revenue            = 25,034.00
--    Units Sold         = 13
--    Average Item Price = 1,925.69
--
-- 7. These examples demonstrate that strong revenue can be
--    created through:
--
--    high unit volume
--
--    OR
--
--    high item value.
--
-- 8. The highest-revenue product is NOT the product with
--    the highest unit sales.



-- ============================================================
-- 7. TOP 20 PRODUCTS BY UNITS SOLD
-- ============================================================
-- Business question:
--
-- Which individual products sell the highest number
-- of item units?
--
-- Comparing this ranking with revenue ranking helps show
-- differences between product volume and product value.
-- ============================================================

SELECT TOP 20
    oi.product_id,

    p.category_name,

    COUNT(*)
        AS units_sold,

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    CAST(
        SUM(oi.price)
        AS DECIMAL(18,2)
    ) AS revenue,

    CAST(
        AVG(oi.price)
        AS DECIMAL(18,2)
    ) AS average_item_price

FROM dbo.orders AS o

INNER JOIN dbo.vw_order_items_clean AS oi
    ON o.order_id = oi.order_id

LEFT JOIN dbo.vw_products_clean AS p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered'

GROUP BY
    oi.product_id,
    p.category_name

ORDER BY
    units_sold DESC;
GO


-- ============================================================
-- FINDINGS - SECTION 7
-- ============================================================
--
-- 1. The highest-volume individual product belongs to:
--
--    furniture_decor
--
-- 2. It generated:
--
--    Units Sold         = 520
--    Revenue            = 37,104.30
--    Average Item Price = 71.35
--
-- 3. Despite selling the highest number of units, this
--    product does not generate the highest product revenue.
--
-- 4. Several garden_tools products appear among the
--    highest-volume individual products.
--
-- 5. These garden_tools products generally have observed
--    average prices around the mid-50 range.
--
-- 6. This suggests a more volume-driven product pattern.
--
-- 7. The highest-revenue health_beauty product sold:
--
--    194 units
--
--    but generated:
--
--    63,560.00
--
--    because its observed average selling price was:
--
--    327.63
--
-- 8. A computers_accessories product performs strongly
--    across both volume and revenue:
--
--    Units Sold = 332
--    Revenue    = 45,620.56
--
-- 9. Units sold alone can undervalue expensive products.
--
-- 10. Revenue alone can also hide products that generate
--     significant transaction volume.
--
-- 11. Product performance should therefore be evaluated
--     using both volume and value measures.



-- ============================================================
-- 8. PRODUCT REVENUE CONCENTRATION
-- ============================================================
-- Business question:
--
-- How much total revenue is generated by the Top 20
-- highest-revenue individual products?
--
-- This helps determine whether the business depends heavily
-- on a small number of individual products.
-- ============================================================

WITH product_revenue AS (

    SELECT
        oi.product_id,

        SUM(oi.price)
            AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        oi.product_id
),

ranked_products AS (

    SELECT
        product_id,

        revenue,

        ROW_NUMBER() OVER (
            ORDER BY revenue DESC
        ) AS revenue_rank

    FROM product_revenue
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
    ) AS top_20_product_revenue,

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
        NULLIF(
            SUM(revenue),
            0
        )
        AS DECIMAL(10,2)
    ) AS top_20_revenue_share_pct

FROM ranked_products;
GO


-- ============================================================
-- RESULTS - SECTION 8
-- ============================================================
--
-- Top 20 Product Revenue = 720,405.30
-- Total Revenue          = 13,221,498.11
-- Revenue Share          = 5.45%
--
--
-- FINDINGS:
--
-- 1. The Top 20 highest-revenue individual products generate
--    only approximately:
--
--    5.45%
--
--    of total product revenue.
--
-- 2. Revenue is therefore not heavily concentrated among
--    a small number of individual products.
--
-- 3. This contrasts strongly with category-level revenue
--    concentration:
--
--    Top 10 Categories = 62.43% of revenue
--
--    Top 20 Products   = 5.45% of revenue
--
-- 4. Revenue is therefore relatively concentrated across
--    major product categories while remaining broadly
--    distributed across individual products inside those
--    categories.
--
-- 5. The business does not appear highly dependent on a
--    small set of individual best-selling products.



-- ============================================================
-- 9. PRODUCT ANALYSIS CONSISTENCY CHECK
-- ============================================================
-- Purpose:
--
-- Validate that product-level aggregation returns the same
-- Total Revenue KPI as the Sales and Customer analyses.
--
-- This helps detect:
--
-- missing rows
-- incorrect joins
-- duplicated item records
-- unexpected row multiplication
-- ============================================================

WITH product_revenue AS (

    SELECT
        oi.product_id,

        SUM(oi.price)
            AS revenue

    FROM dbo.orders AS o

    INNER JOIN dbo.vw_order_items_clean AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        oi.product_id
)

SELECT
    COUNT(*) AS products_sold,

    CAST(
        SUM(revenue)
        AS DECIMAL(18,2)
    ) AS total_revenue

FROM product_revenue;
GO


-- ============================================================
-- EXPECTED RESULTS - SECTION 9
-- ============================================================
--
-- Products Sold = 32,216
--
-- Total Revenue = 13,221,498.11
--
--
-- FINDINGS:
--
-- 1. Product-level aggregation returns:
--
--    32,216
--
--    distinct products with delivered sales.
--
-- 2. Product-level revenue aggregates back to:
--
--    13,221,498.11
--
-- 3. This matches the overall Total Revenue KPI from:
--
--    05_sales_analysis.sql
--
--    and
--
--    06_customer_analysis.sql
--
-- 4. This consistency increases confidence that product
--    joins and aggregations have not caused revenue
--    duplication or loss.



-- ============================================================
-- FINAL PRODUCT ANALYSIS SUMMARY
-- ============================================================
--
-- MAIN PRODUCT KPIs:
--
-- Distinct Products Sold:
-- 32,216
--
-- Units Sold:
-- 110,197
--
-- Categories Sold:
-- 74
--
-- Average Item Price:
-- 119.98
--
-- Total Product Revenue:
-- 13,221,498.11
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 1
-- CATEGORY REVENUE AND SALES VOLUME ARE NOT THE SAME
-- ============================================================
--
-- health_beauty generated the highest category revenue:
--
-- 1,233,131.72
--
-- while bed_bath_table generated the highest unit volume:
--
-- 10,953 units.
--
-- This demonstrates that high unit volume does not
-- automatically imply the highest revenue.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 2
-- PRODUCT VALUE STRONGLY AFFECTS REVENUE PERFORMANCE
-- ============================================================
--
-- watches_gifts ranks second in category revenue despite
-- being only seventh among the Top 10 categories by
-- unit sales.
--
-- Its average observed item price:
--
-- 199.04
--
-- helps explain its strong revenue performance.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 3
-- CATEGORIES FOLLOW DIFFERENT SALES PATTERNS
-- ============================================================
--
-- Examples of more volume-oriented categories include:
--
-- bed_bath_table
-- furniture_decor
-- telephony
--
-- Examples of higher-value categories include:
--
-- watches_gifts
-- computers
-- musical_instruments
--
-- Some categories depend more heavily on sales volume,
-- while others generate meaningful revenue through higher
-- item values.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 4
-- TOP PRODUCTS ALSO SHOW VOLUME VS VALUE DIFFERENCES
-- ============================================================
--
-- Highest-revenue product:
--
-- Category           = health_beauty
-- Units Sold         = 194
-- Revenue            = 63,560.00
-- Average Item Price = 327.63
--
--
-- Highest-volume product:
--
-- Category           = furniture_decor
-- Units Sold         = 520
-- Revenue            = 37,104.30
-- Average Item Price = 71.35
--
-- The highest-volume product is therefore not the
-- highest-revenue product.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 5
-- SOME PRODUCTS ARE STRONGLY VALUE-DRIVEN
-- ============================================================
--
-- A computers product generated:
--
-- Revenue = 45,949.35
--
-- from only:
--
-- 33 units
--
-- with an average observed item price of:
--
-- 1,392.40
--
--
-- A musical_instruments product generated:
--
-- Revenue = 25,034.00
--
-- from only:
--
-- 13 units
--
-- with an average observed item price of:
--
-- 1,925.69
--
-- Low-volume products can therefore still contribute
-- meaningful revenue when individual item values are high.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 6
-- CATEGORY REVENUE IS MODERATELY CONCENTRATED
-- ============================================================
--
-- Top 5 Categories:
--
-- 39.83% of total revenue
--
-- Top 10 Categories:
--
-- 62.43% of total revenue
--
-- Top 20 Categories:
--
-- 84.06% of total revenue
--
-- However, the largest individual category contributes only:
--
-- 9.33%
--
-- Therefore the product portfolio is concentrated among
-- several important categories rather than dominated by
-- one single category.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 7
-- INDIVIDUAL PRODUCT REVENUE IS BROADLY DISTRIBUTED
-- ============================================================
--
-- The Top 20 products generate only:
--
-- 5.45%
--
-- of total revenue.
--
-- This indicates that revenue is spread across a broad
-- range of individual products.
--
-- Category-level concentration is therefore much stronger
-- than individual-product concentration.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 8
-- MISSING CATEGORY DATA HAS LIMITED BUT REAL IMPACT
-- ============================================================
--
-- Products categorized as:
--
-- Unknown
--
-- generated approximately:
--
-- 170,726.63
--
-- representing approximately:
--
-- 1.29%
--
-- of total product revenue.
--
-- These products were retained so valid sales revenue
-- would not be lost because of missing metadata.



-- ============================================================
-- BUSINESS RECOMMENDATIONS
-- ============================================================
--
-- 1. PROTECT HIGH-REVENUE CATEGORIES
--
-- Major categories such as:
--
-- health_beauty
-- watches_gifts
-- bed_bath_table
-- sports_leisure
-- computers_accessories
--
-- should receive close monitoring for:
--
-- product availability
-- assortment quality
-- pricing changes
-- sales trends
--
--
-- 2. DISTINGUISH VOLUME-DRIVEN AND VALUE-DRIVEN PRODUCTS
--
-- High-volume categories should not automatically be
-- evaluated using the same criteria as higher-value
-- categories.
--
-- Volume-oriented categories may benefit from:
--
-- strong product availability
-- efficient fulfillment
-- cross-selling opportunities
--
-- Higher-value categories may benefit from:
--
-- premium positioning
-- targeted product recommendations
-- stronger customer trust
-- high-quality product information
--
--
-- 3. DO NOT RELY ONLY ON UNITS SOLD
--
-- Units sold alone can undervalue expensive products.
--
-- Revenue alone can also hide products that generate
-- substantial transaction volume.
--
-- Product performance should consider both:
--
-- unit volume
--
-- and
--
-- revenue value.
--
--
-- 4. MAINTAIN CATEGORY DIVERSIFICATION
--
-- No single category contributes more than 10% of total
-- revenue.
--
-- This reduces dependence on one product category.
--
--
-- 5. INVESTIGATE UNKNOWN PRODUCT METADATA
--
-- Unknown-category products contribute approximately:
--
-- 1.29%
--
-- of total revenue.
--
-- Improving metadata quality could improve category
-- reporting while preserving valid transactions.
--
--
-- 6. MONITOR CATEGORY-LEVEL PERFORMANCE MORE THAN ONLY
--    INDIVIDUAL TOP PRODUCTS
--
-- Top 10 categories generate:
--
-- 62.43%
--
-- of revenue.
--
-- Top 20 individual products generate only:
--
-- 5.45%
--
-- of revenue.
--
-- Category-level monitoring may therefore provide a more
-- useful strategic view than focusing only on a small set
-- of individual products.



-- ============================================================
-- ANALYTICAL CAUTIONS
-- ============================================================
--
-- 1. REVENUE IS NOT PROFIT
--
-- This dataset does not contain:
--
-- product cost
-- gross margin
-- inventory cost
-- marketing cost
--
-- Therefore a high-revenue product cannot automatically be
-- described as a high-profit product.
--
--
-- 2. LOW REVENUE DOES NOT AUTOMATICALLY MEAN POOR
--    PRODUCT PERFORMANCE
--
-- A product may have:
--
-- niche demand
-- limited availability
-- fewer selling periods
-- fewer products within its category
--
-- Additional business context would be required before
-- recommending product removal.
--
--
-- 3. AVERAGE ITEM PRICE IS DESCRIPTIVE
--
-- average_item_price reflects the average observed selling
-- price in delivered order-item records.
--
-- It should not automatically be interpreted as an official
-- catalog or list price.
--
--
-- 4. ONLY DELIVERED ORDERS ARE INCLUDED
--
-- Cancelled, unavailable, and incomplete orders are excluded
-- from the main product-sales KPIs.
--
--
-- 5. CATEGORY PERFORMANCE MAY BE AFFECTED BY CATEGORY SIZE
--
-- Categories contain different numbers of products.
--
-- A category with more available products may naturally
-- generate greater total volume or revenue.
--
--
-- 6. UNKNOWN CATEGORY RECORDS ARE RETAINED
--
-- They are kept in the analysis to preserve valid sales
-- revenue rather than deleting transactions because of
-- incomplete product metadata.
--
--
-- ============================================================
-- END OF PRODUCT ANALYSIS
-- ============================================================