-- some accounts have not been updated to the churn event table
SELECT
	is_trial,
	start_date,
	end_date
FROM subscription 
WHERE account_id IN (
SELECT
account_id
FROM subscription
EXCEPT
SELECT
account_id
FROM churn_event
)


/** plan tier distribution for subscriptions that have not appeared in feature usage table **/
-- plan tier does not affect this problem of subscriptions not appearing in the feature usage table
SELECT
	plan_tier,
	COUNT(*)
FROM subscription a
WHERE subscription_id NOT IN (
SELECT
	subscription_id
FROM feature_usage)
GROUP BY 1
ORDER BY 2


/** there's no real difference between the time to resolve for escalated and non-escalated tickets **/
SELECT
	escalation_flag,
	priority,
	AVG(resolution_time_hours) AS avg_resolve_time
FROM support_ticket
GROUP BY 1,2 
ORDER BY 1,
CASE priority
WHEN 'urgent' THEN 1
WHEN 'high' THEN 2
WHEN 'medium' THEN 3
WHEN 'low' THEN 4
END 

/** all kinds of feedback text show up in all kinds of reason code and vice versa **/
SELECT
	reason_code,
	feedback_text,
	COUNT(*)
FROM churn_event
GROUP BY 1,2 
ORDER BY 1


