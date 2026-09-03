# Amazon 데이터셋 기반 추천 시스템 설계 보고서

## 1. 프로젝트 개요

본 프로젝트는 Amazon 상품 및 평가 데이터를 활용하여 서로 다른 목적을 가진 5가지 추천 시스템을 SQL로 설계하는 것을 목표로 한다.

상품의 평균 평점, 평가 수, 가격, 할인율, 대표 후기, 리뷰 작성자 및 카테고리 정보를 활용하여 사용자의 상품 탐색과 비교를 도울 수 있는 규칙 기반 추천 로직을 구현하였다.

본 프로젝트에서 설계한 추천 시스템은 다음과 같다.

1. 믿고 사는 베스트셀러
2. 검증된 가성비 상품
3. 대표 후기의 위험 신호가 적은 상품
4. 공통 리뷰어 기반 유사 상품
5. 카테고리별 균형 추천

각 추천 시스템은 단순히 평점 기준만 변경하지 않고, 신뢰도 점수 계산, 실제 할인율 검증, 후기 키워드 탐색, 공통 리뷰어 분석, 카테고리별 순위 계산 등 서로 다른 방식으로 설계하였다.

---

## 2. 데이터 구조 및 전처리

### 2.1 주요 데이터 구조

Amazon 데이터셋은 상품별로 다음과 같은 정보를 제공한다.

- 상품 ID와 상품명
- 계층형 카테고리
- 정가와 할인가
- 표시 할인율
- 상품의 평균 평점
- 평점이 등록된 횟수
- 대표 후기의 제목과 내용
- 리뷰 작성자 ID
- 상품 이미지 및 판매 페이지 링크

한 행은 기본적으로 하나의 상품을 나타내지만, 동일한 `product_id`가 여러 행에 존재할 수 있다. 또한 `user_id`, `review_id`, `review_title`, `review_content`에는 여러 값이 하나의 문자열 안에 저장되어 있다.

### 2.2 전처리 사항

SQL 분석 전 다음과 같은 데이터 구조를 고려하였다.

- `rating`, `rating_count`, `actual_price`, `discounted_price`, `discount_percentage`가 문자형으로 저장되어 있어 계산 전에 숫자형으로 변환했다.
- 가격의 인도 루피 기호(`₹`)와 천 단위 쉼표를 `REPLACE()`로 제거한 뒤 `DOUBLE`로 변환했다.
- `rating_count`의 쉼표를 제거한 뒤 `INTEGER`로 변환했다.
- 숫자로 변환할 수 없는 값이 포함되어 있더라도 쿼리 전체가 중단되지 않도록 `TRY_CAST()`를 사용했다.
- 동일한 상품이 추천 결과에 중복으로 나타나는 것을 줄이기 위해 필요한 쿼리에서 `product_id`를 기준으로 그룹화했다.
- 중복 행에 평점이나 평가 수가 다르게 기록된 경우에는 `MAX()`를 사용하여 대표값을 선택했다.
- 쉼표로 연결된 여러 사용자 ID는 `STRING_SPLIT()`과 `UNNEST()`를 사용하여 사용자 한 명당 한 행으로 분리했다.
- `category`는 여러 분류 단계가 `|`로 연결된 구조이므로 `SPLIT_PART()`를 이용해 첫 번째 대분류를 추출했다.

### 2.3 데이터의 한계

이 데이터에는 실제 구매 여부, 구매 수량, 상품 조회 기록 및 이용 시점이 포함되어 있지 않다. 따라서 본 보고서에서 말하는 인기도는 실제 판매량이 아니라 평균 평점과 평가 수를 바탕으로 판단한 결과이다.

또한 개별 사용자가 부여한 평점은 확인할 수 없고, 상품의 전체 평균 평점만 제공된다. 따라서 리뷰 작성 여부만으로 사용자가 해당 상품을 긍정적으로 평가했다고 단정할 수 없다.

`review_content`와 `review_title` 역시 전체 후기 원문이 아니라 데이터에 포함된 일부 대표 후기이므로, 키워드 분석 결과를 전체 고객의 의견으로 일반화할 수 없다.

이러한 한계를 고려하여 각 추천 결과는 실제 구매 예측이 아닌, 현재 데이터에서 확인할 수 있는 정보를 바탕으로 구성한 추천 후보로 해석하였다.

---

