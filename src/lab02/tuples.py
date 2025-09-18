def format_record(rec: tuple[str, str, float]) -> str:
    """
    Formats student record into a readable string.

    Args:
        rec (tuple[str, str, float]): A tuple containing three elements:
            - rec[0]: Full name (surname, name, and optionally patronymic),
                      given as a single string with possible extra spaces.
            - rec[1]: Group identifier (string).
            - rec[2]: GPA (float or convertible to float).

    Returns:
        str: A formatted string in the form:
             "Surname Name.P. , гр. Group, GPA X.XX"

             Examples:
             - ("иванов иван иванович", "ABB-01", 4.55)
               → "Ivanov I.I., гр. ABB-01, GPA 4.55"
             - ("сидорова анна", "CS-22", 3.9)
               → "Sidorova A., гр. CS-22, GPA 3.90"

    Raises:
        ValueError: If full name or group is missing/invalid,
                    or GPA cannot be converted to float.

    Notes:
        - Supports names with 1, 2, or 3 parts (surname, surname+name, surname+name+patronymic).
        - Excess spaces in the name and group fields are ignored.
    """

    name_data = rec[0].strip().split()

    if len(name_data) > 2:
        surname, name, patronymic = rec[0].strip().split()
        name_string_data = f"{surname[0].upper()}{surname[1:]} {name[0].upper()}.{patronymic[0].upper()}."
    elif len(name_data) == 2:
        surname, name = rec[0].strip().split()
        name_string_data = f"{surname[0].upper()}{surname[1:]} {name[0].upper()}."
    elif len(name_data) == 1:
        surname = rec[0].strip().split()
        name_string_data = f"{surname[0].upper()}{surname[1:]}"
    else:
        return ValueError

    group = rec[1].strip()
    if group == "":
        return ValueError

    try:
        gpa = float(rec[2])
    except Exception as _:
        return ValueError

    return f"{name_string_data}, гр. {group}, GPA {gpa:.2f}"


print(format_record(("  сидорова  анна   сергеевна ", "ABB-01", 3.5689)))
