-- Gold: revenue and activity rolled up by country (BI-ready).

select
    country,
    count(distinct invoice_no)   as order_count,
    count(distinct customer_id)  as customer_count,
    sum(quantity)                as units_sold,
    sum(line_revenue)            as total_revenue
from {{ ref('stg_online_retail') }}
group by country
order by total_revenue desc