## 3. 추천 시스템 설계

### 3.1 믿고 사는 베스트셀러

#### 1. 추천 테마

평균 평점만 높은 상품은 평가 수가 적어 결과의 신뢰도가 낮을 수 있다. 따라서 평균 평점과 평가 수를 함께 반영하여, 많은 평가가 누적되면서 만족도도 높은 상품을 추천한다.

#### 2. 사용자 가치

사용자가 상품을 처음 탐색할 때 소수의 평가만으로 평점이 높아진 상품보다, 충분한 평가가 누적된 검증된 인기 상품을 먼저 확인할 수 있다.

#### 3. 구현 로직

- 평균 평점이 4.0 이상인 상품을 선별했다.
- 평점 등록 수가 1,000개 이상인 상품만 포함하여 소수 평가로 인한 불확실성을 줄였다.
- 동일한 상품 ID와 상품명이 반복된 행은 `GROUP BY`로 하나로 집계하고, 중복 행에 기록된 값 중 최댓값을 대표값으로 사용했다.
- 평균 평점과 평가 수를 함께 반영하기 위해 다음과 같이 신뢰도 점수를 계산했다.

`베스트셀러 점수 = 평균 평점 × LN(평가 수 + 1)`

평가 수를 그대로 곱하면 평가 수가 많은 상품이 점수를 지나치게 지배할 수 있으므로 자연로그를 적용하였다. 평점 4.0과 평가 수 1,000개는 절대적인 품질 기준이 아니라, 기본적인 만족도와 평가의 누적 정도를 확보하기 위해 설정한 운영 기준이다.

#### 4. SQL 쿼리

```sql
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
```

#### 5. 실행 결과

![믿고 사는 베스트셀러 실행 결과](images/result_01.png)

[결과 CSV 파일](01_믿고사는_베스트셀러_결과.csv)

#### 6. 결과 해석

실행 결과, 평균 평점이 높으면서 평가 수가 충분히 많은 상품들이 상위에 선정되었다. 특히 Amazon Basics HDMI 케이블과 같이 평점이 4점 이상이고 수십만 건의 평가가 누적된 상품이 높은 베스트셀러 점수를 기록했다.

이는 단순히 평균 평점만 비교한 것이 아니라, 해당 평점이 얼마나 많은 이용자의 평가를 바탕으로 형성되었는지 함께 반영한 결과이다. 다만 이 데이터에는 실제 판매량이 없으므로, 여기서 말하는 베스트셀러는 실제 판매량 기준이 아니라 평점과 평가 수를 결합한 추천상의 인기 상품을 의미한다.

---

### 3.2 할인율 일치 여부를 확인한 고평가 상품

#### 1. 추천 테마

표시 할인율이 높은 상품 중에서 정가와 할인가를 이용해 직접 계산한 할인율이 표시 할인율과 거의 일치하고, 평균 평점과 평가 수도 일정 기준 이상인 상품을 추천한다.

단순히 할인율만 높은 상품을 선택하지 않고 할인율의 계산상 일치 여부와 상품 평가를 함께 확인하여, 할인 폭이 크면서도 기본적인 만족도가 확보된 상품을 선별한다.

#### 2. 사용자 가치

사용자는 표시 할인율만 보고 상품을 선택하는 대신, 실제 정가와 할인가로 다시 계산한 할인율을 확인할 수 있다. 또한 평점과 평가 수 기준을 함께 적용하여 할인 폭은 크지만 평가가 좋지 않거나 평가 자료가 지나치게 적은 상품을 제외할 수 있다.

#### 3. 구현 로직

- `actual_price`와 `discounted_price`에서 루피 기호(`₹`)와 쉼표를 제거하고 숫자형으로 변환했다.
- `discount_percentage`에서 `%` 기호를 제거하고 숫자형으로 변환했다.
- 다음 계산식을 이용하여 할인율을 직접 계산했다.

`계산 할인율 = (정가 - 할인가) ÷ 정가 × 100`

