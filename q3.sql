-- Loan delinquency buckets
WITH RECURSIVE month_ends (month_end) AS (
    SELECT DATE('2025-01-31')

    UNION ALL

    SELECT LAST_DAY(DATE_ADD(month_end, INTERVAL 1 MONTH))
    FROM month_ends
    WHERE month_end < '2025-12-31'
),

products AS (
    SELECT DISTINCT product
    FROM loans
),

active_loans AS (
    SELECT
        m.month_end,
        l.loan_id,
        l.product,
        l.tenure_months

    FROM month_ends m

    JOIN loans l
      ON l.sanction_date <= m.month_end

    LEFT JOIN loan_installments i
      ON i.loan_id = l.loan_id
     AND i.due_date <= m.month_end
     AND i.paid_date <= m.month_end

    GROUP BY
        m.month_end,
        l.loan_id,
        l.product,
        l.tenure_months

    HAVING COUNT(i.installment_id) < l.tenure_months
),

loan_status AS (
    SELECT
        al.month_end,
        al.loan_id,
        al.product,

        MIN(
            CASE
                WHEN i.due_date <= al.month_end
                 AND (
                     i.paid_date IS NULL
                     OR i.paid_date > al.month_end
                 )
                THEN i.due_date
            END
        ) AS oldest_unpaid_due_date,

        SUM(
            CASE
                WHEN i.due_date <= al.month_end
                 AND (
                     i.paid_date IS NULL
                     OR i.paid_date > al.month_end
                 )
                THEN i.amount_due
                ELSE 0
            END
        ) AS overdue_amount

    FROM active_loans al

    LEFT JOIN loan_installments i
      ON i.loan_id = al.loan_id

    GROUP BY
        al.month_end,
        al.loan_id,
        al.product
),

classified_loans AS (
    SELECT
        month_end,
        loan_id,
        product,
        overdue_amount,

        CASE
            WHEN oldest_unpaid_due_date IS NULL
                THEN 'current'

            WHEN DATEDIFF(
                month_end,
                oldest_unpaid_due_date
            ) = 0
                THEN 'current'

            WHEN DATEDIFF(
                month_end,
                oldest_unpaid_due_date
            ) <= 30
                THEN 'dpd_1_30'

            WHEN DATEDIFF(
                month_end,
                oldest_unpaid_due_date
            ) <= 60
                THEN 'dpd_31_60'

            WHEN DATEDIFF(
                month_end,
                oldest_unpaid_due_date
            ) <= 90
                THEN 'dpd_61_90'

            ELSE 'dpd_90_plus'
        END AS dpd_category

    FROM loan_status
)

SELECT
    m.month_end,
    p.product,

    COUNT(c.loan_id) AS active_loans,

    SUM(
        CASE WHEN c.dpd_category = 'current'
             THEN 1 ELSE 0 END
    ) AS `current`,

    SUM(
        CASE WHEN c.dpd_category = 'dpd_1_30'
             THEN 1 ELSE 0 END
    ) AS dpd_1_30,

    SUM(
        CASE WHEN c.dpd_category = 'dpd_31_60'
             THEN 1 ELSE 0 END
    ) AS dpd_31_60,

    SUM(
        CASE WHEN c.dpd_category = 'dpd_61_90'
             THEN 1 ELSE 0 END
    ) AS dpd_61_90,

    SUM(
        CASE WHEN c.dpd_category = 'dpd_90_plus'
             THEN 1 ELSE 0 END
    ) AS dpd_90_plus,

    ROUND(COALESCE(SUM(c.overdue_amount), 0), 2)
        AS overdue_amount

FROM month_ends m

CROSS JOIN products p

LEFT JOIN classified_loans c
  ON c.month_end = m.month_end
 AND c.product = p.product

GROUP BY
    m.month_end,
    p.product

ORDER BY
    m.month_end,
    p.product;