# Part 2

## PostgreSQL Analytical Queries (E-commerce)

Create Table and import data
````sql
DROP TABLE IF EXISTS orders_big;

CREATE TABLE orders_big (
                            id SERIAL PRIMARY KEY,
                            customer_name TEXT,
                            product_category TEXT,
                            quantity Integer,
                            price_per_unit float,
                            order_date date,
                            country TEXT
);

\COPY orders_big(customer_name, product_category, quantity, price_per_unit, order_date, country) FROM '/data/orders_1M.csv' DELIMITER ',' CSV HEADER;
````

A. Which order has the highest price_per_unit?
```sql
select * from orders_big order by price_per_unit desc limit 1;
```
841292 | Emma Brown    | Automotive       |        3 |           2000 | 2024-10-11 | Italy


B. What are the top 3 product categories with the highest total quantity sold across all orders?
```sql
select product_category, sum(quantity) from orders_big group by product_category order by sum(quantity) desc limit 3;
```
| product_category |  sum   |
| -----------------|--------|
| Health & Beauty  | 300842 |
| Electronics      | 300804 |
| Toys             | 300598 |

C. What is the total revenue per product category? (Revenue = price_per_unit × quantity)
````sql
select product_category, sum(price_per_unit * quantity) from orders_big group by product_category order by sum(price_per_unit * quantity) desc;
````
| product_category |        sum         |
|------------------|------------------- |
| Automotive       |  306589798.8600011 |
| Electronics      |  241525009.4500002 |
| Home & Garden    |  78023780.09000017 |
| Sports           |  61848990.82999985 |
| Health & Beauty  |  46599817.89000012 |
| Office Supplies  |  38276061.63999986 |
| Fashion          |  31566368.22000021 |
| Toys             |  23271039.02000005 |
| Grocery          | 15268355.660000062 |
| Books            | 12731976.040000059 |

D. Who are the top 5 customers by total spending?
```sql
select customer_name, sum(price_per_unit * quantity) from orders_big group by customer_name order by sum(price_per_unit * quantity) desc limit 5;
```
| customer_name  |        sum        |
| ---------------|------------------ |
| Carol Taylor   | 991179.1799999997 |
| Nina Lopez     | 975444.9500000001 |
| Daniel Jackson | 959344.4800000002 |
| Carol Lewis    | 947708.5700000003 |
| Daniel Young   | 946030.1399999999 |

E. Look at the spending totals in D — and at how many orders each of those customers has. What do you notice? Open ecommerce/dataset_generator.py and explain why the data looks like this.
```sql
select customer_name, count(customer_name) from orders_big group by customer_name order by sum(price_per_unit * quantity) desc limit 5;
```
| customer_name  | count |
| ---------------|------ |
| Carol Taylor   |  1028 |
| Nina Lopez     |   980 |
| Daniel Jackson |  1033 |
| Carol Lewis    |   943 |
| Daniel Young   |   973 |
- There are 1 million lines generated, out of 32 firstnames and 33 lastnames (1056 combinations)
- If we divide 1.000.000 with 1056, we get an average of 947
- We see, that the top five are at the upper tail of a normal distribution, with all except one being above the average
- In general, all prices, categories, quantities and orders are random, so with enough lines and data, there will be a bell curve
- In the real world, the numbers would not be so similar (all around 950): the top 1% would spend way more compared to the rest...

## Activity 2.2 — Why Is This Self-Join So Slow?
Users of the system sometimes run naive queries such as:
````sql
SELECT COUNT(*)
FROM people_big p1
JOIN people_big p2
  ON p1.country = p2.country;
````
### Step 1 — Measure how it grows. Create three smaller copies of the table:
| rows in table | join result (`COUNT(*)`) | time |
|---|---|---|
| 50 000 | 27501822 | 1460.023 ms |
| 100 000 | 109946508 | 6078.843 ms |
| 200 000 | 439395606 | 33648.616 ms |
- With double the input, the time takes 5 times as long
- With 1m rows, it would take around 18 minutes (34*5*5*(5/4)/60)
- The result set grows by a factor of 4 (= 2²)
- With 1m rows, the set would be around 11 billion pairs (5² * 439395606)

