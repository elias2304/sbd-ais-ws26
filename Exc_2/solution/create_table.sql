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