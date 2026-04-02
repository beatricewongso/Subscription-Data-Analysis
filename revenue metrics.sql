/***********************************
notes:
A. Revenue Accrued throughout 2024
- Revenue Accrued includes revenue generated from 2023 (for older subscriptions that started before 2024)
- Revenue Accrued does not accrue in the month of end date
- Had some help with AI to create the query, even though I modified it a little and re-used its logic for the other revenue query
B. Revenue Fresh out of 2024
- For subscriptions with start date older than 1st Jan 2024, the accumulated MRR from 2023 is not accounted for 
C & D Revenue per Plan Tier and Industry
- Used Revenue Fresh out of 2024 for these 2 pivot tables
************************************/

/***********************************
 * A. Revenue Accrued throughout 2024    *
 ***********************************/
SELECT 
    m.month_date,
    SUM(s.mrr_amount * (
        (EXTRACT(YEAR FROM AGE(m.month_date, s.start_date)) * 12) + 
         EXTRACT(MONTH FROM AGE(m.month_date, s.start_date))
    )) AS revenue_accrued,
	SUM(seats) AS seats
FROM (
    SELECT generate_series('2024-01-01'::date, '2024-12-01'::date, '1 month')::date AS month_date
) m
CROSS JOIN 
(
SELECT
	subscription_id,
	start_date::DATE,
	COALESCE(end_date, '2025-12-31')::DATE AS end_date,
	mrr_amount,
	seats,
	is_trial
FROM subscription
) s
WHERE start_date <= (month_date + INTERVAL '1 month - 1 day') 
  AND s.is_trial = FALSE
  AND end_date >= (month_date + INTERVAL '1 month - 1 day')
GROUP BY m.month_date
ORDER BY m.month_date;

/***********************************
 * Logic Check    *
 ***********************************/
 
-- January Revenue (accrued) Check
SELECT
	SUM(jan_revenue)
FROM (
SELECT
	subscription_id,
	start_date,
	end_date,
	jan_interval,
	(EXTRACT(YEAR FROM jan_interval) * 12 + EXTRACT(MONTH FROM jan_interval)) * mrr_amount AS jan_revenue
FROM (
SELECT
	subscription_id,
	start_date::DATE,
	end_date::DATE,
	mrr_amount,
	AGE('2024-01-01', start_date) AS jan_interval
FROM subscription
WHERE start_date <= '2024-01-31'
AND (end_date >= '2024-01-31' OR end_date IS NULL)
ORDER BY jan_interval 
)
)
-- ====================================================================================
-- table helper 
CREATE VIEW cal AS (
SELECT generate_series('2024-01-01'::date, '2024-12-01'::date, '1 month')::date AS month_date
)
-- ===================================================================================
/***********************************
 * B. Revenue Fresh out of 2024    *
 ***********************************/
DROP VIEW IF EXISTS revenue_2024

CREATE VIEW revenue_2024 AS (
SELECT
	subscription_id,
	plan_tier,
	industry,
	month_date,
	start_date,
	end_date,
	active_interval,
	mrr_amount 
FROM (
SELECT
	subscription_id,
	plan_tier,
	industry,
	month_date,
	start_date::DATE,
	COALESCE(end_date::DATE, '2024-12-31') AS end_date,
	AGE(month_date, DATE_TRUNC('month', start_date)) AS active_interval,
	mrr_amount
FROM subscription a
CROSS JOIN cal
JOIN account b ON a.account_id = b.account_id
WHERE is_trial = FALSE
AND end_date >= '2024-01-01'
OR end_date IS NULL
ORDER BY 4, 1, 2
) a
WHERE active_interval >= '0 day'
AND end_date >= month_date
ORDER BY 4, 2
)

WITH revenue AS (
SELECT
	subscription_id,
	month_date,
	start_date,
	end_date,
	active_interval,
	mrr_amount 
FROM (
SELECT
	subscription_id,
	month_date,
	start_date::DATE,
	COALESCE(end_date::DATE, '2024-12-31') AS end_date,
	AGE(month_date, DATE_TRUNC('month', start_date)) AS active_interval,
	mrr_amount
FROM subscription
CROSS JOIN cal
WHERE is_trial = FALSE
AND end_date >= '2024-01-01'
OR end_date IS NULL
ORDER BY 4, 1, 2
)
WHERE active_interval >= '0 day'
AND end_date >= month_date
ORDER BY 4, 2
)
SELECT
	month_date,
	SUM(mrr_amount) AS revenue
FROM revenue
GROUP BY 1
ORDER BY 1
)
/***********************************
 * Logic Check   *
 ***********************************/
 
 -- January Revenue Check
SELECT
	SUM(mrr_amount)
FROM (
SELECT
	subscription_id,
	'2024-01-01' AS jan,
	start_date::DATE,
	end_date::DATE,
	mrr_amount,
	AGE('2024-01-01', DATE_TRUNC('month', start_date)) AS jan_interval
FROM subscription
WHERE start_date <= '2024-01-31'
AND is_trial = FALSE
AND (end_date >='2024-01-01' OR end_date IS NULL)
ORDER BY subscription_id 
)

