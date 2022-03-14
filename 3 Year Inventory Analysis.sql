USE eCommerce;

/*
3 Year Inventory Analysis
*/

/*
The data we shall query & extract is based on the business requirement of 3 year analysis.
Hence, we have a set of columns that are dimensions and metrics, these form the basis of our 
visualisations contained in our dashboards.

Product,ProductSubCategory and ProductCategory dimensions are part of the data source that has the
potential to be used in subsequent visualisations.
*/
select * from ProductSubcategory;
select * from ProductCategory;
select
		ProductKey,ProductSubcategoryKey,ProductName,StandardCost,ListPrice,SupplierId
from
		product;

/*
# As this is a monthly analysis over 3 years (2017 to 2019); the metrics are captured for the end of month i.e. 
	EOM Snapshot for example the SOH (Stock On Hand) is registered as at the End of Month when the business does a 
	monthly stocktake and we use the StockTakeFlag for this.

	If a flag is not available then the SQL Function EOMONTH(StockTxnDate) could be used instead for example.

# Pre-aggregation is done to reduce the data set size as well as enable the data set to be product agnostic
	thus reducing the calculations required by the Viz Tool (i.e. Less proprietary work)

# The Metrics required for the project data set will be the foundation for a Union All and reduce the
	data size significantly as very often a visualisation does not require a full data set.
   
-- Unioned Data-Set Select template ...

  select
   Prod.ProductKey,
   StockTxnDate,												-- Stock Take is end of each month
   0 as SOHQty,
   0 as BOQQty,
   '' StockStatus,
   0 as StockStatusCount,
   '' as BackorderStatus,
   0 as BackorderStatusCount,
   0 as SOHCost,
   0 as LostSalesValue,
   0 as OverStockAmount,
   0 as OverStockCost
  from
   Product prod inner join
   ProductInventory inv on prod.ProductKey = inv.ProductKey inner join
   ProductSubcategory psc on prod.ProductSubcategoryKey = psc.ProductSubcategoryKey 
  where	
   Condition(s)
  group by
   Column(s)

  UNION ALL
  .
  .
  .
*/

/*
The query below is to demonstrate a single metric worksheet in Tableau and how the query will influence the union all clause.
The metric name is SOHQty.
*/
select
   Prod.ProductKey,
   StockTxnDate,												
   sum(StockOnHand) as SOHQty,
   0 as BOQQty,
   '' StockStatus,
   0 as StockStatusCount,
   '' as BackorderStatus,
   0 as BackorderStatusCount,
   0 as SOHCost,
   0 as LostSalesValue,
   0 as OverStockAmount,
   0 as OverStockCost
  from
   Product prod inner join
   ProductInventory inv on prod.ProductKey = inv.ProductKey inner join
   ProductSubcategory psc on prod.ProductSubcategoryKey = psc.ProductSubcategoryKey 
  where	
   StockOnHand > 0 and
   StockTakeFlag = 'Y'
  group by
   prod.ProductKey,
   inv.StockTxnDate

/*
Let's add the Back Order Qty using the union all clause.
The Back Order Qty amount is the amount of stock on order with our Suppliers because 
sales activity probably depleted stock levels to 0 or below the order threshold
*/

 UNION ALL

select
   Prod.ProductKey,
   StockTxnDate,												
   0 as SOHQty,
   SUM([BackOrderQty]) as BOQQty, 
   '' StockStatus,
   0 as StockStatusCount,
   '' as BackorderStatus,
   0 as BackorderStatusCount,
   0 as SOHCost,
   0 as LostSalesValue,
   0 as OverStockAmount,
   0 as OverStockCost
  from
   Product prod inner join
   ProductInventory inv on prod.ProductKey = inv.ProductKey inner join
   ProductSubcategory psc on prod.ProductSubcategoryKey = psc.ProductSubcategoryKey 
  where	
   [BackOrderQty]>0 AND 
   [StockTakeFlag] = 'Y'
  group by
   Prod.ProductKey,
   StockTxnDate

/*
Let's test the stock on hand values based on the business rules.

Business rules for the Stock Status dimension are ...
1		SOH >= ReorderPoint							: means Stock Level OK
2		SOH = 0 and BackOrderQty > 0				: means Out of Stock - Back Ordered
3		SOH < ReorderPoint and BackOrderQty	> 0		: means Low Stock - Back Ordered
4		BOQ = 0 and SOH <= ReorderPoint				: means Reorder Now
*/

 UNION ALL 

SELECT
   ProductKey,
   StockTxnDate,									
   0 as SOHQty,
   0 as BOQQty,
   StockStatus,
   count(StockStatus) as StockStatusCount,
   '' as BackorderStatus,
   0 as BackorderStatusCount,
   0 as SOHCost,
   0 as LostSalesValue,
   0 as OverStockAmount,
   0 as OverStockCost
FROM 
(
select 
    prod.ProductKey,
    StockTxnDate,
    case 
        when StockOnHand >= prod.ReorderPoint then 'Stock Level OK'
        when StockOnHand = 0 and BackOrderQty > 0 then 'Out of Stock - Back Ordered'
        when (StockOnHand < prod.ReorderPoint) and BackOrderQty > 0 then 'Low Stock - Back Ordered'
        when BackOrderQty = 0 and (StockOnHand <= prod.ReorderPoint) then 'Reorder Now'
    end as StockStatus
from 
    Product prod inner join
    ProductInventory inv on prod.ProductKey = inv.ProductKey inner join
    ProductSubcategory psc on prod.ProductSubcategoryKey = psc.ProductSubcategoryKey 
where 
    [StockOnHand] > 0 and 
    [StockTakeFlag] = 'Y' ) as dtStockStatus
group by 
    ProductKey,
    StockStatus,
    StockTxnDate

