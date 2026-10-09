-- A
select * from orders_big order by price_per_unit desc limit 1;

-- B
select product_category, sum(quantity) from orders_big group by product_category order by sum(quantity) desc limit 3;

--  C
select product_category, sum(price_per_unit * quantity) from orders_big group by product_category order by sum(price_per_unit * quantity) desc;

-- D
select customer_name, sum(price_per_unit * quantity) from orders_big group by customer_name order by sum(price_per_unit * quantity) desc limit 5;

-- e
select customer_name, count(customer_name) from orders_big group by customer_name order by sum(price_per_unit * quantity) desc limit 5;


-- 2.2 step 1
EXPLAIN ANALYZE SELECT COUNT(*)
FROM people_100k  p1
         JOIN people_100k  p2
              ON p1.country = p2.country;

SELECT COUNT(*)
FROM people_200k  p1
         JOIN people_200k  p2
              ON p1.country = p2.country;


create index county_people_100k on people_100k (country);

-- step 3
SELECT SUM(cnt::bigint * cnt)
FROM (
         SELECT COUNT(*) AS cnt
         FROM people_big
         GROUP BY country
     ) sub;