WITH product_reviewers AS (
    SELECT DISTINCT
        product_id,
        TRIM(reviewer_id) AS reviewer_id
    FROM amazon
    CROSS JOIN UNNEST(
        STRING_SPLIT(user_id, ',')
    ) AS reviewer_table(reviewer_id)
    WHERE TRIM(reviewer_id) <> ''
),

product_names AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name
    FROM amazon
    GROUP BY product_id
),

product_pairs AS (
    SELECT
        a.product_id AS product_a_id,
        b.product_id AS product_b_id,
        COUNT(DISTINCT a.reviewer_id) AS shared_reviewer_count
    FROM product_reviewers AS a
    INNER JOIN product_reviewers AS b
        ON a.reviewer_id = b.reviewer_id
       AND a.product_id < b.product_id
    GROUP BY
        a.product_id,
        b.product_id
    HAVING COUNT(DISTINCT a.reviewer_id) >= 2
)

SELECT
    pairs.product_a_id,
    product_a.product_name AS base_product,
    pairs.product_b_id,
    product_b.product_name AS recommended_product,
    pairs.shared_reviewer_count

FROM product_pairs AS pairs

INNER JOIN product_names AS product_a
    ON pairs.product_a_id = product_a.product_id

INNER JOIN product_names AS product_b
    ON pairs.product_b_id = product_b.product_id

ORDER BY
    pairs.shared_reviewer_count DESC,
    pairs.product_a_id,
    pairs.product_b_id

LIMIT 10;