/*
Business rules for the BackOrderStatus dimension are ...
1		BackOrderQty > 0 and BackOrderQty <=10 	: means Up to 10 on order
2		BackOrderQty >10 and BackOrderQty <=20	: means Up to 20 on order
3		BackOrderQty >20 and BackOrderQty <=40	: means Up to 40 on order
4		BackOrderQty >40 and BackOrderQty <=60	: means Up to 60 on order
5	   BackOrderQty >60						: means 60 + on order

*/

UNION ALL 

SELECT
   ProductKey,
   StockTxnDate,									
   0 as SOHQty,
   0 as BOQQty,
   '' as StockStatus,
   0 as StockStatusCount,
   BackorderStatus,
   COUNT(BackorderStatus) as BackorderStatusCount,
   0 as SOHCost,
   0 as LostSalesValue,
   0 as OverStockAmount,
   0 as OverStockCost
FROM
(
select 
    prod.ProductKey,
    StockTxnDate,
    case 
        when BackOrderQty > 0 and BackOrderQty <= 10 then 'Up to 10 0n order'
        when BackOrderQty > 10 and BackOrderQty <= 20 then 'Up to 20 0n order'
        when BackOrderQty > 20 and BackOrderQty <= 40 then 'Up to 40 0n order'
        when BackOrderQty > 40 and BackOrderQty <= 60 then 'Up to 60 0n order'
        else 
            '60+ 0n order'
    end as BackOrderStatus
from 
    Product prod inner join
    ProductInventory inv on prod.ProductKey = inv.ProductKey inner join
    ProductSubcategory psc on prod.ProductSubcategoryKey = psc.ProductSubcategoryKey 
where 
    [BackOrderQty] > 0 and 
    [StockTakeFlag] = 'Y' ) as dtBackOrderStatus
group by 
    ProductKey,
    BackOrderStatus,
    StockTxnDate

/*
In this scenario the Stock on Hand Cost is to be visualised, and there is
no such value in the ProductInventory table, consequently we do this manually in the query.

Compute a value based upon two colmuns inside an aggregation function.
*/
UNION ALL 

select
   Prod.ProductKey,
   StockTxnDate,											
   0 as SOHQty,
   0 as BOQQty,
   '' StockStatus,
   0 as StockStatusCount,
   '' as BackorderStatus,
   0 as BackorderStatusCount,
   sum(StockOnHand*UnitCost) as SOHCost,
   0 as LostSalesValue,
   0 as OverStockAmount,
   0 as OverStockCost
from
   Product prod inner join
   ProductInventory inv on prod.ProductKey = inv.ProductKey inner join
   ProductSubcategory psc on prod.ProductSubcategoryKey = psc.ProductSubcategoryKey 
where	
   StockOnHand>0 and
   StockTakeFlag='Y'
group by
   prod.productkey,
   StockTxnDate

/*	 
The query below is to fullfill the analytics for Lost Sales Value.

Business rules for the lost sales value ...
   Lost sales are calculated as any stock item that is 0 On Hand and has a backorder
   value > 0 multiplied by the List Price of the item.
*/

UNION ALL 

select
   Prod.ProductKey,
   StockTxnDate,											
   0 as SOHQty,
   0 as BOQQty,
   '' StockStatus,
   0 as StockStatusCount,
   '' as BackorderStatus,
   0 as BackorderStatusCount,
   0 as SOHCost,
   SUM(BackOrderQty*ListPrice) as LostSalesValue,
   0 as OverStockAmount,
   0 as OverStockCost
from
   Product prod inner join
   ProductInventory inv on prod.ProductKey = inv.ProductKey inner join
   ProductSubcategory psc on prod.ProductSubcategoryKey = psc.ProductSubcategoryKey 
where
   BackOrderQty > 0 and
   StockOnHand = 0 and
   StockTakeFlag = 'Y'
group by
   prod.productkey,
   StockTxnDate

/*
Let's look at the Overstock Quantity scenario. There is
no such value in the ProductInventory table, consequently we do this 
manually in the query.
*/
UNION ALL

select
   Prod.ProductKey,
   StockTxnDate,												
   0 as SOHQty,
   0 as BOQQty,
   '' StockStatus,
   0 as StockStatusCount,
   '' as BackorderStatus,
   0 as BackorderStatusCount,
   0 as SOHCost,
   0 as LostSalesValue,
   sum(StockOnHand-MaxStockLevel) as OverStockAmount,
   0 as OverStockCost
from
   Product prod inner join
   ProductInventory inv on prod.ProductKey = inv.ProductKey inner join
   ProductSubcategory psc on prod.ProductSubcategoryKey = psc.ProductSubcategoryKey 
where	
   StockOnHand>MaxStockLevel and
   StockTakeFlag ='Y'
group by
   prod.ProductKey,
   StockTxnDate

/*
Overstock Cost $ analytics.
Business rules for the overstock value
   Overstock value is calculated as the Overstock Amount x UnitCost
*/

UNION ALL

select
   Prod.ProductKey,
   StockTxnDate,												
   0 as SOHQty,
   0 as BOQQty,
   '' StockStatus,
   0 as StockStatusCount,
   '' as BackorderStatus,
   0 as BackorderStatusCount,
   0 as SOHCost,
   0 as LostSalesValue,
   0 as OverStockAmount,
   sum((StockOnHand-MaxStockLevel)* UnitCost) as OverStockCost
from
   Product prod inner join
   ProductInventory inv on prod.ProductKey = inv.ProductKey inner join
   ProductSubcategory psc on prod.ProductSubcategoryKey = psc.ProductSubcategoryKey 
where	
   StockOnHand>MaxStockLevel and
   StockTakeFlag ='Y'
group by
   prod.ProductKey,
   StockTxnDate