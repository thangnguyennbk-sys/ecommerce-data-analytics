-- ============================================================
-- E-COMMERCE SALES & CUSTOMER ANALYTICS
-- File: 03_data_quality_checks.sql
-- Purpose:
--   Validate data quality before business analysis.
--
-- Data quality dimensions checked:
--   1. Schema
--   2. Row counts
--   3. Duplicate / key uniqueness
--   4. Missing values
--   5. Invalid numeric values
--   6. Categorical values
--   7. Date consistency
--   8. Referential integrity
--   9. Product category mapping
--
-- IMPORTANT:
--   Raw data is NOT modified in this file.
-- ============================================================

USE ecommerce_analytics;
GO


-- ============================================================
-- 1. SCHEMA CHECK
-- Check the datatypes created by SSMS Import Flat File
-- ============================================================

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
        'customers',
        'orders',
        'order_items',
        'products',
        'payments',
        'reviews',
        'category_translation'
    )
ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;
GO


-- ============================================================
-- 2. ROW COUNT
-- Confirm that all tables were imported successfully
-- ============================================================

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM dbo.customers

UNION ALL
SELECT 'orders', COUNT(*)
FROM dbo.orders

UNION ALL
SELECT 'order_items', COUNT(*)
FROM dbo.order_items

UNION ALL
SELECT 'products', COUNT(*)
FROM dbo.products

UNION ALL
SELECT 'payments', COUNT(*)
FROM dbo.payments

UNION ALL
SELECT 'reviews', COUNT(*)
FROM dbo.reviews

UNION ALL
SELECT 'category_translation', COUNT(*)
FROM dbo.category_translation;
GO


-- ============================================================
-- 3. KEY / DUPLICATE CHECKS
-- ============================================================

-- customers:
-- customer_id should identify one row
SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM dbo.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
GO


-- orders:
-- order_id should identify one order
SELECT
    order_id,
    COUNT(*) AS duplicate_count
FROM dbo.orders
GROUP BY order_id
HAVING COUNT(*) > 1;
GO


-- products:
-- product_id should identify one product
SELECT
    product_id,
    COUNT(*) AS duplicate_count
FROM dbo.products
GROUP BY product_id
HAVING COUNT(*) > 1;
GO


-- order_items:
-- one order can contain many items.
-- Therefore the expected unique key is:
-- order_id + order_item_id
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS duplicate_count
FROM dbo.order_items
GROUP BY
    order_id,
    order_item_id
HAVING COUNT(*) > 1;
GO


-- payments:
-- one order can have multiple payment records.
-- Expected unique key:
-- order_id + payment_sequential
SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS duplicate_count
FROM dbo.payments
GROUP BY
    order_id,
    payment_sequential
HAVING COUNT(*) > 1;
GO


-- Review IDs:
-- Profile duplicates before deciding whether they are problematic
SELECT
    review_id,
    COUNT(*) AS duplicate_count
FROM dbo.reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
GO


-- Orders can potentially have more than one review record.
-- Investigate rather than assuming order_id is unique in reviews.
SELECT
    order_id,
    COUNT(*) AS review_count
FROM dbo.reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC;
GO


-- Category translation:
-- category names should normally have one translation
SELECT
    product_category_name,
    COUNT(*) AS duplicate_count
FROM dbo.category_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;
GO


