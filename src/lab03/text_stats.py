import sys
from src.lib.text import normalize, tokenize, count_freq, top_n

"""
text_stats.py — скрипт для анализа текста.

Функции:
    - Считает общее количество слов
    - Считает количество уникальных слов
    - Находит топ-5 наиболее частых слов

Токенизация и нормализация текста выполняются с помощью функций из src.lib.text:
    - normalize() — нормализует текст (нижний регистр, убирает лишние пробелы и заменяет 'ё' на 'е')
    - tokenize() — разбивает текст на слова/числа
    - count_freq() — считает частоты слов
    - top_n() — возвращает топ-N наиболее частых слов

Запуск:
    Из корня проекта:
        python3 -m src.lab03.text_stats < src/lab03/input.txt

Переменные:
    IS_TABLE — если True, выводится красивая таблица; иначе простая печать токен:частота
"""

IS_TABLE = True

text = sys.stdin.read()

text = normalize(text=text)

tokens = tokenize(text=text)

top = top_n(count_freq(tokens=tokens), n=5)

print(f"Всего слов: {len(tokens)}")
print(f"Уникальных слов: {len(set(tokens))}")
print("Топ-5:")

if IS_TABLE:
    max_word_length = max([len(i[0]) for i in top]) + 1

    print(f"cлово{(max_word_length - 5) * ' '}| частота")
    print("-" * (max_word_length + 2 + max_word_length))
    for i in top:
        word, count = i
        print(f"{word}{(max_word_length - len(word)) * ' '}| {count}")
else:
    for i in top:
        print(f"{i[0]}:{i[1]}")
