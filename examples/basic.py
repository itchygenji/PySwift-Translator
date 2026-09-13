import math

def square(x):
    return x * x

name = "Swift"
nums = [1, 2, 3, 4]
print(f"Hello {name}")
print("sqrt:", math.sqrt(16))
for n in nums:
    print(n, square(n))
