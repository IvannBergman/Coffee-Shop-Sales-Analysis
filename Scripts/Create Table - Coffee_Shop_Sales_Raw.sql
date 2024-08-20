Use [Projects_DW]

Drop Table Coffee_Shop_Sales

Create Table
	[dbo].[Coffee_Shop_Sales] (
		[record_id] Int Not Null Primary Key,
		[date] Date Null,
		[transaction_date] DateTime Null,
		[transaction_type] NvarChar(15) Null,
		[card_id] NVarChar(50) Null,
		[transaction_amount] Decimal(19,6) Null,
		[product_name] NVarChar(50) Null,
		[ingest_date] DateTime Null)