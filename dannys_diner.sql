/*
1.每位顾客在餐厅总花费多少？
2.每位顾客光顾餐厅多少天？
3.每位顾客从菜单上购买的第一道菜是什么？
4.菜单上购买次数最多的菜品是什么？所有顾客购买了多少次？
5.哪款商品最受每位顾客欢迎？
6.成为会员后，客户最先购买的是哪一项商品？
7.在客户成为会员之前刚购买的商品是哪一项？
8.每位会员在成为会员之前，总计的物品和花费金额是多少？
9.如果每花1美元相当于10积分，而寿司有2倍积分倍数—那每位顾客会有多少积分？
10.客户加入计划的第一周（包括加入日期）会在所有商品上获得2倍积分，不仅仅是寿司—客户A和B在一月底时有多少积分？
*/

-- 1.每位顾客总花费
SELECT
    s.customer_id,
    SUM(m.price) AS total_spend
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- 2.每位顾客光顾天数（去重日期）
SELECT
    customer_id,
    COUNT(DISTINCT order_date) AS visit_days
FROM sales
GROUP BY customer_id;

-- 3.每位顾客购买的第一道菜品
SELECT customer_id, product_name
FROM (
    SELECT
        s.customer_id,
        m.product_name,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date ASC) AS rn
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
) t
WHERE rn = 1;

-- 4.购买次数最多的菜品
SELECT
    m.product_name,
    COUNT(*) AS buy_count
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY buy_count DESC
LIMIT 1;

-- 5.每位顾客最喜欢（购买最多）的菜品
SELECT customer_id, product_name, buy_count
FROM (
    SELECT
        s.customer_id,
        m.product_name,
        COUNT(*) AS buy_count,
        RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(*) DESC) AS rk
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
) t
WHERE rk = 1;

-- 6.成为会员之后，最先买的商品
SELECT customer_id, product_name
FROM (
    SELECT
        s.customer_id,
        m.product_name,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date ASC) AS rn
    FROM sales s
    JOIN members mb ON s.customer_id = mb.customer_id
    JOIN menu m ON s.product_id = m.product_id
    WHERE s.order_date >= mb.join_date
) t
WHERE rn = 1;

-- 7.成为会员之前，最后一次购买的商品
SELECT customer_id, product_name
FROM (
    SELECT
        s.customer_id,
        m.product_name,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rn
    FROM sales s
    JOIN members mb ON s.customer_id = mb.customer_id
    JOIN menu m ON s.product_id = m.product_id
    WHERE s.order_date < mb.join_date
) t
WHERE rn = 1;

-- 8.入会之前，购买总数 + 总花费
SELECT
    s.customer_id,
    COUNT(*) AS total_item,
    SUM(m.price) AS total_money
FROM sales s
JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m ON s.product_id = m.product_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id;

-- 9.积分：1美元=10分，寿司双倍
SELECT
    s.customer_id,
    SUM(
        CASE WHEN m.product_name = 'sushi' THEN m.price * 20
        ELSE m.price * 10 END
    ) AS points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- 10.入会首周全部商品双倍积分，求A、B 1月底积分
SELECT
    s.customer_id,
    SUM(
        CASE WHEN s.order_date BETWEEN mb.join_date AND DATE_ADD(mb.join_date,INTERVAL 6 DAY)
             THEN m.price * 20
             ELSE m.price * 10 END
    ) AS points
FROM sales s
JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m ON s.product_id = m.product_id
WHERE s.order_date <= '2021-01-31'
GROUP BY s.customer_id;