- 계산 과정에서 0으로 나누는 문제를 방지하기 위해 정가가 0보다 큰 상품만 사용했다.
- 계산 할인율이 40% 이상인 상품만 포함하여 비교적 할인 폭이 큰 상품을 선별했다.
- 표시 할인율과 계산 할인율의 차이가 2%p 이하인 경우만 포함했다.
- 평균 평점 4.0 이상, 평가 수 1,000개 이상인 상품만 추천 후보로 사용했다.
- 동일한 상품 ID와 상품명이 반복된 행은 하나로 집계하고, 중복 행에 기록된 값 중 최댓값을 대표값으로 사용했다.
- 계산 할인율이 높은 순서로 정렬하고, 할인율이 같으면 평균 평점이 높은 상품을 우선 추천했다.

40% 할인율과 평점 4.0, 평가 수 1,000개는 절대적인 품질 기준이 아니라 할인 혜택, 기본 만족도 및 평가 자료의 누적 정도를 함께 확보하기 위해 설정한 운영 기준이다. 표시 할인율과 계산 할인율의 차이는 가격 표시 과정에서 발생할 수 있는 반올림을 고려하여 2%p까지 허용했다.

#### 4. SQL 쿼리

```sql
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
```

#### 5. 실행 결과

![할인율 일치 여부를 확인한 고평가 상품 실행 결과](images/result_02.png)

[결과 CSV 파일](02_검증된_가성비상품_결과.csv)

#### 6. 결과 해석

추천 결과에는 계산 할인율이 40% 이상이고, 표시 할인율과 계산 할인율의 차이가 2%p 이하인 상품들이 포함되었다. 모든 결과는 평균 평점 4.0 이상, 평가 수 1,000개 이상의 조건도 충족했다.

가장 높은 순위의 Mini USB-C 어댑터는 정가 ₹4,999에서 할인가 ₹294로 표시되어 계산 할인율이 94.1%였으며, 표시 할인율 94%와의 차이는 0.1%p였다. 평균 평점은 4.3점, 평가 수는 4,426개로 설정한 추천 조건을 충족했다.

다만 결과를 검토하는 과정에서 상품명, 가격, 평점 및 평가 수가 같은 Fire-Boltt 스마트워치가 서로 다른 `product_id`로 저장되어 추천 목록에 반복되는 문제가 발견되었다. 현재 쿼리는 `product_id`와 `product_name`을 함께 그룹화하므로 상품 ID가 다르면 별도의 상품으로 처리된다.

이는 쿼리가 실행되지 않는 문법 오류는 아니지만, 동일하거나 매우 유사한 상품이 추천 결과를 여러 자리 차지한다는 한계가 있다. 이후에는 `product_name`을 기준으로 추가 중복 제거를 적용하거나, 상품명이 같은 행에 순위를 부여하여 대표 상품 하나만 남기는 방식으로 수정할 필요가 있다.

또한 계산 할인율은 데이터에 기록된 정가와 할인가의 산술적 차이를 확인한 값이다. 따라서 표시 할인율과 계산값이 일치하더라도 정가가 시장가격에 비해 적절한지 또는 다른 판매처보다 실제로 저렴한지까지 검증한 결과는 아니다.


---

### 3.3 대표 후기의 위험 신호가 적은 상품

#### 1. 추천 테마

평균 평점과 평가 수뿐만 아니라 데이터에 포함된 대표 후기의 제목과 내용도 함께 확인한다. 기본 평가 조건을 충족하면서 대표 후기에서 고장, 반품, 강한 불만 및 품질 문제와 관련된 표현이 적게 발견된 상품을 추천한다.

#### 2. 사용자 가치

평균 평점만으로는 확인하기 어려운 구체적인 불만 표현을 함께 살펴볼 수 있다. 이를 통해 평점과 평가 수가 충분하더라도 대표 후기에 위험 신호가 나타나는 상품을 구분할 수 있다.

#### 3. 구현 로직

* 평균 평점 4.0 이상, 평가 수 1,000개 이상인 상품을 추천 후보로 설정했다.
* `review_title`과 `review_content`를 결합하여 대표 후기의 제목과 내용을 함께 탐색했다.
* `COALESCE()`를 사용하여 후기 제목이나 내용이 결측인 경우 빈 문자열로 처리했다.
* `REGEXP_MATCHES()`의 대소문자 구분 없는 검색 옵션인 `'i'`를 사용했다.
* 부정 표현을 고장, 반품, 강한 불만, 품질 문제의 네 가지 유형으로 구분했다.
* 각 유형의 표현이 하나 이상 발견되면 1, 발견되지 않으면 0을 부여했다.
* 네 유형의 값을 합산하여 `negative_signal_types`를 계산했다.
* 부정 신호가 한 종류 이하인 상품만 남겼다.
* 부정 신호 유형 수가 적은 상품을 먼저 정렬하고, 그 값이 같으면 평균 평점과 평가 수가 높은 상품을 우선 추천했다.

