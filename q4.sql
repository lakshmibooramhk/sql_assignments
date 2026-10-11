-- Large transfers followed by returns within 48 hours
WITH transfers_out AS (
    SELECT
        t.account_id AS from_account,
        t.counterparty_account_id AS to_account,
        t.txn_time AS sent_at,
        t.amount AS sent_amount

    FROM transactions t

    WHERE t.status = 'success'
      AND t.direction = 'debit'
      AND t.counterparty_account_id IS NOT NULL
      AND t.amount >= 50000
),

ranked_returns AS (
    SELECT
        s.from_account,
        s.to_account,
        s.sent_at,
        s.sent_amount,
        r.txn_time AS returned_at,
        r.amount AS returned_amount,

        ROW_NUMBER() OVER (
            PARTITION BY
                s.from_account,
                s.to_account,
                s.sent_at,
                s.sent_amount

            ORDER BY r.txn_time ASC
        ) AS rn

    FROM transfers_out s

    JOIN transactions r
      ON r.account_id = s.to_account
     AND r.counterparty_account_id = s.from_account
     AND r.status = 'success'
     AND r.direction = 'debit'
     AND r.txn_time > s.sent_at
     AND r.txn_time <= DATE_ADD(
            s.sent_at,
            INTERVAL 48 HOUR
         )
     AND r.amount BETWEEN s.sent_amount * 0.98
                      AND s.sent_amount * 1.02
)

SELECT
    from_account,
    to_account,
    sent_at,
    returned_at,
    sent_amount,
    returned_amount,

    ROUND(
        TIMESTAMPDIFF(
            SECOND,
            sent_at,
            returned_at
        ) / 3600.0,
        2
    ) AS hours_between

FROM ranked_returns

WHERE rn = 1

ORDER BY
    sent_amount DESC,
    from_account,
    sent_at

LIMIT 40;