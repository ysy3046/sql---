SELECT
    product_id,
    product_name,

    MAX(TRY_CAST(rating AS DOUBLE)) AS product_rating,

    MAX(
        TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
    ) AS product_rating_count,

    MAX(
        CASE
            WHEN REGEXP_MATCHES(
                COALESCE(review_title, '') || ' ' || COALESCE(review_content, ''),
                '(broken|defective|not working|stopped working|faulty)',
                'i'
            )
            THEN 1 ELSE 0
        END
    ) AS defect_signal,

    MAX(
        CASE
            WHEN REGEXP_MATCHES(
                COALESCE(review_title, '') || ' ' || COALESCE(review_content, ''),
                '(refund|returned|replacement)',
                'i'
            )
            THEN 1 ELSE 0
        END
    ) AS return_signal,

    MAX(
        CASE
            WHEN REGEXP_MATCHES(
                COALESCE(review_title, '') || ' ' || COALESCE(review_content, ''),
                '(worst|waste|useless|disappointed)',
                'i'
            )
            THEN 1 ELSE 0
        END
    ) AS dissatisfaction_signal,

    MAX(
        CASE
            WHEN REGEXP_MATCHES(
                COALESCE(review_title, '') || ' ' || COALESCE(review_content, ''),
                '(poor quality|cheap quality|damaged|flimsy)',
                'i'
            )
            THEN 1 ELSE 0
        END
    ) AS quality_signal,

    defect_signal
    + return_signal
    + dissatisfaction_signal
    + quality_signal
    AS negative_signal_types

FROM amazon

GROUP BY
    product_id,
    product_name

HAVING product_rating >= 4.0
   AND product_rating_count >= 1000
   AND negative_signal_types <= 1

ORDER BY
    negative_signal_types ASC,
    product_rating DESC,
    product_rating_count DESC

LIMIT 10;