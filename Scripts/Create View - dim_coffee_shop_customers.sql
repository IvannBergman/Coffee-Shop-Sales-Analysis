Create View
	[dbo].[dim_coffee_shop_customers]
		As
			Select
				Concat('CUST_',Row_Number()Over(Order By CS.Min_TD)) as customer_id,
				concat('Person ',Row_Number()Over(Order By CS.Min_TD)) as customer_name,
				CS.card_id
			From (
					Select
					Distinct
						CS.card_id,
						TD.TD as Min_TD
					From Coffee_Shop_Sales as CS

						Inner Join (
									Select
									CS.card_id,
									Min(CS.transaction_date) as TD
									From Coffee_Shop_Sales as CS

									Group By
										CS.card_id
									) as TD on CS.card_id = TD.card_id

					Where
						CS.card_id != 'cash'
					) as CS