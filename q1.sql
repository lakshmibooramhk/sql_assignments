-- Monthly account balances

WITH RECURSIVE months (month_end) AS (
    SELECT DATE('2025-01-31')

    UNION ALL

    SELECT LAST_DAY(DATE_ADD(month_end, INTERVAL 1 MONTH))
    FROM months
    WHERE month_end < '2025-12-31'
),

account_balances AS (
    SELECT
        a.account_id,
        a.account_type,
        m.month_end,

        a.opening_balance
        + COALESCE(
            SUM(
                CASE
                    WHEN t.direction = 'credit' THEN t.amount
                    WHEN t.direction = 'debit' THEN -t.amount
                    ELSE 0
                END
            ),
            0
        ) AS balance

    FROM accounts a

    CROSS JOIN months m

    LEFT JOIN transactions t
        ON t.account_id = a.account_id
        AND t.status = 'success'
        AND t.txn_time < DATE_ADD(m.month_end, INTERVAL 1 DAY)

    WHERE a.open_date <= m.month_end

    GROUP BY
        a.account_id,
        a.account_type,
        a.opening_balance,
        m.month_end
)

SELECT
    month_end AS month,
    account_type,

    COUNT(*) AS accounts,

    ROUND(SUM(balance), 2) AS total_balance,

    ROUND(AVG(balance), 2) AS avg_balance,

    SUM(
        CASE
            WHEN balance < 0 THEN 1
            ELSE 0
        END
    ) AS overdrawn_accounts,

    ROUND(
        SUM(
            CASE
                WHEN balance < 0 THEN -balance
                ELSE 0
            END
        ),
        2
    ) AS overdrawn_amount

FROM account_balances

GROUP BY
    month_end,
    account_type

ORDER BY
    month_end,
    account_type;