`negative_signal_types`는 부정 단어가 등장한 전체 횟수가 아니라, 네 가지 부정 신호 유형 중 몇 종류가 발견되었는지를 나타낸다.

#### 4. SQL 쿼리

```sql
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
    + quality_signal AS negative_signal_types

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
```

#### 5. 실행 결과

![대표 후기의 위험 신호가 적은 상품 실행 결과](images/result_03.png)

[결과 CSV 파일](03_대표후기_위험신호가_적은상품_결과.csv)

#### 6. 결과 해석

추천 결과로 총 10개 상품이 출력되었으며, 평균 평점은 4.5점에서 4.8점 사이였다. 모든 상품은 평가 수 1,000개 이상의 조건을 충족했다.

상위 10개 상품 모두 `defect_signal`, `return_signal`, `dissatisfaction_signal`, `quality_signal`이 0으로 나타났으며, 이를 합산한 `negative_signal_types` 역시 0이었다. 즉, 데이터에 포함된 대표 후기에서는 설정한 네 가지 유형의 부정 표현이 발견되지 않았다.

가장 먼저 추천된 전기 온수기 상품은 평균 평점 4.8점, 평가 수 53,803개였으며, 대표 후기에서 설정한 부정 신호가 발견되지 않았다. 그 밖에도 마우스패드, 스마트폰 강화유리, 무선 마우스 및 HDMI 케이블 등이 추천 결과에 포함되었다.

다만 이 데이터의 `review_title`과 `review_content`는 전체 후기가 아니라 상품별로 제공된 일부 대표 후기이다. 따라서 신호값이 0이라는 결과는 전체 후기에 부정적인 의견이 전혀 없다는 의미가 아니라, 데이터에 포함된 대표 후기에서 지정한 표현이 발견되지 않았다는 의미이다.

또한 키워드 기반 탐색은 문장의 전체 맥락을 정확히 판단하지 못한다. 예를 들어 `replacement` 등의 단어는 문맥에 따라 반드시 부정적인 의미가 아닐 수 있다. 향후 전체 개별 리뷰 데이터가 제공된다면 후기별 부정 표현의 비율이나 감성분석 결과를 이용해 추천 로직을 보완할 수 있다.

---

### 3.4 공통 리뷰어 기반 연관 상품 후보

#### 1. 추천 테마

동일한 사용자가 여러 상품에 리뷰를 남긴 기록을 활용하여 상품 간 연관성을 탐색한다. 두 상품에 공통으로 리뷰를 남긴 사용자가 많을수록 관련 가능성이 높은 상품 쌍으로 판단하고, 데이터 전체에서 연관성이 높은 상품 쌍을 추천 후보로 추출한다.

#### 2. 사용자 가치

공통 리뷰어가 많은 상품 쌍을 미리 파악하면, 서비스에서 특정 상품을 보여줄 때 함께 비교할 연관 상품 후보를 구성하는 데 활용할 수 있다. 사용자는 규격, 길이, 색상 또는 세부 모델이 비슷한 상품을 함께 비교할 수 있다.

#### 3. 구현 로직

- 한 셀에 쉼표로 연결된 여러 `user_id`를 `STRING_SPLIT()`으로 분리했다.
- `UNNEST()`를 사용하여 상품과 리뷰어의 조합을 리뷰어 한 명당 한 행으로 펼쳤다.
- `SELECT DISTINCT`를 사용하여 같은 상품과 리뷰어의 중복 조합을 제거했다.
- 분리한 상품·리뷰어 테이블을 리뷰어 ID를 기준으로 자기 자신과 조인했다.
- 동일한 리뷰어가 등장한 서로 다른 상품을 하나의 상품 쌍으로 연결했다.
- `a.product_id < b.product_id` 조건을 사용하여 A-B와 B-A가 중복 출력되는 것을 방지하고, 같은 상품끼리 연결되는 경우를 제외했다.
- 두 상품에 모두 리뷰를 남긴 사용자의 수를 `COUNT(DISTINCT reviewer_id)`로 계산했다.
- 공통 리뷰어가 2명 이상인 상품 쌍만 추천 후보로 사용했다.
- 공통 리뷰어 수가 많은 상품 쌍부터 정렬하여 상위 10개를 출력했다.
- 한 명의 공통 리뷰어만으로 형성된 우연한 연결을 일부 제외하기 위해 공통 리뷰어가 2명 이상인 상품 쌍만 사용했다. 이 기준은 절대적인 연관성 기준이 아니라 단일 리뷰어 연결을 제외하기 위한 운영 기준이다.

