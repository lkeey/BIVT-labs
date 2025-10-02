import sys
from src.lib.text import normalize, tokenize
from src.lib.table import print_summary

"""
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

text = normalize(text=sys.stdin.read())

tokens = tokenize(text=text)

print_summary(tokens=tokens, is_table=IS_TABLE)
