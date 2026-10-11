-- Dormant accounts that suddenly move money
WITH account_activity AS (
    SELECT
        t.account_id,
        t.txn_time,
        t.direction,

        LAG(t.txn_time) OVER (
            PARTITION BY t.account_id
            ORDER BY t.txn_time
        ) AS previous_activity

    FROM transactions t

    JOIN accounts a
      ON a.account_id = t.account_id

    WHERE a.account_type = 'savings'
      AND t.status = 'success'
      AND t.channel IN (
          'upi', 'card_pos', 'atm',
          'imps', 'neft', 'branch'
      )
),

reactivations AS (
    SELECT
        account_id,
        previous_activity AS last_activity_before,
        txn_time AS reactivated_at,

        TIMESTAMPDIFF(
            SECOND,
            previous_activity,
            txn_time
        ) / 86400.0 AS dormant_days

    FROM account_activity

    WHERE previous_activity IS NOT NULL
      AND TIMESTAMPDIFF(
            SECOND,
            previous_activity,
            txn_time
          ) >= 180 * 24 * 60 * 60
)

SELECT
    r.account_id,
    a.customer_id,
    r.last_activity_before,
    r.reactivated_at,

    ROUND(r.dormant_days, 2) AS dormant_days,

    COUNT(t.txn_time) AS debit_count_7d,

    ROUND(
        COALESCE(SUM(t.amount), 0),
        2
    ) AS debits_7d

FROM reactivations r

JOIN accounts a
  ON a.account_id = r.account_id

JOIN transactions t
  ON t.account_id = r.account_id
 AND t.status = 'success'
 AND t.direction = 'debit'
 AND t.channel IN (
     'upi', 'card_pos', 'atm',
     'imps', 'neft', 'branch'
 )
 AND t.txn_time >= r.reactivated_at
 AND t.txn_time <= DATE_ADD(
        r.reactivated_at,
        INTERVAL 7 DAY
     )

GROUP BY
    r.account_id,
    a.customer_id,
    r.last_activity_before,
    r.reactivated_at,
    r.dormant_days

HAVING SUM(t.amount) >= 100000

ORDER BY
    debits_7d DESC,
    r.account_id

LIMIT 40;