-- January Revenue Logic Check; found out that criteria needs to include end_date, so revenue does not account for ended subscriptions in 2023
SELECT
	subscription_id,
	month_date,
	start_date,
	end_date,
	active_interval,
	mrr_amount 
FROM (
SELECT
	subscription_id,
	month_date,
	start_date::DATE,
	COALESCE(end_date::DATE, '2024-12-31') AS end_date,
	AGE(month_date, DATE_TRUNC('month', start_date)) AS active_interval,
	mrr_amount
FROM subscription
CROSS JOIN cal
WHERE is_trial = FALSE
ORDER BY 1, 2
)
WHERE active_interval >= '0 day'

AND month_date = '2024-01-01'
AND subscription_id = 'S-0e4b0c'
ORDER BY 1

-- refining the January Revenue Logic; the results of the query below shows subscriptions that has ended, but still show up in Jan revenue due to unawareness that end date needs to be included in the criteria
(SELECT
	subscription_id
FROM (
SELECT
	subscription_id,
	month_date,
	start_date,
	end_date,
	active_interval,
	mrr_amount 
FROM (
SELECT
	subscription_id,
	month_date,
	start_date::DATE,
	COALESCE(end_date::DATE, '2024-12-31') AS end_date,
	AGE(month_date, DATE_TRUNC('month', start_date)) AS active_interval,
	mrr_amount
FROM subscription
CROSS JOIN cal
WHERE is_trial = FALSE
ORDER BY 1, 2
)
WHERE active_interval >= '0 day'
AND month_date = '2024-01-01'
ORDER BY 1
))
EXCEPT
(
SELECT
	subscription_id
FROM (
SELECT
	subscription_id,
	'2024-01-01' AS jan,
	start_date::DATE,
	end_date::DATE,
	mrr_amount,
	AGE('2024-01-01', DATE_TRUNC('month', start_date)) AS jan_interval
FROM subscription
WHERE start_date <= '2024-01-31'
AND is_trial = FALSE
AND (end_date >='2024-01-01' OR end_date IS NULL)
ORDER BY subscription_id))


-- revenue month logic validation (because the criteria will be sensitive towards end and start of month's dates); 
-- to check the subscription ids in a confusing spot, need to ensure these IDs are accounted in the Jan revenue query
SELECT
	subscription_id,
	month_date,
	start_date::DATE,
	COALESCE(end_date::DATE, '2024-12-31') AS end_date,
	AGE(month_date, DATE_TRUNC('month', start_date)) AS active_interval,
	mrr_amount,
	GREATEST(mrr_amount * (EXTRACT(YEAR FROM AGE(month_date, DATE_TRUNC('month', start_date))) * 12 + 1 + EXTRACT(MONTH FROM AGE(month_date, DATE_TRUNC('month', start_date)))),0)
	AS revenue
FROM subscription
CROSS JOIN cal
WHERE is_trial = FALSE
AND month_date = '2024-01-01'
AND start_date = '2024-01-31'
ORDER BY 1, 2

--==================================================================================
-- convenient search query to validate findings
SELECT
	subscription_id,
	start_date,
	end_date,
	mrr_amount
FROM subscription
WHERE subscription_id = 'S-92f228'

-- =========================================================================================
/***********************************
 * C. Revenue per Plan Tier    *
 ***********************************/
DROP VIEW IF EXISTS revenue_plan_tier

CREATE VIEW revenue_plan_tier AS (
SELECT
	month_date,
	plan_tier,
	SUM(mrr_amount) AS rev_plan_tier
FROM revenue_2024
GROUP BY 1, 2
ORDER BY 1, 2
)

CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT * FROM CROSSTAB(
$$ SELECT
	month_date,
	plan_tier,
	rev_plan_tier
FROM revenue_plan_tier
ORDER BY 1, 2 $$,
$$ VALUES ('Basic'), ('Pro'), ('Enterprise') $$
) AS ct (
    month_date DATE,
    "Basic" NUMERIC,
    "Pro" NUMERIC,
    "Enterprise" NUMERIC
)
ORDER BY month_date ASC

-- ====================================================================================
/***********************************
 * D. Revenue per Industry  *
 ***********************************/
DROP VIEW IF EXISTS revenue_industry

CREATE VIEW revenue_industry AS (
SELECT
	month_date,
	industry,
	SUM(mrr_amount) AS rev_industry
FROM revenue_2024
GROUP BY 1, 2
ORDER BY 1, 2
)

CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT * FROM CROSSTAB(
$$ SELECT
	month_date,
	industry,
	rev_industry
FROM revenue_industry
ORDER BY 1, 2 $$,
$$ VALUES ('FinTech'), ('EdTech'), ('Cybersecurity'), ('HealthTech'), ('DevTools') $$
) AS ct (
    month_date DATE,
    "Fintech" NUMERIC,
    "EdTech" NUMERIC,
    "Cybersecurity" NUMERIC,
	"HealthTech" NUMERIC,
	"DevTools" NUMERIC
)
ORDER BY month_date ASC

