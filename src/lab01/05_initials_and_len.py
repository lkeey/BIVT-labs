fio = input("ФИО: ")
print(f"Инициалы: {''.join([i[0].upper() for i in fio.split()])}.")
print(f"Длина: {len(fio.strip())}")
