SHOW GRANTS ON INTEGRATION SLUSSEN_S3_INT;

ALTER STORAGE INTEGRATION SLUSSEN_S3_INT SET STORAGE_ALLOWED_LOCATIONS = (
    's3://slussen-lake-qwer/landing/olist/',
    's3://slussen-lake-qwer/validated/',
    's3://slussen-lake-qwer/audit/contract_violations/'
);