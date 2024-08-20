Create Procedure
	[dbo].[usp_coffee_shop_sales_forecast]
		As
			Begin

				If Object_ID('tempdb..#DateSetup_temp') Is Not Null Drop Table #DateSetup_temp_staging
				If Object_ID('tempdb..#DateSetup_temp') Is Not Null Drop Table #DateSetup_temp
				If Object_ID('tempdb..#ProductVolumeTemp') Is Not Null Drop Table #ProductVolumeTemp
				if Object_ID('tempdb..#BaseTransactions') Is Not Null Drop Table #BaseTransactions
				if Object_ID('tempdb..#sub_trans_temp') Is Not Null Drop Table #sub_trans_temp
				if Object_ID('tempdb..#EnumeratedTransactions') Is Not Null Drop Table #EnumeratedTransactions
				If Object_ID('tempdb..#DateTemp') Is Not Null Drop Table #DateTemp

				------------------------------------------------------------------
				-- Enumerate transactions by group and Transaction for forecast --
				------------------------------------------------------------------
				Select --(#DateSetup_temp_staging)--
					LKD.year_no,
					LKD.month_no,
					LKD.last_real_date,
					LKD.last_known_day,
					Case
						When LKD.last_real_date = LKD.last_known_day Or DateAdd(Day,-1,LKD.last_real_date) = LKD.last_known_day Or DateAdd(Day,-2,LKD.last_real_date) = LKD.last_known_day Then 1
						Else 0
					End as is_month_complete
				Into #DateSetup_temp_staging
				From (
						Select
						Distinct
							Year(transaction_date) as year_no,
							Month(transaction_date) as month_no,
							EOMonth(Convert(Date,Concat(Year(transaction_date),'-',Month(transaction_date),'-01'))) as last_real_date,
							Max(Convert(Date,transaction_date)) as last_known_day
						From fact_coffee_shop_transactions

						Group By
							Year(transaction_date),
							Month(transaction_date),
							EOMonth(Convert(Date,Concat(Year(transaction_date),'-',Month(transaction_date),'-01')))
						) as LKD

				Select --(#DateSetup_temp)--
					DST.year_no,
					DST.month_no,
					DST.is_month_complete,
					Case
						When LCM.M_LKD Is Not Null Then 1
						Else 0
					End as last_full_month
				Into #DateSetup_temp
				From #DateSetup_temp_staging as DST with(nolock)

					Left Join (
								Select
									Max(last_known_day) as M_LKD
								From #DateSetup_temp_staging as DST with(nolock)

								Where
									is_month_complete = 1
								) as LCM on DST.last_known_day = LCM.M_LKD

				Select --(#ProductVolumeTemp)--
					Base.product_id,
					Base.transaction_week_of_month,
					Base.transaction_week_day,
					Base.transaction_time_grouping,
					Sum(Base.transaction_count) as transaction_count
				Into #ProductVolumeTemp
				From (
						Select
							Base.product_id,
							Base.transaction_week_of_month,
							Base.transaction_week_day,
							Base.transaction_time_grouping,
							Case
								When Base.[type] = 'A' Then (Base.transaction_count * 0.60)
								When Base.[type] = 'B' Then (Base.transaction_count * 0.40)
								Else 0
							End as transaction_count
						From (
								Select --(Last Full Month)--
									'A' as [type],
									product_id,
									(DateDiff(ww,DateDiff(d,0,DateAdd(m,DateDiff(m,7,transaction_date),0))/7*7,DateAdd(d,-1,transaction_date))+1) as transaction_week_of_month,
									transaction_week_day,
									transaction_time_grouping,
									Count(transaction_id) as transaction_count
								From fact_coffee_shop_transactions

								Where
									Year(transaction_date) In (
																Select
																Distinct
																	year_no
																From #DateSetup_temp
								
																Where
																	is_month_complete = 1
																	and last_full_month = 1)
									And Month(transaction_date) In (
																	Select
																	Distinct
																		month_no
																	From #DateSetup_temp
									
																	Where
																		is_month_complete = 1
																		and last_full_month = 1)

								Group By
									product_id,
									(DateDiff(ww,DateDiff(d,0,DateAdd(m,DateDiff(m,7,transaction_date),0))/7*7,DateAdd(d,-1,transaction_date))+1),
									transaction_week_day,
									transaction_time_grouping

								Union All

								Select --(Last Full Month)--
									'B' as [type],
									product_id,
									(DateDiff(ww,DateDiff(d,0,DateAdd(m,DateDiff(m,7,transaction_date),0))/7*7,DateAdd(d,-1,transaction_date))+1) as transaction_week_of_month,
									transaction_week_day,
									transaction_time_grouping,
									Count(transaction_id) as transaction_count
								From fact_coffee_shop_transactions

								Where
									Year(transaction_date) In (
																Select
																Distinct
																	year_no
																From #DateSetup_temp
								
																Where
																	is_month_complete = 1
																	and last_full_month = 0)
									And Month(transaction_date) In (
																	Select
																	Distinct
																		month_no
																	From #DateSetup_temp
									
																	Where
																		is_month_complete = 1
																		and last_full_month = 0)

								Group By
									product_id,
									(DateDiff(ww,DateDiff(d,0,DateAdd(m,DateDiff(m,7,transaction_date),0))/7*7,DateAdd(d,-1,transaction_date))+1),
									transaction_week_day,
									transaction_time_grouping
								) as Base
						) as Base

				Group By
					Base.product_id,
					Base.transaction_week_of_month,
					Base.transaction_week_day,
					Base.transaction_time_grouping

				Select --(#BaseTransactions)--
					Row_Number() Over(Order By product_id, transaction_week_of_month, transaction_week_day, transaction_time_grouping) as transaction_id,
					product_id,
					transaction_week_of_month,
					transaction_week_day,
					transaction_time_grouping,
					transaction_count,
					transaction_avg_amount
				Into #BaseTransactions
				From (
						Select
							PVT.product_id,
							PVT.transaction_week_of_month,
							PVT.transaction_week_day,
							PVT.transaction_time_grouping,
							PVT.transaction_count,
							PP.AvgPrice as transaction_avg_amount
						From #ProductVolumeTemp as PVT with(nolock)

							Inner Join (
										Select
											product_id,
											Count(transaction_id) as ProdCount,
											Sum(transaction_amount) as TransAmount,
											Round(((Sum(transaction_amount)) / (Count(transaction_id))),2) as AvgPrice
										From fact_coffee_shop_transactions as T

										Group By
											product_id
										) as PP on PVT.product_id = PP.product_id
						) as Trans

				Where
					Round(transaction_count,0) > 0

				Create Table --(#EnumeratedTransactions)--
					#EnumeratedTransactions (
						[transaction_id] Int,
						[transaction_count] Int,
						[sub_transaction_id] Int,
						[transaction_amount] Decimal(19,6))

				Declare @min_trans_id as Int
				Declare @max_trans_id as Int
				Declare @current_trans_id as Int

				Set @min_trans_id = (Select Min(transaction_id) From #BaseTransactions with(nolock))
				Set @max_trans_id = (Select Max(transaction_id) From #BaseTransactions with(nolock))
				Set @current_trans_id = @min_trans_id

				While --(Enumerate transaction sets per id)--
					@current_trans_id <= @max_trans_id
						Begin

							if Object_ID('tempdb..#sub_trans_temp') Is Not Null Drop Table #sub_trans_temp

							Select --(#sub_trans_temp)--
								transaction_id,
								transaction_count,
								transaction_avg_amount
							Into #sub_trans_temp
							From #BaseTransactions with(nolock)

							Where
								transaction_id = @current_trans_id

							Declare @sub_max_id as Int
							Declare @sub_current_id as Int

							Set @sub_max_id = (Select Max(transaction_count) From #sub_trans_temp with(nolock))
							Set @sub_current_id = 1

							While --(Enumerate transactions sets per sub id)--
								@sub_current_id <= @sub_max_id
									Begin
						
										Insert Into
											#EnumeratedTransactions (
												[transaction_id],
												[transaction_count],
												[sub_transaction_id],
												[transaction_amount])
													Select
														transaction_id,
														transaction_count,
														@sub_current_id as sub_transaction_id,
														transaction_avg_amount as transaction_amount
													From #sub_trans_temp with(nolock)
						
										Print(@sub_current_id)
										Set @sub_current_id = @sub_current_id + 1
									End

							Print(@current_trans_id)
							Set @current_trans_id = @current_trans_id + 1
						End

				------------------------------------------------------------------
				----------- Enumerate transactions dates for forecast ------------
				------------------------------------------------------------------

				Declare @dataset_end_date as Date
				Declare @forecast_current_date as Date
				Declare @forecast_end_date as Date

				Set @dataset_end_date = (Select DateAdd(Day,1,Max(Convert(Date,transaction_date))) From fact_coffee_shop_transactions)
				Set @forecast_current_date = (Select @dataset_end_date)
				Set @forecast_end_date = (Select EOMonth(DateAdd(Month,1,GetDate())))

				Create Table --(#DateTemp)--
					#DateTemp (
						[TransDate] Date)

				While --(Enumerate dates from last date in dataset to current date)--
					@forecast_current_date <= @forecast_end_date
						Begin

						Insert Into
							#DateTemp (
								[TransDate])
									Select
										@forecast_current_date

						Set @forecast_current_date = (Select DateAdd(Day,1,@forecast_current_date))

						End

				------------------------------------------------------------------
				--------------------- Forecast Final Output ----------------------
				------------------------------------------------------------------

				Declare @LastRecID as Int
				Declare @default_time_group as NvarChar(255)
				Declare @default_product_id as NvarChar(255)
				Declare @default_transaction_amount as Decimal(19,6)

				Set @LastRecID = (Select Max(transaction_id) From fact_coffee_shop_transactions)
				Set @default_time_group = (
											Select
											Top 1
												transaction_time_grouping
											From fact_coffee_shop_transactions

											Group By
												transaction_time_grouping

											Order By
												Count(transaction_id) Desc)
				Set @default_product_id = (
											Select
											Top 1
												product_id
											From fact_coffee_shop_transactions

											Where
												transaction_time_grouping =  @default_time_group

											Group By
												product_id

											Order By
												Count(transaction_id) Desc)

				Set @default_transaction_amount = (
													Select
														Avg(transaction_amount)
													From fact_coffee_shop_transactions

													Where
														transaction_time_grouping = @default_time_group
														And product_id = @default_product_id)

				Select --(Main Query)--
					(Row_Number() Over(Order By DT.TransDate, FT.transaction_id, FT.sub_transaction_id) + @LastRecID) as transaction_id,
					DT.TransDate as transaction_date,
					DT.transaction_week_day,
					IsNull(FT.transaction_time_grouping,@default_time_group) as transaction_time_grouping,
					'forecast' as amount_type,
					IsNull(FT.product_id,@default_product_id) as product_id,
					IsNull(FT.transaction_amount,@default_transaction_amount) as transaction_amount
				From (
						Select
							TransDate,
							(DateDiff(ww,DateDiff(d,0,DateAdd(m,DateDiff(m,7,TransDate),0))/7*7,DateAdd(d,-1,TransDate))+1) as transaction_week_of_month,
							DateName(weekday,DatePart(dw,TransDate)) as transaction_week_day
						From #DateTemp as DT with(nolock)) as DT

					Left Join (
								Select
									BT.transaction_id,
									BT.product_id,
									BT.transaction_week_of_month,
									BT.transaction_week_day,
									BT.transaction_time_grouping,
									ET.sub_transaction_id,
									ET.transaction_amount
								From #BaseTransactions as BT with(nolock)

									Inner Join #EnumeratedTransactions as ET with(nolock) on BT.transaction_id = ET.transaction_id
								) as FT on DT.transaction_week_of_month = FT.transaction_week_of_month and DT.transaction_week_day = FT.transaction_week_day

				Order By
					DT.TransDate,
					FT.transaction_week_day,
					FT.transaction_time_grouping,
					FT.product_id

			End

Go