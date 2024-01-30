-- Use the required database
USE gdb023;



/*
Q1: Provide the list of markets in which customer 
"Atliq Exclusive" operates its business in the APAC region.
*/
SELECT DISTINCT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';



/*
Q2: What is the percentage of unique product increase in 2021 vs. 2020?
*/
WITH UniqueProducts AS (
    SELECT
        fiscal_year,
        COUNT(DISTINCT product_code) AS unique_products_count
    FROM fact_sales_monthly
    GROUP BY fiscal_year
)

SELECT
    UP_2020.unique_products_count AS unique_products_2020,
    UP_2021.unique_products_count AS unique_products_2021,
    ROUND(((UP_2021.unique_products_count - UP_2020.unique_products_count) * 100.0) / UP_2020.	unique_products_count, 2) AS percentage_chg
FROM
    UniqueProducts UP_2020
    CROSS JOIN UniqueProducts UP_2021
WHERE
    UP_2020.fiscal_year = 2020
    AND UP_2021.fiscal_year = 2021;



/* Q3: Provide a report with all the unique product counts for 
each segment and sort them in descending order of product counts. */
SELECT
    segment,
    COUNT(DISTINCT product) AS product_count
FROM
    dim_product
GROUP BY
    segment
ORDER BY
    product_count DESC;



/* Q4: Which segment had the most increase in unique products in 2021 vs 2020? */
WITH UniqueProducts AS (
    SELECT
        dp.segment,
        fsm.fiscal_year,
        COUNT(DISTINCT fsm.product_code) AS unique_products_count
    FROM
        fact_sales_monthly fsm
    JOIN
        dim_product dp ON fsm.product_code = dp.product_code
    GROUP BY
        dp.segment, fsm.fiscal_year
)

SELECT
    UP_2020.segment,
    UP_2020.unique_products_count AS product_count_2020,
    UP_2021.unique_products_count AS product_count_2021,
    UP_2021.unique_products_count - UP_2020.unique_products_count AS difference
FROM
    UniqueProducts UP_2020
    JOIN UniqueProducts UP_2021 ON UP_2020.segment = UP_2021.segment
WHERE
    UP_2020.fiscal_year = 2020
    AND UP_2021.fiscal_year = 2021
ORDER BY
    difference DESC;



/* Q5: Get the products that have the highest and lowest manufacturing costs. */
SELECT 
    dm.product_code,
    dm.product,
    fmc.manufacturing_cost
FROM
    dim_product dm
JOIN
    fact_manufacturing_cost fmc ON dm.product_code = fmc.product_code
WHERE
    fmc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
    OR fmc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
ORDER BY
    fmc.manufacturing_cost DESC;



/* Q6: Generate a report which contains the top 5 customers who received an average 
high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. */
SELECT
    dc.customer_code,
    dc.customer,
    ROUND(AVG(fpid.pre_invoice_discount_pct), 2) AS average_discount_percentage
FROM
    dim_customer dc
JOIN
    fact_pre_invoice_deductions fpid ON dc.customer_code = fpid.customer_code
WHERE
    fpid.fiscal_year = '2021'
    AND dc.market = 'India'
GROUP BY
    dc.customer_code, dc.customer
ORDER BY
    average_discount_percentage DESC
LIMIT 5;



/* Q7: Get the complete report of the Gross sales amount for the customer
“Atliq Exclusive” for each month. This analysis helps to get an idea of low
and high-performing months and take strategic decisions. */
SELECT
    MONTH(fsm.date) AS "Month",
    YEAR(fsm.date) AS "Year",
    ROUND(SUM(fgp.gross_price * fsm.sold_quantity), 2) AS "Gross Sales Amount"
FROM
    dim_customer dc
JOIN
    fact_sales_monthly fsm ON dc.customer_code = fsm.customer_code
JOIN
    fact_gross_price fgp ON fsm.product_code = fgp.product_code
WHERE
    dc.customer = "Atliq Exclusive"
GROUP BY
    "Month", "Year", fsm.date
ORDER BY
    "Year", "Month";



/* Q8: Calculate the total sold quantity for each quarter in 2020 */
WITH QuarterSales AS (
    SELECT
        CASE
            WHEN MONTH(date) BETWEEN 1 AND 3 THEN 'Q1'
            WHEN MONTH(date) BETWEEN 4 AND 6 THEN 'Q2'
            WHEN MONTH(date) BETWEEN 7 AND 9 THEN 'Q3'
            WHEN MONTH(date) BETWEEN 10 AND 12 THEN 'Q4'
        END AS Quarter,
        SUM(sold_quantity) AS total_sold_quantity
    FROM
        fact_sales_monthly
    WHERE
        fiscal_year = 2020
    GROUP BY
        Quarter
)

SELECT
    Quarter,
    total_sold_quantity
FROM
    QuarterSales
ORDER BY
    total_sold_quantity DESC;


    
/* Q9: Which channel helped to bring more gross sales in the 
fiscal year 2021 and the percentage of contribution? */
WITH ChannelGrossSales AS (
    SELECT
        dc.channel,
        SUM(fgp.gross_price * fsm.sold_quantity) AS gross_sales
    FROM
        fact_sales_monthly fsm
    JOIN
        fact_gross_price fgp ON fsm.product_code = fgp.product_code
    JOIN
        dim_customer dc ON fsm.customer_code = dc.customer_code
    WHERE
        fsm.fiscal_year = 2021
    GROUP BY
        dc.channel
)

, TotalGrossSales AS (
    SELECT
        SUM(fgp.gross_price * fsm.sold_quantity) AS total_gross_sales
    FROM
        fact_sales_monthly fsm
    JOIN
        fact_gross_price fgp ON fsm.product_code = fgp.product_code
    WHERE
        fsm.fiscal_year = 2021
)

SELECT
    cgs.channel,
    ROUND(cgs.gross_sales) AS gross_sales_mln,
    ROUND((cgs.gross_sales / tgs.total_gross_sales) * 100, 2) AS percentage
FROM
    ChannelGrossSales cgs
JOIN
    TotalGrossSales tgs ON 1 = 1 -- Dummy join to get the total gross sales
ORDER BY
    cgs.gross_sales DESC;



/* Q10: Get the Top 3 products in each division that have a 
high total_sold_quantity in the fiscal_year 2021? */
WITH RankedProducts AS (
    SELECT
        dp.division,
        fsm.product_code,
        dp.product,
        SUM(fsm.sold_quantity) AS total_sold_quantity,
        RANK() OVER (PARTITION BY dp.division ORDER BY SUM(fsm.sold_quantity) DESC) AS rank_order
    FROM
        fact_sales_monthly fsm
    JOIN
        dim_product dp ON fsm.product_code = dp.product_code
    WHERE
        fsm.fiscal_year = 2021
    GROUP BY
        dp.division, fsm.product_code, dp.product
)

SELECT
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM
    RankedProducts
WHERE
    rank_order <= 3;
