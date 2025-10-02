from src.lab04.io_txt_csv import read_text, write_csv
from src.lib.text import normalize, tokenize, count_freq, top_n
import argparse

parser = argparse.ArgumentParser(description="Анализ текста и сохранение отчёта в CSV")
parser.add_argument(
    "--in",
    dest="inputs",
    nargs="+",  # поддержка нескольких файлов
    required=True,
    help="Входные текстовые файлы",
)
parser.add_argument("--out", dest="output", required=True, help="Путь к выходному CSV")
args = parser.parse_args()


texts = []
for path in args.inputs:
    txt = read_text(path)
    texts.append(tokenize(normalize(txt)))
all_text = "\n".join(texts)

freq = frequencies_from_text(all_text)
sorted_freq = sorted_word_counts(freq)


txt = read_text("data/lab04/input.txt")  # должен вернуть строку
data = [i for i in top_n(count_freq(tokenize(normalize(txt))), n=5)]


write_csv(
    header=None,
    rows=[],
    path="data/check.csv",
)  # создаст CSV
