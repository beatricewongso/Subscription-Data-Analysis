-- exploring categorical columns

/***********************************
* User Industry Distribution
************************************/
SELECT
	industry,
	amt,
	SUM(amt) OVER (),
	ROUND(amt/SUM(amt) OVER () * 100, 2) AS amt_perc
FROM (
SELECT
	industry,
	COUNT(industry) AS amt
FROM account
GROUP BY 1
)

/***********************************
* User Country Distribution
************************************/
SELECT
	country,
	freq,
	SUM(freq) OVER (),
	ROUND(freq/SUM(freq) OVER () * 100, 2) AS freq_perc
FROM (
SELECT 
	country,
	COUNT(*) AS freq
FROM account
GROUP BY 1
)

/***********************************
* Referral Source Distribution
************************************/
SELECT
	referral_source,
	freq,
	SUM(freq) OVER (),
	ROUND(freq/SUM(freq) OVER () * 100, 2) AS freq_perc
FROM (
SELECT 
	referral_source,
	COUNT(*) AS freq
FROM account
GROUP BY 1
)
-- ======================================================================================
/***********************************
* Feedback Text & Reason Code
************************************/
SELECT
	feedback_text,
	freq,
	SUM(freq) OVER (),
	ROUND(freq/SUM(freq) OVER () * 100, 2) AS freq_perc
FROM (
SELECT 
	feedback_text,
	COUNT(*) AS freq
FROM churn_event
GROUP BY 1
)

SELECT
reason_code,
feedback_text
FROM churn_event
ORDER BY 2
-- reason_code is unreliable 

SELECT
	feedback_text,
	ROUND(SUM(refund_amount_usd)::NUMERIC, 2)
FROM churn_event
GROUP BY 1

SELECT *
FROM churn_event
WHERE refund_amount_usd > 0
AND is_reactivation = TRUE
-- thought that reactivation and refund cannot be true across both columns, but after thinking, it actually makes sense

/***********************************
* Plan Tier Distribution
************************************/
SELECT
	plan_tier,
	freq,
	SUM(freq) OVER (),
	ROUND(freq/SUM(freq) OVER () * 100, 2) AS freq_perc
FROM (
SELECT 
	plan_tier,
	COUNT(*) AS freq
FROM subscription
GROUP BY 1
)

/***********************************
* Trial Subscription Distribution
************************************/
SELECT
	is_trial,
	freq,
	SUM(freq) OVER (),
	ROUND(freq/SUM(freq) OVER () * 100, 2) AS freq_perc
FROM (
SELECT 
	is_trial,
	COUNT(*) AS freq
FROM subscription
GROUP BY 1
)

--  does a trial have a standardized length
SELECT
	start_date,
	end_date,
	end_date - start_date
FROM subscription
WHERE is_trial = TRUE
-- there's no standardized length for trials


SELECT
	billing_frequency,
	COUNT(*)
FROM subscription
GROUP BY 1


SELECT
	satisfaction_score,
	COUNT(*)
FROM support_ticket
GROUP BY 1

SELECT
	priority,
	escalation_flag,
	COUNT(*)
FROM support_ticket
GROUP BY 1,2
ORDER BY 1


SELECT
	DISTINCT a.account_id AS acc,
	COUNT(subscription_id) AS sub_count
FROM subscription a
GROUP BY 1
ORDER BY 2 DESC
-- some accounts have up to 19 subscriptions


