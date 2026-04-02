/***********************************
Notes:
A. Difference between Query A & B is that query B does not count the month of end date as active
- so if a subscription ends in 20 June, query B will only count it as active until May
************************************/


/***********************************
* Customer Support Stats & Exploration
************************************/
SELECT
AVG(resolution_time_hours),
MIN(resolution_time_hours),
MAX(resolution_time_hours)
FROM support_ticket

SELECT
	escalation_flag,
	COUNT(*)
FROM support_ticket
GROUP BY 1

SELECT
MIN(first_response_time_minutes),
MAX(first_response_time_minutes)
FROM support_ticket

SELECT
	AVG(satisfaction_score)
FROM support_ticket

SELECT
	satisfaction_score,
	COUNT(*)
FROM support_ticket
GROUP BY 1

SELECT
MAX(submitted_at),
MIN(submitted_at)
FROM support_ticket

/***********************************
* Diving Deeper to Table Logic
************************************/

/** Maximum Resolution Time Details **/
-- dive in deeper to the ticket that needed 3 days to solve;
-- we expected to see way more escalation for tickets that need 72 hours to solve
SELECT
	escalation_flag,
	COUNT(*)
FROM support_ticket
WHERE resolution_time_hours = 72
GROUP BY 1


/** Maximum First Response Time Details **/
-- there were 2 urgent cases, and 2 high priority cases; all cases are not escalation
SELECT *
FROM support_ticket
WHERE first_response_time_minutes = 180
-- 2 out of 7  tickets with first response time of 180 hours are still rated 5 out of 5


/***********************************
* [Time Analysis] Count of Support Tickets per Month
************************************/
WITH ticket_month AS (
SELECT
	DATE_TRUNC('month', submitted_at) AS month_ticket
FROM support_ticket 
WHERE submitted_at >= '2024-01-01'
ORDER BY 1
)
SELECT
	month_date,
	ticket,
	ticket - LAG(ticket) OVER () AS diff
FROM (
SELECT 
	month_date,
	COUNT(month_ticket) AS ticket
FROM cal a
JOIN ticket_month b ON a.month_date = b.month_ticket 
GROUP BY 1
ORDER BY 1
)

-- ======================================================================================
/***********************************
* [Time Analysis] Ticket & Satisfaction Score per Month
************************************/
SELECT
	month_date,
	COUNT(submitted_at) AS ticket_amount,
	ROUND(AVG(satisfaction_score)::NUMERIC, 2) AS avg_support_satisfaction
FROM cal
CROSS JOIN support_ticket
WHERE submitted_at >= '2024-01-01'
AND submitted_at BETWEEN month_date AND (month_date + INTERVAL '1 month - 1 day')
GROUP BY 1
ORDER BY 1

-- logic check
SELECT
	COUNT(*)
FROM support_ticket
WHERE submitted_at BETWEEN '2024-01-01' AND '2024-01-31'
