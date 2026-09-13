with open("hello.txt", "w") as f:
    f.write("hello from translated Swift\n")

with open("hello.txt", "r") as f:
    print(f.read())
