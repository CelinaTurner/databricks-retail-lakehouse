-- Silver: clean and conform the raw bronze transactions.
--   * cast types and normalize column names
--   * drop cancellations (Invoice starting with 'C')
--   * drop non-positive quantity/price and null customers
--   * derive line_revenue
--
-- Column names below assume the UCI "Online Retail II" schema. If you loaded
-- the older "Online Retail" file instead, swap: Invoice->InvoiceNo,
-- Price->UnitPrice, `Customer ID`->CustomerID.

with source as (

    select * from {{ source('bronze', 'online_retail') }}

),

renamed as (

    select
        cast(`Invoice`     as string)    as invoice_no,
        cast(`StockCode`   as string)    as stock_code,
        cast(`Description`  as string)   as description,
        cast(`Quantity`    as int)       as quantity,
        coalesce(
            try_to_timestamp(`InvoiceDate`, 'MM/dd/yyyy HH:mm'), 
            try_to_timestamp('InvoiceDate', 'MM/dd/yyyy HH:mm:ss')
            ) as invoice_ts,
        cast(`Price`       as double)    as unit_price,
        cast(`Customer_ID` as string)    as customer_id,
        cast(`Country`     as string)    as country
    from source

),

cleaned as (

    select
        *,
        quantity * unit_price as line_revenue
    from renamed
    where quantity > 0
      and unit_price > 0
      and customer_id is not null
      and not startswith(invoice_no, 'C')

)

select * from cleaned
