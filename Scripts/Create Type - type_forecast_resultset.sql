Create Type
	[dbo].[type_forecast_resultset] as Table (
		[transaction_id] Int,
		[transaction_date] Date,
		[transaction_week_day] NVarChar(50),
		[transaction_time_grouping] NVarChar(50),
		[amount_type] NVarChar(50),
		[product_id] NVarChar(50),
		[transaction_amount] Decimal(19,6))