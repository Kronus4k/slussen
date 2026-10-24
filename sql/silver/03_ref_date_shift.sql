USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE TABLE IF NOT EXISTS ECOM_DB.SILVER.REF_DATE_SHIFT (
  shift_key VARCHAR NOT NULL,
  source_anchor_date DATE NOT NULL,
  target_anchor_date DATE NOT NULL,
  shift_days NUMBER(38,0) NOT NULL,
  source_time_zone VARCHAR NOT NULL,
  CONSTRAINT pk_ref_date_shift PRIMARY KEY (shift_key)
);

MERGE INTO ECOM_DB.SILVER.REF_DATE_SHIFT t
USING (
  SELECT
    'olist_history' AS shift_key,
    '2018-09-01'::DATE AS source_anchor_date,
    '2026-10-24'::DATE AS target_anchor_date,
    DATEDIFF('day', '2018-09-01'::DATE, '2026-10-24'::DATE) AS shift_days,
    'America/Sao_Paulo' AS source_time_zone
) s
ON t.shift_key = s.shift_key
WHEN MATCHED AND (t.source_anchor_date <> s.source_anchor_date OR t.target_anchor_date <> s.target_anchor_date
                  OR t.shift_days <> s.shift_days OR t.source_time_zone <> s.source_time_zone)
  THEN UPDATE SET source_anchor_date = s.source_anchor_date, target_anchor_date = s.target_anchor_date,
                  shift_days = s.shift_days, source_time_zone = s.source_time_zone
WHEN NOT MATCHED
  THEN INSERT (shift_key, source_anchor_date, target_anchor_date, shift_days, source_time_zone)
       VALUES (s.shift_key, s.source_anchor_date, s.target_anchor_date, s.shift_days, s.source_time_zone);