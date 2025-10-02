from src.lib.text import count_freq, top_n


def table(title: str, description: str, top: list[tuple[str, int]]) -> None:
    max_word_length = max([len(i[0]) for i in top]) + 1

    print(f"{title}{(max_word_length - 5) * ' '}| {description}")
    print("-" * (max_word_length + 2 + max_word_length))
    for i in top:
        word, count = i
        print(f"{word}{(max_word_length - len(word)) * ' '}| {count}")


def print_summary(tokens: list[str], is_table: bool, n: int = 5) -> None:
    """Печатает статистику по токенам: всего, уникальные, топ-5."""

    top = top_n(count_freq(tokens), n=n)
    print(f"Всего слов: {len(tokens)}")
    print(f"Уникальных слов: {len(set(tokens))}")

    print("Топ-5:")

    if is_table:
        table(title="cлово", description="частота", top=top)
    else:
        for w, c in top:
            print(f"{w}:{c}")
