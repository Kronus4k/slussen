USE ROLE DATA_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE LOAD_WH;
USE SCHEMA ECOM_DB.BRONZE;

EXECUTE IMMEDIATE $$
DECLARE
    tables ARRAY DEFAULT ARRAY_CONSTRUCT(
        'OLIST_CUSTOMERS', 'OLIST_GEOLOCATION', 'OLIST_ORDERS', 'OLIST_ORDER_ITEMS', 'OLIST_ORDER_PAYMENTS',
        'OLIST_ORDER_REVIEWS', 'OLIST_PRODUCTS', 'OLIST_PRODUCT_CATEGORY_NAME_TRANSLATION', 'OLIST_SELLERS');
    table_name VARCHAR;
    bootstrap_name VARCHAR;
    already INTEGER;
    present INTEGER;
    renamed INTEGER DEFAULT 0;
BEGIN
    FOR i IN 0 TO ARRAY_SIZE(tables) - 1 DO
        table_name := tables[i]::VARCHAR;
        bootstrap_name := table_name || '_BOOTSTRAP';
        SELECT COUNT(*) INTO :already FROM ECOM_DB.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = 'BRONZE' AND TABLE_NAME = :bootstrap_name;
        SELECT COUNT(*) INTO :present FROM ECOM_DB.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = 'BRONZE' AND TABLE_NAME = :table_name;
        IF (already = 0 AND present = 1) THEN
            EXECUTE IMMEDIATE 'ALTER TABLE ECOM_DB.BRONZE.' || table_name || ' RENAME TO ECOM_DB.BRONZE.' || bootstrap_name;
            EXECUTE IMMEDIATE 'COMMENT ON TABLE ECOM_DB.BRONZE.' || bootstrap_name || ' IS ''Day-one bootstrap load of the raw Olist CSV, all VARCHAR. Kept for reconciliation with the contract-typed table, then dropped.''';
            renamed := renamed + 1;
        END IF;
    END FOR;
    RETURN renamed || ' table(s) renamed to *_BOOTSTRAP';
END;
$$;