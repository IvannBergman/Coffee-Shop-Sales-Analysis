Create View
	[dbo].[fact_coffee_shop_transactions]
		As
			Select
				CS.record_id as transaction_id,
				CS.transaction_date as transaction_date,
				DateName(weekday,DatePart(dw,transaction_date)) as transaction_week_day,
				Case
					When Convert(Time,CS.transaction_date) between '07:00:00' and '11:59:59' Then 'Morning - 7am to 11am'
					When Convert(Time,CS.transaction_date) between '12:00:00' and '16:59:59' Then 'Afternoon - 12pm to 4pm'
					When Convert(Time,CS.transaction_date) between '17:00:00' and '19:59:59' Then 'Evening - 5pm to 7pm'
					When Convert(Time,CS.transaction_date) between '20:00:00' and '23:59:59' Then 'Night - 8pm to 11pm'
				End as transaction_time_grouping,
				IsNull(customers.customer_id,cash_cust.cash_cust_id) as customer_id,
				CS.transaction_type,
				products.product_id,
				CS.transaction_amount
			From coffee_shop_sales as CS

				Left Join dim_coffee_shop_products as products on CS.product_name = products.product_name
				left Join dim_coffee_shop_customers as customers on CS.card_id = customers.card_id
				left Join (
							Select --(cash customers)--
							Distinct
								record_id,
								Concat('Cash_Customer_',Row_number() Over(Order By transaction_date)) as cash_cust_id
							From Coffee_Shop_Sales as CSS

							Where
								transaction_type = 'cash'
							) as cash_cust on CS.record_id = cash_cust.record_id