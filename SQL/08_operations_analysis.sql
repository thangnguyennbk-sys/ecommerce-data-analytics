-- ============================================================
-- E-COMMERCE SALES & CUSTOMER ANALYTICS
-- File: 08_operations_analysis.sql
--
-- Purpose:
--   Analyze delivery speed, delivery reliability,
--   late-delivery severity, geographic delivery performance,
--   and the relationship between delivery performance
--   and customer satisfaction.
--
-- BUSINESS RULES:
--
--   1. Delivery KPIs use delivered orders only.
--
--   2. Orders missing actual customer delivery timestamps
--      are excluded from metrics requiring actual delivery.
--
--   3. An order is considered ON TIME when:
--
--      order_delivered_customer_date
--      <=
--      order_estimated_delivery_date
--
--   4. An order is considered LATE when:
--
--      order_delivered_customer_date
--      >
--      order_estimated_delivery_date
--
--   5. Delivery duration is measured from:
--
--      order_purchase_timestamp
--      to
--      order_delivered_customer_date
--
--   6. Reviews are reduced to one analytical record per
--      order before joining to delivery data.
--
--   7. Raw source tables remain unchanged.
--
-- ============================================================

USE ecommerce_analytics;
GO



-- ============================================================
-- 1. DELIVERY KPI SUMMARY
-- ============================================================
-- Business questions:
--
-- How many delivered orders have usable delivery timestamps?
--
-- How long does delivery take on average?
--
-- What is the observed delivery-time range?
-- ============================================================

SELECT
    COUNT(*) AS valid_delivered_orders,

    CAST(
        AVG(
            1.0 * DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        )
        AS DECIMAL(10,2)
    ) AS avg_delivery_days,

    MIN(
        DATEDIFF(
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        )
    ) AS min_delivery_days,

    MAX(
        DATEDIFF(
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        )
    ) AS max_delivery_days

FROM dbo.orders

WHERE order_status = 'delivered'

  AND order_purchase_timestamp IS NOT NULL

  AND order_delivered_customer_date IS NOT NULL;
GO


-- ============================================================
-- RESULTS - SECTION 1
-- ============================================================
--
-- Valid Delivered Orders = 96,470
-- Average Delivery Days  = 12.50
-- Minimum Delivery Days  = 0
-- Maximum Delivery Days  = 210
--
--
-- FINDINGS:
--
-- 1. 96,470 delivered orders contain usable customer
--    delivery timestamps.
--
-- 2. This matches the earlier Data Quality finding:
--
--    Total Delivered Orders                 = 96,478
--    Delivered Orders Missing Delivery Date =      8
--    Valid Delivered Orders                 = 96,470
--
-- 3. Average end-to-end delivery time from purchase to
--    customer delivery is approximately:
--
--    12.50 days.
--
-- 4. Observed delivery duration ranges from:
--
--    0 to 210 days.
--
-- 5. The long upper tail indicates that some orders
--    experienced unusually long delivery durations.
--
-- 6. These long-duration orders should be treated as
--    operational exceptions requiring deeper investigation
--    rather than automatically being classified as bad data.
--
--
-- NOTE:
--
-- DATEDIFF(DAY) counts calendar-day boundaries.
--
-- Therefore a value of:
--
-- 0 days
--
-- does not necessarily mean instantaneous delivery.
--
-- It means the purchase and delivery timestamps fall within
-- a zero-day calendar difference according to DATEDIFF.



-- ============================================================
-- 2. ON-TIME VS LATE DELIVERY
-- ============================================================
-- Business questions:
--
-- What percentage of delivered orders arrive on time?
--
-- How many delivered orders arrive later than the
-- estimated delivery date?
-- ============================================================

