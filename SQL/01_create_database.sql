-- =============================================
-- E-commerce Sales & Customer Analytics
-- Database Setup
-- =============================================

IF DB_ID('ecommerce_analytics') IS NULL
BEGIN
    CREATE DATABASE ecommerce_analytics;
END;
GO

USE ecommerce_analytics;
GO