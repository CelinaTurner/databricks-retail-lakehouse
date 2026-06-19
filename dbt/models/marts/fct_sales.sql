-- Gold: sales fact at invoice-line grain.

{{ config(materialized='table') }}

with lines as (

    select
        *,
        row_number() over (
            partition by invoice_no, stock_code, invoice_ts, quantity, unit_price, customer_id
            order by invoice_no
        ) as line_seq
    from {{ ref('stg_online_retail') }}

)

select
    {{ dbt_utils.generate_surrogate_key([
        'invoice_no', 'stock_code', 'invoice_ts',
        'quantity', 'unit_price', 'customer_id', 'line_seq'
    ]) }} as sales_key,
    invoice_no,
    stock_code,
    description,
    customer_id,
    country,
    invoice_ts,
    quantity,
    unit_price,
    line_revenue
from lines