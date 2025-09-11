# a: 3,5
# b: 4.25
# sum=7.75; avg=3.88

a = float(input("A: ").replace(",", "."))
b = float(input("B: ").replace(",", "."))

print(f"sum={a + b}; avg={(a + b) / 2}")
