class Counter:
    def __init__(self, start=0):
        self.value = start

    def add(self, amount=1):
        self.value = self.value + amount
        return self.value

c = Counter(10)
print(c.add())
print(c.add(5))
