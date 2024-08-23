Create Function
	[dbo].[fn_coffee_shop_sales_product_recommendations] ()
		Returns @OutputTabe Table (
			[time_group] NVarChar(50),
			[product_id] NVarChar(15),
			[recommended_product_id] NVarChar(15))

			As
				Begin

					Declare @Product_base as Table (
													[time_group] NVarChar(50),
													[product_id] NVarChar(15),
													[beverage_type] NVarChar(15),
													[with_milk] NVarChar(15),
													[base_product] NVarChar(30))

					Insert Into --(@Product_base)--
						@Product_base
							Select --(Product_base)--
								TG.time_group,
								P.product_id,
								P.beverage_type,
								P.with_milk,
								P.base_product
							from dim_coffee_shop_products as P
	
								Inner Join (
											Select
											Distinct
												Trans.transaction_time_grouping as time_group
											From fact_coffee_shop_transactions as Trans
											) as TG on P.product_id = P.product_id

					Declare @Product_recommendations_base as Table (
																	[time_group] NVarChar(50),
																	[product_id] NVarChar(15),
																	[recommended_product_id] NVarChar(15),
																	[product_popularity] Int)

					Insert Into --(@Product_recommendations_base)--
						@Product_recommendations_base
							Select --(Product_recommendations_base)--
								PB.time_group,
								PB.product_id,
								Recs.product_id as recommended_product_id,
								Recs.rank_in_group as product_popularity
							From @Product_base as PB

								Left Join (
											Select
												PB.time_group,
												PB.product_id,
												PB.beverage_type,
												PB.with_milk,
												PB.base_product,
												Row_Number() Over(Partition By PB.time_group Order By trans.trans_count desc) as rank_in_group
											from @Product_base as PB

												Left Join (
															Select
																transaction_time_grouping as time_group,
																product_id,
																count(Distinct(transaction_id)) trans_count
															From fact_coffee_shop_transactions as Trans with(nolock)

															Group By
																transaction_time_grouping,
																product_id
															) as trans on PB.product_id = trans.product_id and PB.time_group = trans.time_group
											) as Recs on
												PB.time_group = Recs.time_group
												and PB.beverage_type = Recs.beverage_type
												and PB.with_milk = Recs.with_milk
												and PB.product_id != Recs.product_id

					Insert Into --(@OutputTabe)--
						@OutputTabe
							Select --(Main Query)--
								PR.time_group,
								PR.product_id,
								PR.recommended_product_id
							From @Product_recommendations_base as PR

								Inner Join (
											Select
												PR.time_group,
												PR.product_id,
												Min(product_popularity) as M_prod_pop
											From @Product_recommendations_base as PR

											Group By
												PR.time_group,
												PR.product_id
											) as M_PR on PR.time_group = M_PR.time_group and PR.product_id = M_PR.product_id and PR.product_popularity = M_PR.M_prod_pop

				Return

				End