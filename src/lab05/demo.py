from src.lib.json_csv import json_to_csv, csv_to_json

json_to_csv(
    json_path="data/samples/people.json",
    csv_path="data/out/people.csv",
)

csv_to_json(
    csv_path="data/samples/cities.csv",
    json_path="data/out/cities.json",
)

csv_to_json(
    csv_path="data/samples/people.csv",
    json_path="data/out/people_2.json",
)
