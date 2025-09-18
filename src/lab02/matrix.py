def transpose(mat: list[list[float | int]]) -> list[list]:
    if len(mat) == 0:
        return []

    if any(len(mat[0]) != len(mat[i]) for i in range(len(mat))):
        return ValueError

    new_matrix = [[0 for j in range(len(mat))] for i in range(len(mat[0]))]

    for i in range(len(mat)):
        for j in range(len(mat[i])):
            new_matrix[j][i] = mat[i][j]

    return new_matrix


def row_sums(mat: list[list[float | int]]) -> list[float]:
    if any(len(mat[0]) != len(mat[i]) for i in range(len(mat))):
        return ValueError

    array = list()
    for arr in mat:
        array.append(sum(arr))
    return array


print(row_sums([[1, 2, 3], [4, 5, 6]]))
