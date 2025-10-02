from src.lab04.io_txt_csv import read_text, write_csv
from src.lib.text import normalize, tokenize, count_freq, top_n


txt = read_text("data/lab04/input.txt")  # должен вернуть строку
data = [i for i in top_n(count_freq(tokenize(normalize(txt))), n=5)]
write_csv(
    header=None,
    rows=[],
    path="data/check.csv",
)  # создаст CSV
