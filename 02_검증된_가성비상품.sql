SELECT
    product_id,
    product_name,

    MAX(
        TRY_CAST(
            REPLACE(REPLACE(actual_price, '₹', ''), ',', '')
            AS DOUBLE
        )
    ) AS original_price,

    MAX(
        TRY_CAST(
            REPLACE(REPLACE(discounted_price, '₹', ''), ',', '')
            AS DOUBLE
        )
    ) AS sale_price,

    MAX(
        TRY_CAST(REPLACE(discount_percentage, '%', '') AS DOUBLE)
    ) AS stated_discount_pct,

    ROUND(
        (
            MAX(
                TRY_CAST(
                    REPLACE(REPLACE(actual_price, '₹', ''), ',', '')
                    AS DOUBLE
                )
            )
            -
            MAX(
                TRY_CAST(
                    REPLACE(REPLACE(discounted_price, '₹', ''), ',', '')
                    AS DOUBLE
                )
            )
        )
        /
        MAX(
            TRY_CAST(
                REPLACE(REPLACE(actual_price, '₹', ''), ',', '')
                AS DOUBLE
            )
        ) * 100,
        1
    ) AS calculated_discount_pct,

    MAX(TRY_CAST(rating AS DOUBLE)) AS product_rating,

    MAX(
        TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
    ) AS product_rating_count

FROM amazon
GROUP BY
    product_id,
    product_name

HAVING original_price > 0
   AND calculated_discount_pct >= 40
   AND ABS(stated_discount_pct - calculated_discount_pct) <= 2
   AND product_rating >= 4.0
   AND product_rating_count >= 1000

ORDER BY
    calculated_discount_pct DESC,
    product_rating DESC

LIMIT 10;