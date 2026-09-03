WITH product_summary AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name,
        MAX(SPLIT_PART(category, '|', 1)) AS main_category,
        MAX(TRY_CAST(rating AS DOUBLE)) AS product_rating,
        MAX(
            TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
        ) AS product_rating_count
    FROM amazon
    GROUP BY product_id
),

category_ranking AS (
    SELECT
        product_id,
        product_name,
        main_category,
        product_rating,
        product_rating_count,
        ROUND(
            product_rating * LN(product_rating_count + 1),
            2
        ) AS category_score,

        ROW_NUMBER() OVER (
            PARTITION BY main_category
            ORDER BY
                product_rating * LN(product_rating_count + 1) DESC
        ) AS category_rank

    FROM product_summary
    WHERE product_rating >= 4.0
      AND product_rating_count >= 1000
)

SELECT
    main_category,
    category_rank,
    product_id,
    product_name,
    product_rating,
    product_rating_count,
    category_score
FROM category_ranking
WHERE category_rank <= 2
ORDER BY
    main_category,
    category_rank;