WITH delivery_status AS (

    SELECT
        order_id,

        CASE
            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date
                THEN 'On Time'

            ELSE 'Late'
        END AS delivery_status

    FROM dbo.orders

    WHERE order_status = 'delivered'

      AND order_delivered_customer_date IS NOT NULL

      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    delivery_status,

    COUNT(*) AS total_orders,

    CAST(
        100.0 * COUNT(*)
        /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(10,2)
    ) AS order_share_pct

FROM delivery_status

GROUP BY
    delivery_status

ORDER BY
    total_orders DESC;
GO


-- ============================================================
-- RESULTS - SECTION 2
-- ============================================================
--
-- ON TIME:
--
-- Orders = 88,644
-- Share  = 91.89%
--
--
-- LATE:
--
-- Orders = 7,826
-- Share  = 8.11%
--
--
-- FINDINGS:
--
-- 1. 88,644 delivered orders arrived on or before their
--    estimated delivery date.
--
-- 2. This represents:
--
--    91.89%
--
--    of valid delivered orders.
--
-- 3. 7,826 delivered orders arrived after their estimated
--    delivery date.
--
-- 4. Late deliveries represent:
--
--    8.11%
--
--    of valid delivered orders.
--
-- 5. The large majority of delivered orders therefore met
--    the promised delivery estimate.
--
-- 6. However, approximately one out of every twelve valid
--    delivered orders arrived late.
--
-- 7. Late delivery therefore remains a meaningful
--    operational issue even though overall reliability
--    is relatively high.



-- ============================================================
-- 3. LATE DELIVERY SEVERITY
-- ============================================================
-- Business questions:
--
-- When an order arrives late, how many days late is it?
--
-- How severe can delivery delays become?
-- ============================================================

SELECT
    COUNT(*) AS late_orders,

    CAST(
        AVG(
            1.0 * DATEDIFF(
                DAY,
                order_estimated_delivery_date,
                order_delivered_customer_date
            )
        )
        AS DECIMAL(10,2)
    ) AS avg_late_days,

    MAX(
        DATEDIFF(
            DAY,
            order_estimated_delivery_date,
            order_delivered_customer_date
        )
    ) AS max_late_days

FROM dbo.orders

WHERE order_status = 'delivered'

  AND order_delivered_customer_date IS NOT NULL

  AND order_estimated_delivery_date IS NOT NULL

  AND order_delivered_customer_date
      > order_estimated_delivery_date;
GO


-- ============================================================
-- RESULTS - SECTION 3
-- ============================================================
--
-- Late Orders      = 7,826
-- Average Late Days = 8.87
-- Maximum Late Days = 188
--
--
-- FINDINGS:
--
-- 1. A total of 7,826 delivered orders arrived later than
--    their estimated delivery date.
--
-- 2. This exactly matches the Late order count from
--    Section 2.
--
-- 3. This consistency confirms that the delivery-status
--    classification and late-severity logic agree.
--
-- 4. Late orders arrive approximately:
--
--    8.87 days late on average.
--
-- 5. The most extreme observed late delivery arrived:
--
--    188 days
--
--    after the estimated delivery date.
--
-- 6. Therefore delivery performance should not be evaluated
--    using late-order frequency alone.
--
-- 7. Two operational dimensions matter:
--
--    frequency of late deliveries
--
--    AND
--
--    severity of those delays.



-- ============================================================
-- 4. MONTHLY DELIVERY PERFORMANCE
-- ============================================================
-- Business questions:
--
-- How does delivery performance change over time?
--
-- What percentage of delivered orders arrive on time
-- each month?
--
-- Does average delivery duration move together with
-- on-time delivery performance?
-- ============================================================

SELECT
    DATEFROMPARTS(
        YEAR(order_purchase_timestamp),
        MONTH(order_purchase_timestamp),
        1
    ) AS order_month,

    COUNT(*) AS valid_delivered_orders,

    CAST(
        AVG(
            1.0 * DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        )
        AS DECIMAL(10,2)
    ) AS avg_delivery_days,

    SUM(
        CASE
            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS on_time_orders,

    SUM(
        CASE
            WHEN order_delivered_customer_date
                 > order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN order_delivered_customer_date
                     <= order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS on_time_rate_pct

FROM dbo.orders

WHERE order_status = 'delivered'

  AND order_purchase_timestamp IS NOT NULL

  AND order_delivered_customer_date IS NOT NULL

  AND order_estimated_delivery_date IS NOT NULL

GROUP BY
    YEAR(order_purchase_timestamp),
    MONTH(order_purchase_timestamp)

ORDER BY
    order_month;
GO


-- ============================================================
-- FINDINGS - SECTION 4
-- ============================================================
--
-- 1. Early 2016 months contain extremely low order volume
--    and should be treated as boundary / incomplete periods
--    rather than normal operating months.
--
-- 2. During most of 2017, on-time delivery performance
--    remained above 90%.
--
-- 3. Delivery performance deteriorated significantly in
--    November 2017:
--
--    Valid Delivered Orders = 7,288
--    Avg Delivery Days      = 15.07
--    Late Orders            = 1,043
--    On-Time Rate           = 85.69%
--
-- 4. December 2017 improved somewhat:
--
--    On-Time Rate = 91.62%
--
--    but average delivery duration remained relatively
--    high at:
--
--    15.31 days.
--
-- 5. February 2018 showed another major deterioration:
--
--    Valid Delivered Orders = 6,555
--    Avg Delivery Days      = 16.87
--    Late Orders            = 1,048
--    On-Time Rate           = 84.01%
--
-- 6. March 2018 recorded the weakest delivery reliability
--    within the stable analysis period:
--
--    Valid Delivered Orders = 7,003
--    Avg Delivery Days      = 16.24
--    Late Orders            = 1,496
--    On-Time Rate           = 78.64%
--
-- 7. Delivery performance improved strongly after March 2018.
--
-- 8. June 2018 showed particularly strong performance:
--
--    Valid Delivered Orders = 6,096
--    Avg Delivery Days      = 9.16
--    Late Orders            = 83
--    On-Time Rate           = 98.64%
--
-- 9. July 2018 also maintained relatively strong delivery
--    performance:
--
--    Avg Delivery Days = 8.89
--    On-Time Rate      = 95.52%
--
-- 10. August 2018 had a short average delivery duration:
--
--     7.66 days
--
--     but the on-time rate declined to:
--
--     89.61%
--
-- 11. This demonstrates that delivery speed and reliability
--     should be monitored separately.
--
-- 12. Monthly delivery performance is not constant and
--     therefore should be tracked over time rather than
--     relying only on one overall operational KPI.



-- ============================================================
-- 5A. DELIVERY PERFORMANCE BY CUSTOMER STATE
-- ============================================================
-- Business questions:
--
-- Which states have stronger or weaker delivery performance?
--
-- How does delivery duration vary geographically?
--
-- Does a long delivery duration necessarily imply
-- poor delivery reliability?
-- ============================================================

SELECT
    c.customer_state,

    COUNT(*) AS valid_delivered_orders,

    CAST(
        AVG(
            1.0 * DATEDIFF(
                DAY,
                o.order_purchase_timestamp,
                o.order_delivered_customer_date
            )
        )
        AS DECIMAL(10,2)
    ) AS avg_delivery_days,

    SUM(
        CASE
            WHEN o.order_delivered_customer_date
                 > o.order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN o.order_delivered_customer_date
                     <= o.order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS on_time_rate_pct

FROM dbo.orders AS o

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'

  AND o.order_purchase_timestamp IS NOT NULL

  AND o.order_delivered_customer_date IS NOT NULL

  AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY
    c.customer_state

ORDER BY
    on_time_rate_pct ASC;
GO


-- ============================================================
-- FINDINGS - SECTION 5A
-- ============================================================
--
-- 1. Delivery performance varies substantially across
--    customer states.
--
-- 2. Several large markets show meaningful differences in
--    delivery speed and reliability.
--
--
-- RJ:
--
-- Valid Delivered Orders = 12,350
-- Avg Delivery Days      = 15.24
-- Late Orders            = 1,664
-- On-Time Rate           = 86.53%
--
--
-- SP:
--
-- Valid Delivered Orders = 40,494
-- Avg Delivery Days      = 8.70
-- Late Orders            = 2,387
-- On-Time Rate           = 94.11%
--
--
-- MG:
--
-- Valid Delivered Orders = 11,354
-- Avg Delivery Days      = 11.94
-- Late Orders            = 637
-- On-Time Rate           = 94.39%
--
--
-- PR:
--
-- Valid Delivered Orders = 4,923
-- Avg Delivery Days      = 11.94
-- Late Orders            = 246
-- On-Time Rate           = 95.00%
--
--
-- 3. SP combines the largest delivery volume with
--    relatively strong operational performance.
--
-- 4. RJ has both longer average delivery time and a
--    substantially lower on-time rate than SP.
--
-- 5. Some states have long average delivery times while
--    still maintaining strong on-time rates.
--
-- Example:
--
-- AP:
--
-- Valid Delivered Orders = 67
-- Avg Delivery Days      = 27.18
-- Late Orders            = 3
-- On-Time Rate           = 95.52%
--
-- 6. This demonstrates that:
--
--    DELIVERY SPEED
--
--    and
--
--    DELIVERY RELIABILITY
--
--    are different operational metrics.
--
-- 7. A state may have relatively slow deliveries while
--    still meeting the delivery expectations communicated
--    to customers.
--
-- 8. Geographic performance should therefore be evaluated
--    using both:
--
--    average delivery duration
--
--    AND
--
--    on-time delivery rate.
--
--
-- CAUTION:
--
-- States with very small order counts should not be compared
-- directly with major markets without considering sample size.



-- ============================================================
-- 5B. DELIVERY PERFORMANCE VS REVIEW SCORE
-- ============================================================
-- Business question:
--
-- Do late deliveries receive lower review scores than
-- on-time deliveries?
--
--
-- IMPORTANT REVIEW GRAIN:
--
-- Earlier data-quality analysis found that:
--
-- review_id is not guaranteed to be unique
--
-- AND
--
-- some orders contain multiple review records.
--
-- Therefore raw reviews should NOT be joined directly to
-- orders for order-level satisfaction analysis.
--
-- One analytical review record is selected per order before
-- joining to delivery performance.
-- ============================================================

WITH ranked_reviews AS (

    SELECT
        review_id,

        order_id,

        review_score,

        review_creation_date,

        review_answer_timestamp,

        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY
                review_answer_timestamp DESC,
                review_creation_date DESC,
                review_id DESC
        ) AS rn

    FROM dbo.reviews
),

order_reviews AS (

    SELECT
        order_id,

        review_score

    FROM ranked_reviews

    WHERE rn = 1
),

delivery_reviews AS (

    SELECT
        o.order_id,

        CASE
            WHEN o.order_delivered_customer_date
                 <= o.order_estimated_delivery_date
                THEN 'On Time'

            ELSE 'Late'
        END AS delivery_status,

        r.review_score

    FROM dbo.orders AS o

    INNER JOIN order_reviews AS r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'

      AND o.order_delivered_customer_date IS NOT NULL

      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    delivery_status,

    COUNT(*) AS reviewed_orders,

    CAST(
        AVG(
            1.0 * review_score
        )
        AS DECIMAL(10,2)
    ) AS avg_review_score,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN review_score >= 4
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS positive_review_rate_pct

FROM delivery_reviews

GROUP BY
    delivery_status

ORDER BY
    avg_review_score DESC;
GO


-- ============================================================
-- RESULTS - SECTION 5B
-- ============================================================
--
-- ON-TIME DELIVERIES:
--
-- Reviewed Orders      = 88,163
-- Avg Review Score     = 4.29
-- Positive Review Rate = 82.79%
--
--
-- LATE DELIVERIES:
--
-- Reviewed Orders      = 7,661
-- Avg Review Score     = 2.57
-- Positive Review Rate = 34.55%
--
--
-- FINDINGS:
--
-- 1. On-time deliveries receive substantially higher
--    customer review scores than late deliveries.
--
-- 2. Average review score:
--
--    On Time = 4.29
--    Late    = 2.57
--
-- 3. Positive Review Rate:
--
--    On Time = 82.79%
--    Late    = 34.55%
--
-- 4. The difference is substantial across both satisfaction
--    measures.
--
-- 5. Late delivery is therefore strongly associated with
--    poorer customer review outcomes.
--
-- 6. Delivery reliability appears to be an important
--    operational dimension of customer experience.
--
-- 7. Improving delivery reliability may therefore support
--    stronger customer satisfaction.
--
-- 8. Reviews were reduced to one analytical record per order
--    before joining.
--
-- 9. This prevents orders containing multiple review records
--    from receiving additional weight in the analysis.
--
--
-- IMPORTANT:
--
-- This analysis identifies ASSOCIATION, not CAUSATION.
--
-- Lower review scores may also be influenced by:
--
-- product quality
-- seller performance
-- packaging
-- product expectations
-- customer service
-- other order-related factors
--
-- Therefore late delivery should not be interpreted as the
-- only cause of lower customer satisfaction.



-- ============================================================
-- 6. OPERATIONS CONSISTENCY CHECK
-- ============================================================
-- Purpose:
--
-- Confirm that:
--
-- On-Time Orders + Late Orders
--
-- equals:
--
-- Valid Delivered Orders
-- ============================================================

WITH delivery_status AS (

    SELECT
        order_id,

        CASE
            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date
                THEN 'On Time'

            ELSE 'Late'
        END AS delivery_status

    FROM dbo.orders

    WHERE order_status = 'delivered'

      AND order_delivered_customer_date IS NOT NULL

      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    COUNT(*) AS valid_delivered_orders,

    SUM(
        CASE
            WHEN delivery_status = 'On Time'
            THEN 1
            ELSE 0
        END
    ) AS on_time_orders,

    SUM(
        CASE
            WHEN delivery_status = 'Late'
            THEN 1
            ELSE 0
        END
    ) AS late_orders

FROM delivery_status;
GO


-- ============================================================
-- EXPECTED RESULTS - SECTION 6
-- ============================================================
--
-- Valid Delivered Orders = 96,470
-- On-Time Orders         = 88,644
-- Late Orders            = 7,826
--
--
-- CHECK:
--
-- 88,644
-- +
-- 7,826
-- =
-- 96,470
--
--
-- FINDINGS:
--
-- 1. On-time and late delivery groups account for the entire
--    valid delivered-order population.
--
-- 2. No valid delivered orders are lost between the two
--    delivery-status categories.
--
-- 3. The late-order count also matches the result from
--    Late Delivery Severity analysis.
--
-- 4. These consistency checks increase confidence in the
--    operational KPI calculations.



-- ============================================================
-- FINAL OPERATIONS ANALYSIS SUMMARY
-- ============================================================
--
-- MAIN OPERATIONS KPIs:
--
-- Total Delivered Orders:
-- 96,478
--
-- Valid Delivered Orders:
-- 96,470
--
-- Delivered Orders Missing Actual Delivery Date:
-- 8
--
-- Average Delivery Time:
-- 12.50 days
--
-- On-Time Delivery Rate:
-- 91.89%
--
-- Late Delivery Rate:
-- 8.11%
--
-- Average Late Duration:
-- 8.87 days
--
-- Maximum Observed Late Duration:
-- 188 days
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 1
-- OVERALL DELIVERY RELIABILITY IS HIGH
-- ============================================================
--
-- 91.89% of valid delivered orders arrive on or before
-- their estimated delivery date.
--
-- The majority of customers therefore receive orders
-- within the delivery expectation communicated to them.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 2
-- LATE DELIVERIES REMAIN OPERATIONALLY IMPORTANT
-- ============================================================
--
-- 7,826 orders were delivered late.
--
-- This represents:
--
-- 8.11%
--
-- of valid delivered orders.
--
-- Late orders arrive approximately:
--
-- 8.87 days late
--
-- on average.
--
-- Therefore late-delivery severity should be monitored in
-- addition to the overall late-order rate.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 3
-- DELIVERY PERFORMANCE CHANGES SIGNIFICANTLY OVER TIME
-- ============================================================
--
-- March 2018 experienced particularly weak performance:
--
-- On-Time Rate      = 78.64%
-- Avg Delivery Days = 16.24
-- Late Orders       = 1,496
--
-- June 2018 later showed very strong performance:
--
-- On-Time Rate      = 98.64%
-- Avg Delivery Days = 9.16
--
-- Monthly monitoring can therefore reveal operational
-- problems hidden by the overall 91.89% KPI.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 4
-- DELIVERY PERFORMANCE VARIES GEOGRAPHICALLY
-- ============================================================
--
-- Major customer markets do not experience identical
-- delivery performance.
--
-- Example:
--
-- SP:
--
-- Avg Delivery Days = 8.70
-- On-Time Rate      = 94.11%
--
-- RJ:
--
-- Avg Delivery Days = 15.24
-- On-Time Rate      = 86.53%
--
-- Geographic logistics performance should therefore be
-- monitored separately rather than assuming one national
-- delivery profile.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 5
-- DELIVERY SPEED AND RELIABILITY ARE DIFFERENT
-- ============================================================
--
-- Some states have long delivery durations but still achieve
-- strong on-time performance.
--
-- AP provides one example:
--
-- Avg Delivery Days = 27.18
-- On-Time Rate      = 95.52%
--
-- This indicates that customers may tolerate longer shipping
-- times when the estimated delivery date accurately reflects
-- the expected delivery window.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 6
-- LATE DELIVERY IS STRONGLY ASSOCIATED WITH LOWER REVIEWS
-- ============================================================
--
-- Average Review Score:
--
-- On-Time Deliveries = 4.29
-- Late Deliveries    = 2.57
--
--
-- Positive Review Rate:
--
-- On-Time Deliveries = 82.79%
-- Late Deliveries    = 34.55%
--
-- Delivery reliability is therefore strongly associated
-- with customer satisfaction in the observed data.
--
--
-- ============================================================
-- MAIN BUSINESS INSIGHT 7
-- OPERATIONAL PERFORMANCE CAN AFFECT CUSTOMER EXPERIENCE
-- ============================================================
--
-- The large review-score difference suggests that delivery
-- performance should not be treated only as a logistics KPI.
--
-- It is also closely linked with customer-experience outcomes.
--
-- This creates a connection between:
--
-- operations performance
--
-- and
--
-- customer satisfaction.



-- ============================================================
-- BUSINESS RECOMMENDATIONS
-- ============================================================
--
-- ------------------------------------------------------------
-- 1. MONITOR MONTHLY ON-TIME DELIVERY RATE
-- ------------------------------------------------------------
--
-- Overall operational KPIs can hide temporary delivery
-- problems.
--
-- Monthly monitoring should track:
--
-- on-time delivery rate
-- average delivery duration
-- late-order count
-- average lateness
--
-- Significant drops should trigger investigation.
--
--
-- ------------------------------------------------------------
-- 2. INVESTIGATE LOW-PERFORMING GEOGRAPHIC MARKETS
-- ------------------------------------------------------------
--
-- States with:
--
-- lower on-time rates
--
-- and
--
-- high order volume
--
-- should receive greater operational attention.
--
-- Large markets such as RJ are particularly important
-- because delivery problems affect many orders.
--
--
-- ------------------------------------------------------------
-- 3. DISTINGUISH DELIVERY SPEED FROM RELIABILITY
-- ------------------------------------------------------------
--
-- A long delivery time does not automatically indicate
-- poor service.
--
-- Customers may still receive reliable service when the
-- estimated delivery promise accurately reflects the
-- expected transit time.
--
-- Operational dashboards should therefore display:
--
-- average delivery days
--
-- AND
--
-- on-time delivery rate.
--
--
-- ------------------------------------------------------------
-- 4. PRIORITIZE LATE-DELIVERY REDUCTION
-- ------------------------------------------------------------
--
-- Late orders receive substantially lower review scores.
--
-- Reducing late deliveries may therefore support both:
--
-- logistics performance
--
-- AND
--
-- customer satisfaction.
--
--
-- ------------------------------------------------------------
-- 5. INVESTIGATE EXTREME DELIVERY DELAYS
-- ------------------------------------------------------------
--
-- The longest observed delivery duration was:
--
-- 210 days.
--
-- The largest observed delay beyond estimate was:
--
-- 188 days.
--
-- These extreme cases should be investigated separately
-- because averages can hide unusually severe failures.
--
--
-- ------------------------------------------------------------
-- 6. USE REVIEW DATA AS AN OPERATIONAL FEEDBACK SIGNAL
-- ------------------------------------------------------------
--
-- Review outcomes can help identify whether operational
-- problems are visible to customers.
--
-- However, review scores should not be interpreted as purely
-- logistics-driven because other factors may influence
-- customer satisfaction.



-- ============================================================
-- ANALYTICAL CAUTIONS
-- ============================================================
--
-- 1. ASSOCIATION IS NOT CAUSATION
--
-- Late delivery is strongly associated with lower review
-- scores, but this analysis does not prove that delivery
-- delay alone caused the lower review.
--
--
-- 2. REVIEWS REQUIRE DEDUPLICATION
--
-- Raw review records may contain:
--
-- repeated review IDs
--
-- and
--
-- multiple review records per order.
--
-- One analytical review per order is therefore selected
-- before order-level review analysis.
--
--
-- 3. DELIVERY-DURATION OUTLIERS ARE RETAINED
--
-- Extremely long delivery durations are not automatically
-- deleted.
--
-- They may represent:
--
-- genuine operational failures
-- unusual logistics events
-- source-data problems
--
-- Additional investigation would be required before
-- excluding them.
--
--
-- 4. GEOGRAPHIC SAMPLE SIZE MATTERS
--
-- Some states contain very few delivered orders.
--
-- Their on-time rates may therefore be more volatile than
-- rates from large markets such as SP, RJ, or MG.
--
--
-- 5. DELIVERY DURATION USES CALENDAR DAYS
--
-- DATEDIFF(DAY) measures calendar-day boundaries and does
-- not account for:
--
-- business days
-- holidays
-- weekends
--
--
-- 6. ON-TIME PERFORMANCE DEPENDS ON THE ESTIMATED DATE
--
-- A long delivery may still be classified as On Time when
-- the promised delivery window is also long.
--
-- Therefore:
--
-- delivery speed
--
-- and
--
-- delivery reliability
--
-- should always be interpreted separately.
--
--
-- 7. ONLY DELIVERED ORDERS ARE USED FOR DELIVERY KPIs
--
-- Cancelled, unavailable, shipped, processing, and other
-- incomplete statuses are excluded from completed-delivery
-- performance metrics.
--
--
-- ============================================================
-- END OF OPERATIONS ANALYSIS
-- ============================================================