/*
网址：https://8weeksqlchallenge.com/
1.每位顾客在餐厅总花费多少？

答：要知道总的消费就需要将menu和sales连接起来，
join on就是其中的语法，并且join on 还是临时表格，不会保存在数据库中；
我的想法是：先把两个表拼在一起并且重新给一个名字，当然这个表是一个临时的表，然后再用sum()查询总消费



2.每位顾客光顾餐厅多少天？
答：我的想法是查天数肯定不能直接求和，因为天数不能相加，
所以可以用count(distinct 属性)，count可以计算天数，distinct有区分的意思，可以不重复相加。



3.每位顾客从菜单上购买的第一道菜是什么？

答：我的逻辑是先把需要的属性放在一张表里面，然后用min（）取出最小天数的每位顾客的第
一件商品。这个逻辑并没有成功，min(order_date) 是单独对日期做聚合计算，它没有 “锁定同一行” 的能力。
这是AI完善我的思路写出来的：可以先把先 join，把 sales、menu 合并成一张宽表，再单独聚合：
每个顾客算出最小下单日期，把上面的结果和这张宽表再连接，用 customer_id + order_date 双重匹配，锁定那一行。
第一步合并两个表格，第二步查出每个顾客最早日期，第三步拼起来，拿到第一件商品；


4.菜单上购买次数最多的菜品是什么？所有顾客购买了多少次？
把销售表和菜单表连起来，拿到菜品名字；按菜品分组，统计购买次数；次数从高到低排序，取第一条，就是购买最多的菜品
问题一：

问题二：

5.哪款商品最受每位顾客欢迎？
6.成为会员后，客户最先购买的是哪一项商品？
7.在客户成为会员之前刚购买的商品是哪一项？
8.每位会员在成为会员之前，总计的物品和花费金额是多少？
9.如果每花1美元相当于10积分，而寿司有2倍积分倍数—那每位顾客会有多少积分？
10.客户加入计划的第一周（包括加入日期）会在所有商品上获得2倍积分，不仅仅是寿司—客户A和B在一月底时有多少积分？
*/

-- 1.每位顾客总花费
select *
from menu
join sales on menu.product_id=sales.product_id;

create temporary table new_menu
select menu.product_id, menu.product_name, menu.price, sales.customer_id, sales.order_date
from menu
join sales on menu.product_id=sales.product_id;

select customer_id, sum(price) as total_cost
from new_mwnu
group by customer_id;
-- 2.每位顾客光顾天数（去重日期）
select customer_id, count(distinct order_date) as visit_day
from sales
group by customer_id;

-- 3.每位顾客购买的第一道菜品
use dannys_diner;
select customer_id, order_date, product_name
from sales
join menu on sales.product_id=menu.product_id;

select customer_id,min(order_date) as first_day
from sales
group by customer_id;

SELECT all_info.customer_id, all_info.order_date, all_info.product_name
FROM (
    SELECT customer_id, order_date, product_name
    FROM sales
    JOIN menu ON sales.product_id = menu.product_id
) AS all_info
JOIN (
    SELECT customer_id, MIN(order_date) AS first_day
    FROM sales
    GROUP BY customer_id
) AS first_table
ON all_info.customer_id = first_table.customer_id
AND all_info.order_date = first_table.first_day;

-- 4.购买次数最多的菜品
SELECT
menu.product_name,count(sales.product_id) as total_count
FROM sales
JOIN menu ON sales.product_id = menu.product_id
GROUP BY menu.product_name
ORDER BY total_count DESC
LIMIT 1;
SELECT
    s.customer_id,count(*) as buy_times
from sales s
group by s.customer_id; 

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
