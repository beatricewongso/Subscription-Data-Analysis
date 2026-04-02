/***********************************
Notes:
A. Difference between Query A & B is that query B does not count the month of end date as active
- so if a subscription ends in 20 June, query B will only count it as active until May
************************************/


/***********************************
[Table Helper] Active Subscriptions
************************************/
DROP VIEW IF EXISTS active

CREATE VIEW active AS (
SELECT
	month_date,
	COUNT(*) AS active_subscriptions,
	COUNT(*) FILTER (WHERE is_trial=TRUE) AS trial_subscriptions
FROM (
SELECT
	subscription_id,
	is_trial,
	month_date,
	start_sub,
	end_sub,
	active_months
FROM (
SELECT
	subscription_id,
	is_trial,
	month_date,
	start_date::DATE AS start_sub,
	COALESCE(end_date::DATE, '2024-12-31') AS end_sub,
	(AGE(month_date, DATE_TRUNC('month', start_date))) + '1 Month' AS active_months
FROM subscription
CROSS JOIN cal
WHERE end_date >= '2024-01-01' OR end_date IS NULL
ORDER BY 1, 3
)
WHERE active_months >= '1 Month'
AND month_date <= end_sub
ORDER BY 4, 2
)
GROUP BY 1
ORDER BY 1
)

-- queries to check the filtering logic
SELECT COUNT(*)
FROM subscription
WHERE end_date IS NULL

SELECT COUNT(*)
FROM subscription
WHERE end_date <= '2024-12-01'

SELECT
DISTINCT subscription_id
FROM subscription
WHERE end_date IS NULL

/***********************************
[Table Helper] Churned Subscriptions
************************************/
CREATE VIEW lost_subs AS (
SELECT
	month_date,
	COUNT(*) AS lost_active_subscriptions,
	COUNT(*) FILTER (WHERE is_trial = TRUE) AS lost_trials
FROM (
SELECT
	month_date,
	subscription_id,
	start_date::DATE,
	end_date::DATE,
	is_trial,
	AGE(end_date, month_date) AS duration
FROM subscription
CROSS JOIN cal
WHERE end_date BETWEEN month_date AND (month_date + INTERVAL '1 Month - 1 Day')
)
GROUP BY 1
ORDER BY 1
)

-- queries to ensure filtering logic
SELECT
	month_date,
	subscription_id,
	start_date::DATE,
	end_date::DATE,
	duration
FROM (
SELECT
	month_date,
	subscription_id,
	start_date::DATE,
	end_date::DATE,
	is_trial,
	AGE(end_date, month_date) AS duration -- AGE won't be reliable because some months need 29 days, some 30 and 1 needs 27, occassionally 28
FROM subscription
CROSS JOIN cal
WHERE end_date BETWEEN month_date AND (month_date + INTERVAL '1 Month - 1 Day')
)
WHERE month_date = '2024-10-01'
AND subscription_id = 'S-85796b'

/***********************************
 * A. Active & Lost Subscription throughout 2024
 ***********************************/

SELECT
	active.month_date,
	active_subscriptions,
	trial_subscriptions,
	lost_active_subscriptions,
	lost_trials
FROM active
JOIN lost_subs ON active.month_date = lost_subs.month_date


/***********************************
 * B. Active & Lost Subscription throughout 2024
 ***********************************/
SELECT 
	month_date,
	active_subscriptions,
	active_subscriptions - LAG(active_subscriptions) OVER () AS diff_subscriptions,
	trial_subs,
	ROUND(trial_subs/active_subscriptions * 100, 2) AS trial_perc
FROM (
SELECT 
	month_date,
	COUNT(subscription_id)::NUMERIC AS active_subscriptions,
	COUNT(subscription_id) FILTER (WHERE is_trial = TRUE)::NUMERIC AS trial_subs
FROM cal
CROSS JOIN subscription
WHERE start_date <= (month_date + INTERVAL '1 month - 1 day') 
AND (end_date >= (month_date + INTERVAL '1 month - 1 day') OR end_date IS NULL)
GROUP BY 1
ORDER BY 1
)

-- taking a closer look at the logic; when end_date is NULL, it counts as active at the month_date
SELECT 
	subscription_id,
	month_date,
	start_date::DATE,
	end_date::DATE
FROM cal
CROSS JOIN subscription
WHERE start_date <= (month_date + INTERVAL '1 month - 1 day') 
AND end_date >= (month_date + INTERVAL '1 month - 1 day') 
ORDER BY 1, 2, 3
-- ==================================================================================
-- fact check
SELECT
	subscription_id,
	start_date,
	end_date
