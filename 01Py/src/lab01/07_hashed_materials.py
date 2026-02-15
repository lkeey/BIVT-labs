hashed_str = input("Зашифрованная строка: ")
correct_letter = [""]
first_index = -1

for i in range(len(hashed_str)):
    if hashed_str[i] in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" and len(correct_letter[0]) == 0:
        correct_letter[0] = hashed_str[i]
        first_index = i
    elif (
        hashed_str[i] in "0123456789" and len(correct_letter) == 1 and first_index != -1
    ):
        step = i + 1 - first_index
        for j in range(i + 1, len(hashed_str), step):
            correct_letter.append(hashed_str[j])
        break
print("".join(correct_letter) + ".")