-- ============================================================
-- 4. NULL CHECK - CUSTOMERS
-- ============================================================

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE
        WHEN customer_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_customer_id,

    SUM(CASE
        WHEN customer_unique_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_customer_unique_id,

    SUM(CASE
        WHEN customer_city IS NULL
        THEN 1 ELSE 0
    END) AS missing_city,

    SUM(CASE
        WHEN customer_state IS NULL
        THEN 1 ELSE 0
    END) AS missing_state

FROM dbo.customers;
GO


-- ============================================================
-- 5. NULL CHECK - ORDERS
-- ============================================================

SELECT
    COUNT(*) AS total_orders,

    SUM(CASE
        WHEN order_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_order_id,

    SUM(CASE
        WHEN customer_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_customer_id,

    SUM(CASE
        WHEN order_status IS NULL
        THEN 1 ELSE 0
    END) AS missing_order_status,

    SUM(CASE
        WHEN order_purchase_timestamp IS NULL
        THEN 1 ELSE 0
    END) AS missing_purchase_timestamp,

    SUM(CASE
        WHEN order_approved_at IS NULL
        THEN 1 ELSE 0
    END) AS missing_approved_at,

    SUM(CASE
        WHEN order_delivered_carrier_date IS NULL
        THEN 1 ELSE 0
    END) AS missing_carrier_date,

    SUM(CASE
        WHEN order_delivered_customer_date IS NULL
        THEN 1 ELSE 0
    END) AS missing_customer_delivery_date,

    SUM(CASE
        WHEN order_estimated_delivery_date IS NULL
        THEN 1 ELSE 0
    END) AS missing_estimated_delivery_date

FROM dbo.orders;
GO


-- ============================================================
-- 6. INVESTIGATE NULL DELIVERY DATES
--
-- NULL does NOT automatically mean bad data.
-- A canceled/unavailable order may legitimately have no delivery.
-- ============================================================

SELECT
    order_status,
    COUNT(*) AS orders_without_delivery_date
FROM dbo.orders
WHERE order_delivered_customer_date IS NULL
GROUP BY order_status
ORDER BY orders_without_delivery_date DESC;
GO


-- Suspicious case:
-- An order marked as delivered should normally have
-- a customer delivery timestamp.
SELECT
    COUNT(*) AS delivered_orders_missing_delivery_date
FROM dbo.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
GO


-- Investigate missing approval timestamps
SELECT
    order_status,
    COUNT(*) AS orders_without_approval_date
FROM dbo.orders
WHERE order_approved_at IS NULL
GROUP BY order_status
ORDER BY orders_without_approval_date DESC;
GO


-- ============================================================
-- 7. ORDER STATUS PROFILE
-- ============================================================

SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_orders
FROM dbo.orders
GROUP BY order_status
ORDER BY total_orders DESC;
GO


-- ============================================================
-- 8. NULL CHECK - PRODUCTS
-- ============================================================

SELECT
    COUNT(*) AS total_products,

    SUM(CASE
        WHEN product_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_product_id,

    SUM(CASE
        WHEN product_category_name IS NULL
        THEN 1 ELSE 0
    END) AS missing_category,

    SUM(CASE
        WHEN product_name_lenght IS NULL
        THEN 1 ELSE 0
    END) AS missing_name_length,

    SUM(CASE
        WHEN product_description_lenght IS NULL
        THEN 1 ELSE 0
    END) AS missing_description_length,

    SUM(CASE
        WHEN product_photos_qty IS NULL
        THEN 1 ELSE 0
    END) AS missing_photo_qty,

    SUM(CASE
        WHEN product_weight_g IS NULL
        THEN 1 ELSE 0
    END) AS missing_weight,

    SUM(CASE
        WHEN product_length_cm IS NULL
        THEN 1 ELSE 0
    END) AS missing_length,

    SUM(CASE
        WHEN product_height_cm IS NULL
        THEN 1 ELSE 0
    END) AS missing_height,

    SUM(CASE
        WHEN product_width_cm IS NULL
        THEN 1 ELSE 0
    END) AS missing_width

FROM dbo.products;
GO


-- ============================================================
-- 9. PRODUCT NULL PATTERN
-- Check whether missing metadata tends to occur together
-- ============================================================

SELECT TOP 100
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM dbo.products
WHERE product_category_name IS NULL
   OR product_name_lenght IS NULL
   OR product_description_lenght IS NULL
   OR product_photos_qty IS NULL
   OR product_weight_g IS NULL;
GO


-- ============================================================
-- 10. NULL CHECK - ORDER ITEMS
-- ============================================================

SELECT
    COUNT(*) AS total_order_items,

    SUM(CASE
        WHEN order_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_order_id,

    SUM(CASE
        WHEN product_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_product_id,

    SUM(CASE
        WHEN seller_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_seller_id,

    SUM(CASE
        WHEN price IS NULL
        THEN 1 ELSE 0
    END) AS missing_price,

    SUM(CASE
        WHEN freight_value IS NULL
        THEN 1 ELSE 0
    END) AS missing_freight_value

FROM dbo.order_items;
GO


-- ============================================================
-- 11. INVALID NUMERIC VALUES - ORDER ITEMS
-- ============================================================

-- Product price should not be zero or negative
SELECT *
FROM dbo.order_items
WHERE price <= 0;
GO


-- Freight can legitimately be zero,
-- but a negative freight value would be invalid.
SELECT *
FROM dbo.order_items
WHERE freight_value < 0;
GO


-- Inspect value ranges
SELECT
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    AVG(CAST(price AS DECIMAL(18,2))) AS avg_price,

    MIN(freight_value) AS min_freight,
    MAX(freight_value) AS max_freight

FROM dbo.order_items;
GO


-- ============================================================
-- 12. PAYMENT QUALITY
-- ============================================================

SELECT
    COUNT(*) AS total_payments,

    SUM(CASE
        WHEN order_id IS NULL
        THEN 1 ELSE 0
    END) AS missing_order_id,

    SUM(CASE
        WHEN payment_type IS NULL
        THEN 1 ELSE 0
    END) AS missing_payment_type,

    SUM(CASE
        WHEN payment_value IS NULL
        THEN 1 ELSE 0
    END) AS missing_payment_value

FROM dbo.payments;
GO


-- Negative payments would be suspicious/invalid
SELECT *
FROM dbo.payments
WHERE payment_value < 0;
GO


-- Zero payments are not automatically deleted.
-- Investigate them separately.
SELECT *
FROM dbo.payments
WHERE payment_value = 0;
GO


-- Profile payment types
SELECT
    payment_type,
    COUNT(*) AS payment_records,
    SUM(payment_value) AS total_payment_value
FROM dbo.payments
GROUP BY payment_type
ORDER BY payment_records DESC;
GO


-- ============================================================
-- 13. REVIEWS QUALITY
-- ============================================================

SELECT
    COUNT(*) AS total_reviews,

    SUM(CASE
        WHEN review_score IS NULL
        THEN 1 ELSE 0
    END) AS missing_review_score,

    SUM(CASE
        WHEN review_comment_title IS NULL
        THEN 1 ELSE 0
    END) AS missing_comment_title,

    SUM(CASE
        WHEN review_comment_message IS NULL
        THEN 1 ELSE 0
    END) AS missing_comment_message

FROM dbo.reviews;
GO


-- Review scores should normally be between 1 and 5
SELECT
    review_score,
    COUNT(*) AS review_count
FROM dbo.reviews
GROUP BY review_score
ORDER BY review_score;
GO


-- Explicitly find invalid scores if any
SELECT *
FROM dbo.reviews
WHERE review_score < 1
   OR review_score > 5;
GO


-- IMPORTANT:
-- NULL comments are normally acceptable.
-- Customers can leave a rating without writing text.


-- ============================================================
-- 14. DATE RANGE
-- ============================================================

SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date
FROM dbo.orders;
GO


-- ============================================================
-- 15. DATE CONSISTENCY CHECKS
-- ============================================================

-- Approval should normally not happen before purchase
SELECT
    COUNT(*) AS approval_before_purchase
FROM dbo.orders
WHERE order_approved_at IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_approved_at < order_purchase_timestamp;
GO


-- Customer delivery should not happen before purchase
SELECT
    COUNT(*) AS delivery_before_purchase
FROM dbo.orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp;
GO


-- Customer delivery should normally not happen
-- before handoff to the carrier
SELECT
    COUNT(*) AS delivery_before_carrier
FROM dbo.orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date <
      order_delivered_carrier_date;
GO


-- ============================================================
-- 16. REFERENTIAL INTEGRITY
-- Check whether child records have matching parent records
-- ============================================================

-- Orders without customer
SELECT
    COUNT(*) AS orders_without_customer
FROM dbo.orders AS o
LEFT JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
GO


-- Order items without order
SELECT
    COUNT(*) AS items_without_order
FROM dbo.order_items AS oi
LEFT JOIN dbo.orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


-- Order items without product
SELECT
    COUNT(*) AS items_without_product
FROM dbo.order_items AS oi
LEFT JOIN dbo.products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
GO


-- Payments without order
SELECT
    COUNT(*) AS payments_without_order
FROM dbo.payments AS pay
LEFT JOIN dbo.orders AS o
    ON pay.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


-- Reviews without order
SELECT
    COUNT(*) AS reviews_without_order
FROM dbo.reviews AS r
LEFT JOIN dbo.orders AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


-- ============================================================
-- 17. CATEGORY TRANSLATION QUALITY
-- ============================================================

-- NULL / blank translations
SELECT *
FROM dbo.category_translation
WHERE product_category_name IS NULL
   OR product_category_name_english IS NULL
   OR LTRIM(RTRIM(product_category_name)) = ''
   OR LTRIM(RTRIM(product_category_name_english)) = '';
GO


-- Categories used by products but missing
-- from the English translation table
SELECT DISTINCT
    p.product_category_name
FROM dbo.products AS p
LEFT JOIN dbo.category_translation AS ct
    ON p.product_category_name =
       ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL
ORDER BY p.product_category_name;
GO


-- ============================================================
-- 18. FINAL CORE JOIN VALIDATION
-- Verify that the central analytical data model works
-- ============================================================

SELECT TOP 20
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,

    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    oi.order_item_id,
    oi.product_id,
    oi.price,
    oi.freight_value,

    p.product_category_name,

    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name

FROM dbo.orders AS o

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

INNER JOIN dbo.order_items AS oi
    ON o.order_id = oi.order_id

LEFT JOIN dbo.products AS p
    ON oi.product_id = p.product_id

LEFT JOIN dbo.category_translation AS ct
    ON p.product_category_name =
       ct.product_category_name;
GO


-- ============================================================
-- DATA QUALITY TREATMENT RULES
-- ============================================================

-- RULE 1:
-- Do not delete NULL delivery dates globally.
-- Non-delivered orders can legitimately have NULL delivery dates.

-- RULE 2:
-- Delivery KPIs will only use successfully delivered orders
-- with valid delivery timestamps.

-- RULE 3:
-- Missing product categories will NOT cause sales rows
-- to be removed.
-- In reports they will be labeled as "Unknown".

-- RULE 4:
-- Missing review comments are valid and will remain NULL.
-- Review score analysis does not require written comments.

-- RULE 5:
-- Raw imported tables will remain unchanged.
-- Cleaning / transformations will occur in analysis queries,
-- views, Python, or Power BI.

-- RULE 6:
-- Any suspicious duplicate, orphan record, invalid numeric
-- value, or inconsistent date discovered above must be
-- investigated before being excluded.
-- ============================================================
-- 19. ADDITIONAL REVIEW DUPLICATE INVESTIGATION
-- ============================================================

-- review_id alone is NOT unique in the raw reviews table.
-- Check whether the combination review_id + order_id is unique.

SELECT
    review_id,
    order_id,
    COUNT(*) AS duplicate_count
FROM dbo.reviews
GROUP BY
    review_id,
    order_id
HAVING COUNT(*) > 1;
GO


-- FINDING:
-- Some review_id values appear multiple times and may be
-- associated with different order_id values.
-- Some orders also contain multiple review records.
--
-- TREATMENT:
-- Keep the raw reviews table unchanged.
-- Do not use review_id alone as a primary key.
-- Before order-level customer satisfaction analysis,
-- reviews will be transformed to one analytical record
-- per order to avoid double counting.


-- ============================================================
-- 20. PRODUCT NULL PATTERN SUMMARY
-- ============================================================

SELECT
    SUM(
        CASE
            WHEN product_category_name IS NULL
             AND product_name_lenght IS NULL
             AND product_description_lenght IS NULL
             AND product_photos_qty IS NULL
            THEN 1
            ELSE 0
        END
    ) AS products_missing_all_metadata,

    SUM(
        CASE
            WHEN product_weight_g IS NULL
              OR product_length_cm IS NULL
              OR product_height_cm IS NULL
              OR product_width_cm IS NULL
            THEN 1
            ELSE 0
        END
    ) AS products_missing_dimensions

FROM dbo.products;
GO


-- FINDING:
-- 610 products are missing category and descriptive metadata.
-- 2 products are missing physical dimension / weight data.
--
-- TREATMENT:
-- Keep these products because they may still contribute
-- to orders and revenue.
-- Missing categories will be represented as 'Unknown'
-- in the analytical layer.
-- Other missing product attributes remain NULL unless
-- required for a specific analysis.


-- ============================================================
-- 21. ORDERS NULL FINDINGS
-- ============================================================

-- FINDING:
-- 2,965 orders have NULL order_delivered_customer_date.
--
-- Most are explained by non-delivered statuses such as:
-- shipped, canceled, unavailable, invoiced, processing,
-- created, or approved.
--
-- However, 8 orders are marked as 'delivered' while still
-- having a NULL customer delivery timestamp.
--
-- 160 orders have NULL order_approved_at:
--   141 canceled
--   14 delivered
--   5 created
--
-- TREATMENT:
-- Keep raw order records unchanged.
--
-- Delivery-time metrics will use:
--   order_status = 'delivered'
--   AND order_delivered_customer_date IS NOT NULL
--
-- Approval-time metrics will only use rows where
-- order_approved_at IS NOT NULL.


-- ============================================================
-- 22. NULL PROFILE FINDINGS - OTHER TABLES
-- ============================================================

-- CUSTOMERS:
-- No missing values were found in customer_id,
-- customer_unique_id, customer_city, or customer_state.

-- ORDER_ITEMS:
-- No missing values were found in order_id, product_id,
-- seller_id, price, or freight_value.

-- PAYMENTS:
-- No missing values were found in order_id, payment_type,
-- payment_installments, or payment_value.

-- REVIEWS:
-- order_id and review_score contain no missing values.
--
-- review_comment_title contains 87,658 NULL values.
-- review_comment_message contains 58,256 NULL values.
--
-- These NULLs are considered valid because customers
-- can submit a rating without leaving written comments.
-- No imputation is required.

-- CATEGORY_TRANSLATION:
-- No NULL values were found in either category column.


-- ============================================================
-- 23. CATEGORY TRANSLATION COVERAGE
-- ============================================================

-- Two categories used in the products table do not have
-- matching English translations.

SELECT
    p.product_category_name,
    COUNT(DISTINCT p.product_id) AS product_count,
    COUNT(DISTINCT oi.order_id) AS order_count

FROM dbo.products AS p

LEFT JOIN dbo.category_translation AS ct
    ON p.product_category_name =
       ct.product_category_name

LEFT JOIN dbo.order_items AS oi
    ON p.product_id = oi.product_id

WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL

GROUP BY
    p.product_category_name

ORDER BY
    order_count DESC;
GO


-- FINDING:
-- Missing English translations:
--
-- 1. pc_gamer
-- 2. portateis_cozinha_e_preparadores_de_alimentos
--
-- TREATMENT:
-- When an English translation is unavailable,
-- use the original Portuguese category name.
--
-- If the original category itself is NULL,
-- use 'Unknown'.
--
-- Analysis logic:
--
-- COALESCE(
--     product_category_name_english,
--     product_category_name,
--     'Unknown'
-- )


-- ============================================================
-- 24. MONETARY IMPORT ANOMALY
-- ============================================================

-- During data-quality validation, price, freight_value,
-- and payment_value were found to have been imported
-- at 100x their intended monetary values.
--
-- Example:
-- raw price = 5890
-- expected monetary value = 58.90
--
-- raw freight_value = 1329
-- expected monetary value = 13.29


-- Preview raw vs corrected order-item values

SELECT TOP 20
    order_id,

    price AS raw_price,

    CAST(
        price / 100.0
        AS DECIMAL(12,2)
    ) AS corrected_price,

    freight_value AS raw_freight_value,

    CAST(
        freight_value / 100.0
        AS DECIMAL(12,2)
    ) AS corrected_freight_value

FROM dbo.order_items;
GO


-- Preview raw vs corrected payment values

SELECT TOP 20
    order_id,

    payment_value AS raw_payment_value,

    CAST(
        payment_value / 100.0
        AS DECIMAL(12,2)
    ) AS corrected_payment_value

FROM dbo.payments;
GO


-- FINDING:
-- The monetary fields affected are:
--
-- dbo.order_items.price
-- dbo.order_items.freight_value
-- dbo.payments.payment_value
--
-- TREATMENT:
-- Raw imported tables will NOT be updated.
--
-- Corrected monetary values will be created in
-- analytical views in:
--
-- 04_data_cleaning.sql
--
-- using:
--
-- CAST(value / 100.0 AS DECIMAL(12,2))


-- ============================================================
-- 25. FINAL DATA QUALITY FINDINGS
-- ============================================================

-- SUMMARY:
--
-- 1. Core customer, order, product, order-item, and payment
--    identifiers were checked for expected uniqueness.
--
-- 2. review_id is not unique and some orders contain
--    multiple review records.
--
-- 3. Missing order timestamps were investigated based
--    on order status instead of being removed automatically.
--
-- 4. 610 products have missing descriptive metadata.
--
-- 5. Review comments contain many NULL values, but these
--    are considered valid and do not affect review-score analysis.
--
-- 6. Two product categories do not have English translations.
--
-- 7. Core table relationships were checked for orphan records.
--
-- 8. Monetary fields were imported at 100x their intended values.
--    This will be corrected in the analytical layer.
--
-- 9. Raw source tables remain unchanged.
--
-- Data is now ready for the cleaning / analytical layer.