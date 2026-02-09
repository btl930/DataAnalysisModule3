USE coffeeshop_db;

-- =========================================================
-- ADVANCED SQL ASSIGNMENT
-- Subqueries, CTEs, Window Functions, Views
-- =========================================================
-- Notes:
-- - Unless a question says otherwise, use orders with status = 'paid'.
-- - Write ONE query per prompt.
-- - Keep results readable (use clear aliases, ORDER BY where it helps).

-- =========================================================
-- Q1) Correlated subquery: Above-average order totals (PAID only)
-- =========================================================
-- For each PAID order, compute order_total (= SUM(quantity * products.price)).
-- Return: order_id, customer_name, store_name, order_datetime, order_total.
-- Filter to orders where order_total is greater than the average PAID order_total
-- for THAT SAME store (correlated subquery).
-- Sort by store_name, then order_total DESC.
select o.order_id, 
	concat(c.first_name, ' ', c.last_name) as customer_name, 
    s.name as store_name, 
    o.order_datetime, 
    sum(oi.quantity * p.price) as order_total
from orders o
join customers c on o.customer_id = c.customer_id
join stores s on o.store_id = s.store_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
where o.status = 'paid'
group by o.order_id, c.first_name, c.last_name, s.name, o.order_datetime
having sum(oi.quantity * p.price) > (
	select avg(order_total)
    from (
		select sum(oi2.quantity * p2.price) as order_total
		from orders o2
		join order_items oi2 on o2.order_id = oi2.order_id
		join products p2 on oi2.product_id = p2.product_id
		where o2.status = 'paid' 
        and o2.store_id = o.store_id
        group by o2.order_id) avg_order_total_table
        )
	order by store_name, order_total desc;
-- =========================================================
-- Q2) CTE: Daily revenue and 3-day rolling average (PAID only)
-- =========================================================
-- Using a CTE, compute daily revenue per store:
--   revenue_day = SUM(quantity * products.price) grouped by store_id and DATE(order_datetime).
-- Then, for each store and date, return:
--   store_name, order_date, revenue_day,
--   rolling_3day_avg = average of revenue_day over the current day and the prior 2 days.
-- Use a window function for the rolling average.
-- Sort by store_name, order_date.
with revenue_day as (
	select sum(oi.quantity * p.price) as revenue_day, o.store_id, date(o.order_datetime) as order_date
    from order_items oi
    join products p on oi.product_id = p.product_id
    join orders o on oi.order_id = o.order_id
    where o.status = 'paid'
    group by o.store_id, date(o.order_datetime) )
select s.name as store_name, r.order_date, r.revenue_day,
	avg(r.revenue_day) over (partition by s.name order by r.order_date rows between 2 preceding and current row) rolling_3day_avg
from revenue_day r
join stores s on r.store_id = s.store_id
order by s.name, r.order_date;
-- =========================================================
-- Q3) Window function: Rank customers by lifetime spend (PAID only)
-- =========================================================
-- Compute each customer's total spend across ALL stores (PAID only).
-- Return: customer_id, customer_name, total_spend,
--         spend_rank (DENSE_RANK by total_spend DESC).
-- Also include percent_of_total = customer's total_spend / total spend of all customers.
-- Sort by total_spend DESC.
with total_spend as (
	select 
		o.customer_id, 
		concat(c.first_name, ' ', c.last_name) as customer_name, 
		sum(oi.quantity * p.price) as total_spend
	from orders o
	join customers c on o.customer_id = c.customer_id
	join order_items oi on o.order_id = oi.order_id
	join products p on oi.product_id = p.product_id
	where o.status = 'paid'
	group by o.customer_id, c.first_name, c.last_name
    )
select *, 
	dense_rank() over (order by t.total_spend desc) as spend_rank,
    (t.total_spend * 100) / sum(t.total_spend) over () as percent_of_total
from total_spend t
order by t.total_spend desc;
-- =========================================================
-- Q4) CTE + window: Top product per store by revenue (PAID only)
-- =========================================================
-- For each store, find the top-selling product by REVENUE (not units).
-- Revenue per product per store = SUM(quantity * products.price).
-- Return: store_name, product_name, category_name, product_revenue.
-- Use a CTE to compute product_revenue, then a window function (ROW_NUMBER)
-- partitioned by store to select the top 1.
-- Sort by store_name.
with product_revenue_table as (
	select s.name as store_name, 
        p.name as product_name, 
		c.name as category_name,  
        sum(oi.quantity * p.price) as product_revenue,
        row_number() over (
			partition by s.name 
            order by (sum(oi.quantity * p.price)) desc) as rn
    from stores s 
    join orders o on s.store_id = o.store_id
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    join categories c on p.category_id = c.category_id
    where o.status = 'paid'
    group by s.name, p.name, c.name)
select store_name, product_name, category_name, product_revenue
from product_revenue_table 
where rn = 1
order by store_name;
-- =========================================================
-- Q5) Subquery: Customers who have ordered from ALL stores (PAID only)
-- =========================================================
-- Return customers who have at least one PAID order in every store in the stores table.
-- Return: customer_id, customer_name.
-- Hint: Compare count(distinct store_id) per customer to (select count(*) from stores).
select o.customer_id, concat(c.first_name, ' ', c.last_name) as customer_name
from orders o
join customers c on o.customer_id = c.customer_id
where o.status = 'paid'
group by o.customer_id 
having count(distinct o.store_id) = (
	select count(*) 
    from stores);
