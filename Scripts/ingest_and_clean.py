import pandas as pd
import datetime as dt
import sqlalchemy
from sqlalchemy.engine import URL

# SQL Server Stuff:

server = 'IVAN_LAPTOP\LOCALSQLSERVER'
database = 'Projects_DW'
username = 'ExternalApps'
password = 'Ext_PW_01'
connection_string = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password}'
connection_url = URL.create("mssql+pyodbc",query={"odbc_connect": connection_string})
cnxn = sqlalchemy.create_engine(connection_url)

# Read raw data from .csv file and insert to dataframe

raw_file_location = "Raw Files\index.csv"

rawdf = pd.read_csv(
                    raw_file_location,
                    header="infer")

# Clean & Sort data

cleandf = rawdf[rawdf['money'] > 0.0]

cleandf = cleandf.drop_duplicates()

cleandf.fillna({'card':'cash'},inplace=True)

cleandf['date'] = pd.to_datetime(cleandf['date'])

cleandf['datetime'] = pd.to_datetime(cleandf['datetime'])

cleandf = cleandf.rename(columns={'datetime':'transaction_date',
                                  'cash_type':'transaction_type',
                                  'card':'card_id',
                                  'money':'transaction_amount',
                                  'coffee_name':'product_name'})

cleandf.sort_values(by=['date','transaction_date','card_id'])

cleandf.reset_index()

cleandf.insert(0,'record_id',cleandf.index + 1)

cleandf.insert(1,'ingest_date',dt.datetime.now())

# Push to SQL Server

sql_data_types = {
    "record_id": sqlalchemy.types.Integer(),
    "date": sqlalchemy.types.Date(),
    "transaction_date": sqlalchemy.types.DateTime(),
    "transaction_type": sqlalchemy.types.String(length=15),
    "card_id": sqlalchemy.types.String(length=50),
    "transaction_amount": sqlalchemy.types.Float(),
    "product_name": sqlalchemy.types.String(length=50),
    "ingest_date": sqlalchemy.types.DateTime()
                }

print(cleandf.info())
print(cleandf)

cleandf.to_sql(name='Coffee_Shop_Sales',
               con=cnxn,
               if_exists='append',
               index=False,
               dtype=sql_data_types)