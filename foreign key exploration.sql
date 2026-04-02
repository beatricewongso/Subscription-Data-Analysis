-- ensuring foreign key consistency & getting the gist of relationships between data
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position
-- 
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
AND data_type = 'text'
AND column_name LIKE '%id'
ORDER BY table_name, ordinal_position

-- ===================================================================================
-- nunique of id columns for each tables

-- a. account 
SELECT
COUNT(DISTINCT account_id) AS nunique_account_id, -- 500 account_id
COUNT(*) AS account_rows
FROM account

-- b. feature usage
SELECT
	COUNT(DISTINCT subscription_id) AS nunique_subscription_id, -- 3913 subscription id have used features
	COUNT(*) AS feature_usage_rows -- 7730 feature usages
FROM feature_usage
-- not all subscription (about 120 subscription_id) have used features (maybe even inactive)

-- c. support ticket
SELECT
	COUNT(DISTINCT ticket_id) AS nunique_ticket_id, -- 2000 unique tickets 
	COUNT(DISTINCT account_id) AS nunique_account_id, -- 492 unique account had gone to support
	COUNT(*) AS support_ticket_rows -- 2000 rows in support ticket
FROM support_ticket
-- not all accounts have gone to support

-- d. churn event
SELECT
	COUNT(DISTINCT churn_event_id) AS nunique_churn_event_id, -- 600 churn id
	COUNT(DISTINCT account_id) AS nunique_account_id, -- 352 accounts either left for good or reactivated
	COUNT(*) AS churn_event_rows
FROM churn_event

-- e. subscription
SELECT
	COUNT(DISTINCT subscription_id) AS nunique_subscription_id, -- 4993 different subscriptions 
	COUNT(DISTINCT account_id) AS nunique_account_id, -- 500 accounts
	COUNT(*) AS subscription_rows
FROM subscription
-- ====================================================================================


-- ===================================================================================
-- ## making sense of the fact table: subscription
-- ### subscription 
SELECT
	account_id,
	subscription_id,
	start_date::DATE,
	is_trial,
	plan_tier,
	upgrade_flag,
	downgrade_flag,
	churn_flag,
	billing_frequency,
	auto_renew_flag
FROM subscription
WHERE account_id = 'A-00bed1'
ORDER BY 3
-- account_id will only be used when joining subscription table to account table

-- b. subscription and churn event
WITH churn_event AS (
SELECT
	reactivate.account_id AS reactivated_account_id,
	churn.account_id AS churned_account_id,
	reactivated_times,
	total_reactivated,
	churned_times,
	total_churned
FROM (
SELECT
	account_id,
	reactivated_times,
	SUM(reactivated_times) OVER () AS total_reactivated
FROM (
SELECT
	account_id,
	COUNT(account_id) AS reactivated_times
FROM churn_event
WHERE is_reactivation = TRUE
GROUP BY 1
ORDER BY 2 DESC
)) reactivate
FULL JOIN 
(
SELECT
	account_id,
	churned_times,
	SUM(churned_times) OVER () AS total_churned
FROM (
SELECT
	account_id,
	COUNT(account_id) AS churned_times
FROM churn_event
WHERE is_reactivation = FALSE
GROUP BY 1
ORDER BY 2 DESC
)
) churn
ON churn.account_id = reactivate.account_id
ORDER BY reactivated_times DESC
), 
acc_fact AS 
(SELECT 
	account_id,
	subscription_id,
	churn_flag
FROM subscription 
ORDER BY 1
)

SELECT
	reactivated_account_id,
	churned_account_id,
	subscription_id,
	reactivated_times,
	churned_times
FROM churn_event a
LEFT JOIN acc_fact b
ON a.reactivated_account_id = b.account_id
AND a.churned_account_id = b.account_id
ORDER BY 1, 2
-- there are some account_id with no subscription id
-- so, only categorical data will be used from churn event 

-- ### subscription and account
-- mapping of the same columns in both subscription and account
SELECT
	b.account_id,
	b.subscription_id,
	a.churn_flag AS acc_churn,
	b.churn_flag As sub_churn,
	a.is_trial AS acc_trial,
	b.is_trial AS sub_trial,
	a.plan_tier AS acc_plan_tier,
	b.plan_tier AS sub_plan_tier,
	a.seats AS acc_seats,
	b.seats As sub_seats
FROM account a
FULL JOIN subscription b
ON a.account_id = b.account_id
WHERE a.account_id = 'A-00bed1'
ORDER BY 1
-- mismatch between is_trial columns in account and subscription, maybe is_trial in account is not relevant
-- mismatch again between plan tier, where account table only records the basic plan tier, whereas the subscription one has many tiers from basic, pro and enterprise

-- ** so, it's better to drop the matching columns from account table, since those are more relevant subscription_id base, rather than account base
ALTER TABLE account
DROP COLUMN plan_tier,
DROP COLUMN seats, 
DROP COLUMN is_trial,
DROP COLUMN churn_flag;

-- =====================================================================================
-- # exploring relationships between tables

-- ## relationship between signup_date and start_date
SELECT
	a.acc,
	start-signup AS days_to_start_since_regist
FROM (
SELECT
	subscription_id AS acc,
	signup_date::DATE AS signup,
	start_date AS start,
	is_trial 
FROM subscription a
LEFT JOIN account b
ON a.account_id = b.account_id
) a
ORDER BY 2 

-- some accounts wait 432 days to start, some start immediately

-- ## account and support ticket
SELECT
	a.account_id,
	signup_date::DATE,
	is_trial,
	churn_flag
FROM (
SELECT
	DISTINCT account_id,
	is_trial,
	churn_flag
FROM subscription
WHERE account_id NOT IN (
SELECT
	DISTINCT account_id
FROM support_ticket)
) a
JOIN account b
ON a.account_id = b.account_id

SELECT
	subscription_id
FROM subscription
WHERE subscription_id NOT IN (
SELECT subscription_id
FROM feature_usage)
-- almost half of the total subs never used any of the features


-- ## account and churn
SELECT
	signup_date::DATE,
	churn_date::DATE,
	churn_date - signup_date AS active_dur  
FROM account a
JOIN churn_event b
ON a.account_id = b.account_id
ORDER BY 3 DESC

-- 3 accounts immediately churned on their signup_date, while the longest acc stayed for almost 2 years
-- ==================================================================================







