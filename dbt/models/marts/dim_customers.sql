-- Gold: one row per customer, with recency/frequency/monetary measures.

with sales as (

    select * from {{ ref('stg_online_retail') }}

),

customer_agg as (

    select
        customer_id,
        max(country)                                          as country,
        count(distinct invoice_no)                            as order_count,        -- frequency
        sum(line_revenue)                                     as lifetime_revenue,   -- monetary
        min(invoice_ts)                                       as first_order_ts,
        max(invoice_ts)                                       as last_order_ts,
        datediff(current_date(), date(max(invoice_ts)))       as recency_days        -- recency
    from sales
    group by customer_id

)

select
    *,
    round(lifetime_revenue / nullif(order_count, 0), 2) as avg_order_value
from customer_agg