-- =========================================================
-- Q6) Window function: Time between orders per customer (PAID only)
-- =========================================================
-- For each customer, list their PAID orders in chronological order and compute:
--   prev_order_datetime (LAG),
--   minutes_since_prev (difference in minutes between current and previous order).
-- Return: customer_name, order_id, order_datetime, prev_order_datetime, minutes_since_prev.
-- Only show rows where prev_order_datetime is NOT NULL.
-- Sort by customer_name, order_datetime.
with prev_order_datetime as (
	select c.customer_id, 
		concat(c.first_name, ' ', c.last_name) as customer_name, 
		o.order_id, 
		o.order_datetime, 
		lag(o.order_datetime) over (partition by c.customer_id) as prev_order_datetime
    from customers c
    join orders o on c.customer_id = o.customer_id
    where o.status = 'paid'
    group by c.customer_id, c.last_name, c.first_name, o.order_id, o.order_datetime
    ),
minutes_since_prev as (
	select pov.customer_name, 
		pov.order_id, 
		pov.order_datetime, 
		pov.prev_order_datetime,
        TIMESTAMPDIFF(MINUTE, prev_order_datetime, order_datetime) AS minutes_since_prev
    from prev_order_datetime pov
    where prev_order_datetime is not null
    )	
select *
from minutes_since_prev
order by customer_name, order_datetime;
-- =========================================================
-- Q7) View: Create a reusable order line view for PAID orders
-- =========================================================
-- Create a view named v_paid_order_lines that returns one row per PAID order item:
--   order_id, order_datetime, store_id, store_name,
--   customer_id, customer_name,
--   product_id, product_name, category_name,
--   quantity, unit_price (= products.price),
--   line_total (= quantity * products.price)
-- 
create or replace view v_paid_order_lines as 
	select
		o.order_id, o.order_datetime, o.store_id, s.name as store_name,
        c.customer_id, concat(c.first_name, ' ', c.last_name) as customer_name,
        p.product_id, p.name as product_name, ca.name as category_name,
        oi.quantity, p.price as unit_price,
        (oi.quantity * p.price) as line_total
	from orders o
    join stores s on o.store_id = s.store_id
    join customers c on o.customer_id = c.customer_id
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    join categories ca on p.category_id = ca.category_id
    where o.status = 'paid';
    
-- After creating the view, write a SELECT that uses the view to return:
--   store_name, category_name, revenue
-- where revenue is SUM(line_total),
-- sorted by revenue DESC.
select store_name, category_name, sum(line_total) as revenue
from v_paid_order_lines
group by store_name, category_name
order by revenue desc;
-- =========================================================
-- Q8) View + window: Store revenue share by payment method (PAID only)
-- =========================================================
-- Create a view named v_paid_store_payments with:
--   store_id, store_name, payment_method, revenue
-- where revenue is total PAID revenue for that store/payment_method.
--
-- Then query the view to return:
--   store_name, payment_method, revenue,
--   store_total_revenue (window SUM over store),
--   pct_of_store_revenue (= revenue / store_total_revenue)
-- Sort by store_name, revenue DESC.
create or replace view v_paid_store_payments as
	select s.store_id, s.name as store_name, o.payment_method, sum(oi.quantity * p.price) as revenue
    from stores s 
    join orders o on s.store_id = o.store_id
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    where o.status = 'paid'
    group by s.store_id, s.name, o.payment_method;
    
select store_name, payment_method, revenue, store_total_revenue,
	(revenue / store_total_revenue) * 100 as pct_of_store_revenue
from (
	select store_name, payment_method, revenue,
		sum(revenue) over (partition by store_name) as store_total_revenue
	from v_paid_store_payments
    group by store_name, payment_method, revenue
    ) t
order by store_name, revenue desc;

-- =========================================================
-- Q9) CTE: Inventory risk report (low stock relative to sales)
-- =========================================================
-- Identify items where on_hand is low compared to recent demand:
-- Using a CTE, compute total_units_sold per store/product for PAID orders.
-- Then join inventory to that result and return rows where:
--   on_hand < total_units_sold
-- Return: store_name, product_name, on_hand, total_units_sold, units_gap (= total_units_sold - on_hand)
-- Sort by units_gap DESC.
with total_units_sold as (
	select o.store_id, s.name as store_name, p.product_id, p.name as product_name, sum(oi.quantity) as total_units_sold
    from orders o 
    join order_items oi on o.order_id = oi.order_id
    join stores s on o.store_id = s.store_id
    join products p on oi.product_id = p.product_id
    where o.status = 'paid'
    group by o.store_id, oi.product_id
    )
select t.store_name, t.product_name, i.on_hand, t.total_units_sold, (t.total_units_sold - i.on_hand) as units_gap
from total_units_sold t
join inventory i on t.store_id = i.store_id and t.product_id = i.product_id
where i.on_hand < t.total_units_sold
order by units_gap desc;