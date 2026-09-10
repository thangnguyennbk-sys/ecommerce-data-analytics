USE ecommerce_analytics;
GO


-- ============================================================
-- 1. CLEAN ORDER ITEMS
-- ============================================================

CREATE OR ALTER VIEW dbo.vw_order_items_clean
AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,

    CAST(price / 100.0 AS DECIMAL(12,2)) AS price,

    CAST(freight_value / 100.0 AS DECIMAL(12,2))
        AS freight_value

FROM dbo.order_items;
GO


-- ============================================================
-- 2. CLEAN PAYMENTS
-- ============================================================

CREATE OR ALTER VIEW dbo.vw_payments_clean
AS
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,

    CAST(payment_value / 100.0 AS DECIMAL(12,2))
        AS payment_value

FROM dbo.payments;
GO


-- ============================================================
-- 3. CLEAN PRODUCTS
-- ============================================================

CREATE OR ALTER VIEW dbo.vw_products_clean
AS
SELECT
    p.product_id,

    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,

    p.product_category_name AS original_category_name,

    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm

FROM dbo.products AS p

LEFT JOIN dbo.category_translation AS ct
    ON p.product_category_name =
       ct.product_category_name;
GO