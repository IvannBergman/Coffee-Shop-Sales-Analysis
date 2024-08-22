Create Function
	[dbo].[fn_coffee_shop_sales_growthkpi] (@forecastTemp [dbo].[type_forecast_resultset] READONLY)
		Returns @growth_kpi Table (
			[transaction_date] Date,
			[transaction_year] Int,
			[transaction_month] Int,
			[products_sold_current] Int,
			[products_sold_previous] Int)

		As
			Begin

				Declare @DateTable as Table (
											[transaction_date] Date,
											[transaction_year] Int,
											[transaction_month] Int)

				Insert Into --(@DateTable)--
					@DateTable
						Select --(DateTable)--
							Trans.transaction_date,
							Year(Trans.transaction_date) as transaction_year,
							Month(Trans.transaction_date) as transaction_month
						From (
								Select
								Distinct
									DateAdd(Month,-1,DateAdd(Day,1,EOMonth(IsNull(Trans.transaction_date,FT.transaction_date)))) as transaction_date
								From fact_coffee_shop_transactions as Trans

									Full Outer Join @ForecastTemp as FT on Convert(Date,Trans.transaction_date) > FT.transaction_date
							) as Trans

				Declare @Base_transactions as Table (
													[transaction_year] Int,
													[transaction_month] Int,
													[products_sold] Decimal(19,6))

				Insert Into --(@Base_transactions)--
					@Base_transactions
						Select --(Base_transactions)--
							Year(Trans.transaction_date) as transaction_year,
							Month(Trans.transaction_date) as transaction_month,
							Count(Trans.transaction_date) as products_sold
						From (
								Select
									IsNull(Trans.transaction_id,FT.transaction_id) as transaction_id,
									IsNull(Trans.transaction_date,FT.transaction_date) as transaction_date
								From fact_coffee_shop_transactions as Trans

									Full Outer Join @ForecastTemp as FT on Convert(Date,Trans.transaction_date) > FT.transaction_date
							) as Trans

						Group By
							Year(Trans.transaction_date),
							Month(Trans.transaction_date)

				Declare @Min_month as Int
				Set @Min_month = (Select Min(transaction_month) From @Base_transactions)

				Insert Into --(@growth_kpi)--
					@growth_kpi
						Select --(growth_kpi)--
							DT.transaction_date,
							DT.transaction_year,
							DT.transaction_month,
							Current_Trans.products_sold as products_sold_current,
							IsNull(Previous_Trans.products_sold,0) as products_sold_previous
						From (
								Select
									base.transaction_year as trans_year_real,
									Case
										When base.transaction_month = 1 then (base.transaction_year - 1)
										Else base.transaction_year
									End as transaction_year,
									Case
										When base.transaction_month = 1 then 12
										Else (base.transaction_month - 1)
									End as transaction_month,
									transaction_month as trans_month_real,
									products_sold
								From @Base_transactions as base
								) as Current_Trans

							Left Join @Base_transactions as Previous_Trans on
								Current_Trans.transaction_year = Previous_Trans.transaction_year
								and Current_Trans.transaction_month = Previous_Trans.transaction_month
							Left Join @DateTable as DT on
								Current_Trans.trans_year_real = DT.transaction_year
								and Current_Trans.trans_month_real = DT.transaction_month

						Order By
							DT.transaction_year,
							DT.transaction_month,
							DT.transaction_date

			Return

			End