from src.lib.json_csv import json_to_csv, csv_to_json
from src.lab05.cvs_xlsx import csv_to_xlsx

# json_to_csv(
#     json_path="data/samples/people.json",
#     csv_path="data/out/people.csv",
# )

# csv_to_json(
#     csv_path="data/samples/cities.csv",
#     json_path="data/out/cities.json",
# )

# csv_to_json(
#     csv_path="data/samples/people.csv",
#     json_path="data/out/people_2.json",
# )

csv_to_xlsx(
    csv_path="data/samples/cities.csv",
    xlsx_path="data/out/cities.xlsx",
)
