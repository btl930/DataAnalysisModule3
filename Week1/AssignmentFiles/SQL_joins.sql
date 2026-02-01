USE coffeeshop_db;

-- =========================================================
-- JOINS & RELATIONSHIPS PRACTICE
-- =========================================================

-- Q1) Join products to categories: list product_name, category_name, price.
select p.name as product_name, c.name as category_name, p.price 
from categories c
inner join products p
	on c.category_id = p.category_id;
-- Q2) For each order item, show: order_id, order_datetime, store_name,
--     product_name, quantity, line_total (= quantity * products.price).
--     Sort by order_datetime, then order_id.
select o.order_id, o.order_datetime, s.name as store_name, p.name as product_name, oi.quantity,(oi.quantity * p.price) as line_total
from stores s
inner join orders o on s.store_id = o.store_id 
inner join order_items oi on o.order_id = oi.order_id
inner join products p on oi.product_id = p.product_id
order by o.order_datetime, o.order_id;
-- Q3) Customer order history (PAID only):
--     For each order, show customer_name, store_name, order_datetime,
--     order_total (= SUM(quantity * products.price) per order).
select o.order_id, concat(c.first_name,', ', c.last_name) as customer_name, s.name as store_name, o.order_datetime, (sum(oi.quantity * p.price)) as order_total
from customers c
inner join orders o on c.customer_id = o.customer_id and o.status = 'paid'
inner join stores s on o.store_id = s.store_id
inner join order_items oi on o.order_id = oi.order_id
inner join products p on oi.product_id = p.product_id
group by o.order_id, customer_name, store_name, o.order_datetime;
-- Q4) Left join to find customers who have never placed an order.
--     Return first_name, last_name, city, state.
select c.first_name, c.last_name, c.city, c.state
from customers c
left join orders o on c.customer_id = o.customer_id
where o.customer_id is Null;
-- Q5) For each store, list the top-selling product by units (PAID only).
--     Return store_name, product_name, total_units.
--     Hint: Use a window function (ROW_NUMBER PARTITION BY store) or a correlated subquery.

-- Q6) Inventory check: show rows where on_hand < 12 in any store.
--     Return store_name, product_name, on_hand.
select s.name as store_name, p.name as product_name, i.on_hand
from inventory i
inner join stores s on i.store_id = s.store_id
inner join products p on i.product_id = p.product_id
and i.on_hand < 12;
-- Q7) Manager roster: list each store's manager_name and hire_date.
--     (Assume title = 'Manager').
select s.name as store_name, 
concat(e.first_name, ', ', e.last_name) as manager_name,
e.hire_date
from employees e
inner join stores s on e.store_id = s.store_id 
and e.title = 'Manager';
-- Q8) Using a subquery/CTE: list products whose total PAID revenue is above
--     the average PAID product revenue. Return product_name, total_revenue.

-- Q9) Churn-ish check: list customers with their last PAID order date.
--     If they have no PAID orders, show NULL.
--     Hint: Put the status filter in the LEFT JOIN's ON clause to preserve non-buyer rows.
select concat(c.first_name, ', ', c.last_name) as customer_name, 
max(date(o.order_datetime)) as last_paid_order_date
from customers c
left join orders o on c.customer_id = o.customer_id and o.status = 'paid'
group by customer_name
order by last_paid_order_date desc;
-- Q10) Product mix report (PAID only):
--     For each store and category, show total units and total revenue (= SUM(quantity * products.price)).