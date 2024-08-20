Create View
	[dbo].[dim_coffee_shop_products]
		As
			Select
				Concat('COF_',Row_Number() Over(Order By CS.Min_TD)) as product_id,
				Replace(CS.product_name,'with Milk','') as base_product,
				Case
					When CS.product_name Like ('%with Milk') then 'With Milk'
					When CS.product_name In ('Latte','Hot Chocolate','Cocoa','Cortado','Cappuccino') Then 'With Milk'
					Else 'Without Milk'
				End as with_milk,
				Case
					When Replace(CS.product_name,'with Milk','') In ('Latte','Americano','Cortado','Espresso','Cappuccino') Then 'Coffee'
					When Replace(CS.product_name,'with Milk','') In ('Hot Chocolate','Cocoa') Then 'Other'
				End as beverage_type,
				CS.product_name
			From (
					Select
					Distinct
						CS.product_name,
						TD.TD as Min_TD
					From Coffee_Shop_Sales as CS

						Inner Join (
									Select
									CS.product_name,
									Min(CS.transaction_date) as TD
									From Coffee_Shop_Sales as CS

									Group By
										CS.product_name
									) as TD on CS.product_name = TD.product_name
					) as CS