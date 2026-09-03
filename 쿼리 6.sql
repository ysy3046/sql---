WITH products AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name,
        MAX(STRING_SPLIT(category, '|')[-1]) AS leaf_category,
        MAX(
            TRY_CAST(
                REPLACE(REPLACE(discounted_price, '₹', ''), ',', '')
                AS DOUBLE
            )
        ) AS price_num,
        MAX(TRY_CAST(rating AS DOUBLE)) AS rating_num,
        MAX(
            TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
        ) AS rating_count_num
    FROM amazon
    GROUP BY product_id
),

alternatives AS (
    SELECT
        a.product_id AS base_product_id,
        a.product_name AS base_product,
        a.leaf_category,
        a.price_num AS base_price,
        a.rating_num AS base_rating,

        b.product_id AS alternative_product_id,
        b.product_name AS alternative_product,
        b.price_num AS alternative_price,
        b.rating_num AS alternative_rating,
        b.rating_count_num AS alternative_rating_count,

        ROUND(a.price_num - b.price_num, 2) AS saving_amount,

        ROW_NUMBER() OVER (
            PARTITION BY a.product_id
            ORDER BY
                a.price_num - b.price_num DESC,
                b.rating_num DESC,
                b.rating_count_num DESC
        ) AS alternative_rank

    FROM products AS a
    INNER JOIN products AS b
        ON a.leaf_category = b.leaf_category
       AND a.product_id <> b.product_id
       AND a.product_name <> b.product_name
       AND b.price_num < a.price_num
       AND b.rating_num >= a.rating_num
       AND b.rating_num >= 4.0
       AND b.rating_count_num >= 1000

    WHERE a.price_num IS NOT NULL
      AND a.rating_num IS NOT NULL
)

SELECT
    base_product,
    leaf_category,
    base_price,
    base_rating,
    alternative_product,
    alternative_price,
    alternative_rating,
    alternative_rating_count,
    saving_amount
FROM alternatives
WHERE alternative_rank = 1
ORDER BY saving_amount DESC
LIMIT 20;