FROM subscription
WHERE DATE_TRUNC('month', end_date) = '2024-02-01'

SELECT 
	subscription_id,
	start_date,
	end_date
FROM subscription
WHERE DATE_TRUNC('month', end_date) = '2024-02-01'
AND is_trial = TRUE
-- ===================================================================================
/***********************************
 * C. New Account and Subscriptions per Month
 ***********************************/
-- new account sign up per month
SELECT
	signup_month,
	number_of_account_signups,
	number_of_started_subscriptions
FROM
(SELECT
	signup_month,
	COUNT(*) AS number_of_account_signups
FROM (
SELECT 
	account_id,
	DATE_TRUNC('month', signup_date)::DATE AS signup_month
FROM account
)
GROUP BY 1
ORDER BY 1
) acc
JOIN (
-- new subscription per month
SELECT
	start_month,
	COUNT(*) AS number_of_started_subscriptions
FROM (
SELECT 
	subscription_id,
	DATE_TRUNC('month', start_date)::DATE AS start_month
FROM subscription
)
GROUP BY 1
ORDER BY 1
) subs
ON acc.signup_month = subs.start_month

-- archive
-- ============================================================
/***********************************
 * [Old CTE] Active Subscriptions
 ***********************************/
WITH active AS (
SELECT
	subscription_id,
	mrr_amount * (EXTRACT(YEAR FROM AGE(end_date, start_date)) * 12 + EXTRACT(MONTH FROM AGE(end_date, start_date))) AS interval
FROM (
SELECT
	subscription_id,
	DATE_TRUNC('month', start_date)::DATE AS start_date,
	COALESCE(DATE_TRUNC('month', end_date)::DATE, '2025-07-01') AS end_date,
	mrr_amount
FROM subscription
)
)

/***********************************
 * [Old Query] Active & Lost Subscription throughout 2024
 ***********************************/
WITH active AS (
SELECT
	subscription_id,
	month_date,
	start_date,
	end_date,
	active_months,
	is_trial
FROM (
SELECT
	subscription_id,
	is_trial,
	month_date,
	start_date::DATE,
	COALESCE(end_date::DATE, '2024-12-31') AS end_date,
	(AGE(month_date, DATE_TRUNC('month', start_date))) + '1 Month' AS active_months
FROM subscription
CROSS JOIN cal
ORDER BY 4, 1, 3
)
ORDER BY 1, 2
),
lost_subs AS (
SELECT
	month_date,
	COUNT(*) AS lost_active_subscriptions,
	COUNT(*) FILTER (WHERE is_trial = TRUE) AS lost_trials
FROM (
SELECT
	month_date,
	subscription_id,
	start_date::DATE,
	end_date::DATE,
	is_trial,
	AGE(end_date, month_date) AS duration
FROM subscription
CROSS JOIN cal
WHERE end_date BETWEEN month_date AND (month_date + INTERVAL '1 Month - 1 Day')
)
GROUP BY 1
ORDER BY 1
)
SELECT
	active_trial.month_date,
	active_subscriptions,
	trial_subscriptions,
	lost_active_subscriptions,
	lost_trials
FROM (
SELECT
	month_date,
	COUNT(subscription_id) AS active_subscriptions,
	COUNT(subscription_id) FILTER (WHERE is_trial = TRUE) AS trial_subscriptions
FROM active
WHERE active_months >= '1 Month' 
GROUP BY 1
ORDER BY 1
) active_trial
JOIN lost_subs ON active_trial.month_date = lost_subs.month_date
SELECT
	DATE_TRUNC('month', start_date)::DATE,
	COUNT(*)
FROM subscription
GROUP BY 1
ORDER BY 1

/***********************************
 * [Old Query] Lost Subscriptions per Month
 ***********************************/
SELECT
	month_date,
	ended_subscriptions,
	ended_subscriptions - LAG(ended_subscriptions) OVER () AS diff_subscriptions,
	trial_subs,
	ROUND(trial_subs/ended_subscriptions * 100, 2) AS trial_perc
FROM (
SELECT 
	month_date,
	COUNT(subscription_id)::NUMERIC AS ended_subscriptions,
	COUNT(subscription_id) FILTER (WHERE is_trial = TRUE)::NUMERIC AS trial_subs
FROM cal
CROSS JOIN subscription
WHERE start_date <= (month_date + INTERVAL '1 month - 1 day') -- we actually don't need to filter start date
AND end_date BETWEEN month_date AND (month_date + INTERVAL '1 month - 1 day')
GROUP BY 1
ORDER BY 1
)
	