### Step 2 - Does an index help?
```sql
create index county_people_100k on people_100k (country);
```
```                                                                                         QUERY PLAN                                                                                          
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=637573.15..637573.16 rows=1 width=8) (actual time=11804.669..11809.630 rows=1.00 loops=1)
   Buffers: shared hit=186
   ->  Gather  (cost=637572.93..637573.14 rows=2 width=8) (actual time=11804.656..11809.620 rows=2.00 loops=1)
         Workers Planned: 1
         Workers Launched: 1
         Buffers: shared hit=186
         ->  Partial Aggregate  (cost=636572.93..636572.94 rows=1 width=8) (actual time=11779.216..11779.218 rows=1.00 loops=2)
               Buffers: shared hit=186
               ->  Parallel Hash Join  (cost=2332.09..474777.44 rows=64718196 width=0) (actual time=277.748..7360.022 rows=54973254.00 loops=2)
                     Hash Cond: (p1.country = p2.country)
                     Buffers: shared hit=186
                     ->  Parallel Index Only Scan using county_people_100k on people_100k p1  (cost=0.29..1596.50 rows=58824 width=8) (actual time=0.022..5.521 rows=50000.00 loops=2)
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=93
                     ->  Parallel Hash  (cost=1596.50..1596.50 rows=58824 width=8) (actual time=276.061..276.062 rows=50000.00 loops=2)
                           Buckets: 131072  Batches: 1  Memory Usage: 5216kB
                           Buffers: shared hit=93
                           ->  Parallel Index Only Scan using county_people_100k on people_100k p2  (cost=0.29..1596.50 rows=58824 width=8) (actual time=0.087..4.641 rows=50000.00 loops=2)
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=93
 Planning:
   Buffers: shared hit=38
 Planning Time: 1.556 ms
 JIT:
   Functions: 16
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 1.988 ms (Deform 0.248 ms), Inlining 249.779 ms, Optimization 106.247 ms, Emission 159.786 ms, Total 517.799 ms
 Execution Time: 11979.689 ms
```
- new time: 5954.371 (time without explain analyze, which has an overhead)
- The time did not change
- The query uses a parallel index only scan using the new index, but the part is not the bottleneck (actual time=0.022)
- The real bottleneck is the aggregate and the parallel hash join which cannot utilize the index
- The index does not help, because it is used, to make queries on specific countries faster (e.g. where country=austria)
- Because there is no where, it has to read all countries, which makes the index completely useless

### Step 3 - Rewrite it?
- The query only wants the number of matching pairs, not the pairs themselves. 
- If a country has k people, how many pairs does it contribute to the join? 
  - as it is the same dataset, it will make a join from all k people to all k people, which creates a space of k²

- Write a query that computes the same number without a join. 
```sql
SELECT SUM(cnt::bigint * cnt)
FROM (
         SELECT COUNT(*) AS cnt
         FROM people_100k
         GROUP BY country
     ) sub;
```
- Check that it returns exactly the same result as the join on people_100k, then run it on people_big and compare its runtime with your prediction from Step 1.
  - Time: 7.206 ms
  - Solution: 109 946 508 (same as above)
  - On big: 235.654 ms
  - Count big: 10 983 941 260
  - 0.2 seconds compared to 18 minutes makes a mile of a difference

### Step 4 — Discussion (submit in writing). 
Considering scalability and efficiency, which approaches and/or optimizations can be applied to improve this kind of query in a real system? Discuss at least:
- what the rewrite in Step 3 tells you about adding more hardware or an index;
  - the statement creates a complexity of O(N²)
  - Adding hardware would only improve the performance in a linear fashion
  - An Index is used for searching specific elements, it does not change the number of elements, that need to be searched

- what you would do if the business actually needed the pairs themselves (not just their count) — would a bigger machine or a cluster help, and how much?
  - as stated above, better hardware would only help to a certain extend
  - a cluster would help, as it would help parallelize the hash join, but it would still need to produce 11 billion rows
  - Potential solutions: decoupled OLAP system, Pagination

- the limits of an OLTP database for this workload, especially in a large-scale cloud environment.
  - OLTP is used for production; it is best for many small reads and writes
  - If we make analytical requests, it takes up all the computing power
  - OLTP typically makes a Row store -> for an avg(*), it needs to read every line, with each column
  - In OLAP, a column store is used -> the system only needs to read the columns it needs, and discards all unrelated columns
  - If a cloud system is used, the costs would be way higher, because a lot of ram and cpu would be needed
  - If these requests are made on an OLTP system, it could lock other transactional requests


