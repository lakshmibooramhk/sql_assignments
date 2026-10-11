--Rapid-fire debits

WITH eligible_debits AS (
    SELECT
        t.account_id,
        t.txn_time,
        t.amount
    FROM transactions t
    WHERE t.status = 'success'
      AND t.direction = 'debit'
      AND t.channel IN ('upi', 'card_pos')
),

window_totals AS (
    SELECT
        d.account_id,
        d.txn_time AS window_start,
        COUNT(*) AS debits_in_window,
        SUM(w.amount) AS amount_in_window

    FROM eligible_debits d

    JOIN eligible_debits w
      ON w.account_id = d.account_id
     AND w.txn_time >= d.txn_time
     AND w.txn_time <= DATE_ADD(
            d.txn_time,
            INTERVAL 600 SECOND
         )

    GROUP BY
        d.account_id,
        d.txn_time
),

ranked_windows AS (
    SELECT
        account_id,
        window_start,
        debits_in_window,
        amount_in_window,

        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY
                debits_in_window DESC,
                amount_in_window DESC,
                window_start ASC
        ) AS rn

    FROM window_totals
)

SELECT
    a.account_id,
    a.customer_id,
    a.account_type,
    r.window_start,
    r.debits_in_window,
    ROUND(r.amount_in_window, 2) AS amount_in_window

FROM ranked_windows r

JOIN accounts a
  ON a.account_id = r.account_id

WHERE r.rn = 1

ORDER BY
    r.debits_in_window DESC,
    r.amount_in_window DESC,
    r.account_id

LIMIT 30;