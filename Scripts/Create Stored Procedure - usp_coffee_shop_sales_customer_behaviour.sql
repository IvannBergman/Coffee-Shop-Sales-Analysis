Create Procedure
	[dbo].[usp_coffee_shop_sales_customer_behaviour]
		As
			Begin

				If Object_ID('tempdb..#base_transactions') Is Not Null Drop Table #base_transactions
				If Object_ID('tempdb..#customers_unpivoted') Is Not Null Drop Table #customers_unpivoted
				If Object_ID('tempdb..#customer_habits_base') Is Not Null Drop Table #customer_habits_base

				Select --(#base_transactions)--
					Trans.transaction_id,
					Trans.transaction_date,
					Trans.transaction_week_day,
					Trans.transaction_time_grouping,
					Trans.customer_id,
					Trans.product_id,
					Prods.beverage_type,
					Prods.base_product,
					Prods.with_milk,
					Prods.product_name,
					Trans.transaction_amount
				Into #base_transactions
				From fact_coffee_shop_transactions as Trans

					Inner Join dim_coffee_shop_products as Prods on Trans.product_id = Prods.product_id

				Where
					transaction_type = 'card'

				Select --(#customers_unpivoted)--
					customer_id,
					record_type,
					record_label,
					record_rank,
					total_volume,
					total_spend
				Into #customers_unpivoted
				From (
						Select --(Totals)--
							customer_id,
							'Overall' record_type,
							'Totals' as record_label,
							Row_Number() Over(Order By Count(Distinct(transaction_id)) desc, Sum(transaction_amount) desc, Max(transaction_date) desc) as record_rank,
							Convert(Decimal(19,6),Count(Distinct(transaction_id))) as total_volume,
							Sum(transaction_amount) as total_spend,
							Max(transaction_date) as total_mtd
						From #base_transactions as trans with(nolock)

						Group By
							customer_id

						Union All

						Select --(Product)--
							customer_id,
							'Product' record_type,
							product_id as record_label,
							Row_Number() Over(Partition By customer_id Order By Count(Distinct(transaction_id)) desc, Sum(transaction_amount) desc, Max(transaction_date) desc) as record_rank,
							Count(Distinct(transaction_id)) as total_volume,
							Sum(transaction_amount) as total_spend,
							Max(transaction_date) as total_mtd
						From #base_transactions as trans with(nolock)

						Group By
							customer_id,
							product_id

						Union All

						Select --(Week day)--
							customer_id,
							'Week_Day' record_type,
							transaction_week_day as record_label,
							Row_Number() Over(Partition By customer_id Order By Count(Distinct(transaction_id)) desc, Sum(transaction_amount) desc, Max(transaction_date) desc) as record_rank,
							Count(Distinct(transaction_id)) as total_volume,
							Sum(transaction_amount) as total_spend,
							Max(transaction_date) as total_mtd
						From #base_transactions as trans with(nolock)

						Group By
							customer_id,
							transaction_week_day

						Union All

						Select --(Time group)--
							customer_id,
							'Time_Group' record_type,
							transaction_time_grouping as record_label,
							Row_Number() Over(Partition By customer_id Order By Count(Distinct(transaction_id)) desc, Sum(transaction_amount) desc, Max(transaction_date) desc) as record_rank,
							Count(Distinct(transaction_id)) as total_volume,
							Sum(transaction_amount) as total_spend,
							Max(transaction_date) as total_mtd
						From #base_transactions as trans with(nolock)

						Group By
							customer_id,
							transaction_time_grouping
						) as allparams

				Where
					Case
						When record_type = 'Overall' Then 1
						When record_rank = 1 Then 1
						Else 0
					End = 1

				Order By	
					customer_id,
					record_type,
					record_label,
					record_rank

				Select --(Main Query)--
							Cust_Behav.customer_id,
							Cust_Behav.Overall_Rank,
							Cust_Behav.items_purchased,
							Cust_Behav.total_spend,
							Cust_Behav.fav_productid,
							C_P.product_count as items_for_product,
							Cust_Behav.fav_weekday,
							C_WD.product_count as items_for_weekday,
							Cust_Behav.fav_timegroup,
							C_TG.product_count as items_for_timegroup,
							C_V.monthly_visits as total_visits
				From (
						Select
							Cust_Hab_Pivot.customer_id,
							Cust_Hab_Pivot.Overall_Rank,
							Cust_Hab_Pivot.total_volume as items_purchased,
							Cust_Hab_Pivot.total_spend,
							Cust_Hab_Pivot.[Product] as fav_productid,
							Cust_Hab_Pivot.Week_day as fav_weekday,
							Cust_Hab_Pivot.Time_Group as fav_timegroup
						From (
								Select
									CU_base.customer_id,
									CU_base.record_rank as Overall_Rank,
									CU_base.total_volume,
									CU_base.total_spend,
									CU_aux.record_type,
									CU_aux.record_label
								From #customers_unpivoted as CU_base with(nolock)

									Inner Join #customers_unpivoted as CU_aux with(nolock) on CU_base.customer_id = CU_aux.customer_id and CU_aux.record_type != 'Overall' and CU_aux.record_label != 'Totals'

								Where
									CU_base.record_type = 'Overall'
									and CU_base.record_label = 'Totals'
								) as base

						Pivot (
							Max(base.record_label)
								For base.record_type
									In ([Product],[Week_day],[Time_Group])
								) as Cust_Hab_Pivot

						Where
							Cust_Hab_Pivot.total_volume > 1
						) as Cust_Behav

					Left Join (
								Select
									customer_id,
									product_id,
									Count(Distinct(transaction_id)) as product_count
								From #base_transactions with(nolock)

								Group By
									customer_id,
									product_id
								) as C_P on Cust_Behav.customer_id = C_P.customer_id and Cust_Behav.fav_productid = C_P.product_id
					Left Join (
								Select
									customer_id,
									transaction_week_day as week_day,
									Count(Distinct(transaction_id)) as product_count
								From #base_transactions with(nolock)

								Group By
									customer_id,
									transaction_week_day
								) as C_WD on Cust_Behav.customer_id = C_WD.customer_id and Cust_Behav.fav_weekday = C_WD.week_day
					Left Join (
								Select
									customer_id,
									transaction_time_grouping as time_group,
									Count(Distinct(transaction_id)) as product_count
								From #base_transactions with(nolock)

								Group By
									customer_id,
									transaction_time_grouping
								) as C_TG on Cust_Behav.customer_id = C_TG.customer_id and Cust_Behav.fav_timegroup = C_TG.time_group
					Left Join (
								Select
									customer_id,
									Count(Distinct(Convert(Date,transaction_date))) as monthly_visits
								From #base_transactions with(nolock)

								Group By
									customer_id
								) C_V on Cust_Behav.customer_id = C_V.customer_id

				Order By
					Cust_Behav.Overall_Rank

			End