#### 4. SQL 쿼리

```sql
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
```

#### 5. 실행 결과

![공통 리뷰어 기반 유사 상품 실행 결과](images/result_04.png)

[결과 CSV 파일](04_공통리뷰어_기반_유사상품_결과.csv)

#### 6. 결과 해석

실행 결과, 상위 10개 상품 쌍은 모두 공통 리뷰어 수가 8명으로 나타났다. 연결된 상품을 확인한 결과, 완전히 다른 종류의 상품보다는 동일 브랜드의 비슷한 모델이나 옵션 상품이 주로 연결되었다.

예를 들어 TP-Link의 서로 다른 USB Wi-Fi 어댑터 모델, 길이가 다른 BlueRigger 광케이블, 길이와 구성 수량이 다른 Amazon Basics HDMI 및 USB 케이블, 색상이 다른 JBL 유선 이어폰이 서로 연관 상품으로 추출되었다.

따라서 이 결과는 함께 구매되는 상품을 보여준다기보다, 동일한 리뷰어 정보가 나타나는 유사 모델이나 옵션 상품을 비교 후보로 제시하는 데 활용할 수 있다.

다만 상위 상품 쌍의 공통 리뷰어 수가 모두 8명이고 서로 유사한 상품이 주로 연결된 점을 고려하면, 제품 변형이나 상품 패밀리 사이에 동일한 대표 리뷰어 정보가 반복되어 저장되었을 가능성이 있다. 또한 데이터에는 구매 여부, 조회 기록, 리뷰 작성 시점 및 개별 사용자의 평점이 없으므로 공통 리뷰어 수를 동시 구매나 긍정적인 선호 관계로 해석할 수 없다.

---

### 3.5 카테고리별 균형 추천

#### 1. 추천 테마

전체 상품을 하나의 목록에서 경쟁시키면 평가 수가 많은 특정 카테고리의 상품이 추천 결과를 대부분 차지할 수 있다. 이를 보완하기 위해 상품을 대분류별로 나누고, 각 카테고리 안에서 평점과 평가 수를 결합한 점수가 높은 상품을 최대 2개씩 추천한다.

#### 2. 사용자 가치

특정 종류의 인기 상품에 추천 결과가 집중되는 현상을 줄이고, 여러 카테고리의 우수 상품을 고르게 탐색할 수 있도록 한다. 이를 통해 사용자는 전체 인기 순위에서는 발견하기 어려운 다른 카테고리의 상품도 확인할 수 있다.

#### 3. 구현 로직

- `SPLIT_PART(category, '|', 1)`을 사용하여 계층형 카테고리에서 첫 번째 대분류를 추출했다.
- 동일한 상품 ID가 반복된 경우 `product_id`를 기준으로 그룹화하고 상품명, 카테고리, 평점 및 평가 수의 대표값을 생성했다.
- 평균 평점 4.0 이상, 평가 수 1,000개 이상인 상품만 추천 후보로 사용했다.
- 평균 평점과 평가 수를 함께 반영하기 위해 다음과 같이 카테고리 점수를 계산했다.

`카테고리 점수 = 평균 평점 × LN(평가 수 + 1)`

- 평가 수의 크기가 점수를 지나치게 지배하지 않도록 자연로그를 적용했다.
- `PARTITION BY main_category`를 사용하여 전체 상품이 아닌 카테고리별로 순위를 새로 계산했다.
- 각 대분류에서 카테고리 점수가 높은 상품을 최대 2개씩 추출했다.
- 조건을 만족하는 상품이 2개보다 적은 카테고리에서는 존재하는 상품만 출력했다.

평점 4.0과 평가 수 1,000개는 기본적인 만족도와 평가 자료의 누적 정도를 확보하기 위해 설정한 운영 기준이다.

#### 4. SQL 쿼리

```sql
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
```

