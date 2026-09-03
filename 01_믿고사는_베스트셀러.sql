SELECT
    product_id,
    product_name,
    MAX(TRY_CAST(rating AS DOUBLE)) AS product_rating,
    MAX(
        TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
    ) AS product_rating_count,
    ROUND(
        MAX(TRY_CAST(rating AS DOUBLE))
        * LN(
            MAX(
                TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
            ) + 1
        ),
        2
    ) AS bestseller_score
FROM amazon
GROUP BY
    product_id,
    product_name
HAVING MAX(TRY_CAST(rating AS DOUBLE)) >= 4.0
   AND MAX(
       TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
   ) >= 1000
ORDER BY bestseller_score DESC
LIMIT 10;