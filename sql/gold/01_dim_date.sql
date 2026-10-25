USE ROLE DATA_ENGINEER;

CREATE OR REPLACE VIEW ECOM_DB.GOLD.DIM_DATE AS
WITH bounds AS (
  SELECT
    DATEADD('day', shift_days, '2016-09-01'::DATE) AS start_date,
    DATEADD('day', shift_days, '2017-01-01'::DATE) AS window_start,
    target_anchor_date
  FROM ECOM_DB.SILVER.REF_DATE_SHIFT
  WHERE shift_key = 'olist_history'
),
spine AS (
  SELECT DATEADD('day', ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, b.start_date) AS date_day,
         b.window_start,
         b.target_anchor_date
  FROM TABLE(GENERATOR(ROWCOUNT => 1500))
  CROSS JOIN bounds b
)
SELECT
  date_day,
  YEAR(date_day) AS year,
  QUARTER(date_day) AS quarter,
  MONTH(date_day) AS month,
  DATE_TRUNC('month', date_day) AS month_start,
  DATEADD('day', 1 - DAYOFWEEKISO(date_day), date_day) AS iso_week_start,
  DAYOFWEEKISO(date_day) AS iso_day_of_week,
  DAYNAME(date_day) AS day_name,
  date_day >= window_start AS is_analysis_window,
  date_day >= target_anchor_date AS is_live_period
FROM spine;