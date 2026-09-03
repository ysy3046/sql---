# ### 추천 시스템 1: 믿고 사는 베스트셀러
#
# #### 추천 테마
# 평점과 리뷰 수를 함께 반영하여 많은 고객에게 검증된 상품을 추천한다.
#
# #### 구현 로직
# 평점 4.0 이상, 리뷰 수 1,000개 이상인 상품을 대상으로
# 평점 × LN(리뷰 수 + 1)의 추천 점수를 계산했다.
# 동일한 상품은 GROUP BY를 이용해 중복을 제거했다.
#
# #### SQL 쿼리
# [SQL 코드가 보이는 캡처]
#
# #### 실행 결과
# [결과표가 보이는 캡처]
#
# #### 결과 해석
# 평점과 리뷰 수가 모두 높은 상품이 상위에 선정되었다.
#
# SELECT
#     product_id,
#     product_name,
#     MAX(TRY_CAST(rating AS DOUBLE)) AS product_rating,
#     MAX(
#         TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
#     ) AS product_rating_count,
#     ROUND(
#         MAX(TRY_CAST(rating AS DOUBLE))
#         * LN(
#             MAX(
#                 TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
#             ) + 1
#         ),
#         2
#     ) AS bestseller_score
# FROM amazon
# GROUP BY
#     product_id,
#     product_name
# HAVING MAX(TRY_CAST(rating AS DOUBLE)) >= 4.0
#    AND MAX(
#        TRY_CAST(REPLACE(rating_count, ',', '') AS INTEGER)
#    ) >= 1000
# ORDER BY bestseller_score DESC
# LIMIT 10;