#### 5. 실행 결과

![카테고리별 균형 추천 실행 결과](images/result_05.png)

[결과 CSV 파일](05_카테고리별_균형추천_결과.csv)

#### 6. 결과 해석

실행 결과, Computers&Accessories, Electronics, Health&PersonalCare, Home&Kitchen, HomeImprovement, MusicalInstruments, OfficeProducts, Toys&Games의 총 8개 대분류에서 13개 상품이 추천되었다.

Computers&Accessories에서는 SanDisk USB 저장장치 2개가 선정되었고, Electronics에서는 Amazon Basics HDMI 케이블 2개가 선정되었다. Home&Kitchen과 HomeImprovement, OfficeProducts에서도 각각 2개 상품이 출력되었다.

반면 Health&PersonalCare, MusicalInstruments, Toys&Games에서는 추천 조건을 충족한 상품이 하나씩만 존재하여 각 카테고리의 1위 상품만 출력되었다. 이는 쿼리 오류가 아니라 평균 평점 4.0 이상, 평가 수 1,000개 이상이라는 조건을 만족하는 후보 수가 부족했기 때문이다.

전체 상품을 대상으로 한 첫 번째 추천과 달리, 이번 추천은 카테고리별로 순위를 새로 계산했기 때문에 여러 대분류의 상품이 결과에 포함되었다. 다만 대분류 수준의 다양성은 확보되었지만, Electronics의 상위 상품이 모두 HDMI 케이블인 것처럼 각 카테고리 내부의 세부 상품 다양성까지 보장하지는 않는다.

---

## 4. 종합 결론

본 프로젝트에서는 Amazon 상품 및 평가 데이터를 활용하여 서로 다른 목적을 가진 5가지 추천 시스템을 SQL로 구현하였다.

| 추천 시스템 | 주요 활용 정보 | 추천 목적 |
|---|---|---|
| 믿고 사는 베스트셀러 | 평균 평점, 평가 수 | 평가가 충분히 누적된 인기 상품 추천 |
| 할인율 일치 여부를 확인한 고평가 상품 | 정가, 할인가, 표시 할인율, 평점 | 할인 폭과 표시 할인율의 계산상 일치 여부 확인 |
| 대표 후기의 위험 신호가 적은 상품 | 후기 제목, 후기 내용, 평점 | 대표 후기에서 부정 표현이 적게 발견된 상품 추천 |
| 공통 리뷰어 기반 연관 상품 후보 | 상품 ID, 리뷰 작성자 ID | 동일한 리뷰어가 나타난 연관 상품 쌍 탐색 |
| 카테고리별 균형 추천 | 카테고리, 평점, 평가 수 | 대분류별 상위 상품을 최대 2개씩 제시 |

첫 번째 추천은 전체 상품의 평점과 평가 수를 결합하여 검증된 인기 상품을 찾았다. 두 번째 추천은 정가와 할인가를 이용해 할인율을 다시 계산하고 상품 평가 조건을 함께 적용했다. 세 번째 추천은 대표 후기에서 부정적인 표현을 탐색했으며, 네 번째 추천은 공통 리뷰어 정보를 이용해 연관 상품 쌍을 찾았다. 마지막 추천은 대분류별로 순위를 계산하여 여러 카테고리의 상품이 결과에 포함되도록 했다.

분석 과정에서 동일하거나 매우 유사한 상품이 서로 다른 상품 ID로 저장된 경우와, 유사 상품 사이에 같은 대표 리뷰어 정보가 반복된 것으로 보이는 사례가 발견되었다. 또한 실제 구매량, 구매 시점, 조회 기록 및 개별 사용자의 평점이 없어 추천 결과를 실제 구매 행동이나 긍정적인 선호로 해석하기 어렵다는 한계가 있다.

따라서 본 프로젝트의 결과는 실제 구매를 예측하는 완성된 추천 모델이 아니라, 현재 데이터에서 확인할 수 있는 상품·평가·대표 후기·리뷰어 정보를 바탕으로 구성한 규칙 기반 추천 후보로 해석해야 한다.

향후 실제 구매 이력, 개별 평점, 조회 및 클릭 기록, 리뷰 작성 시점이 추가된다면 사용자별 선호도와 상품 간 연관성을 더 정확하게 반영한 개인화 추천 시스템으로 확장할 수 있다.