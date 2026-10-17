# 1.1 Class + __init__ + self
class Medicine:
    def __init__(self, name, price, stock):
        self.name = name
        self.price = price
        self.stock = stock
    def low_stock_status(self):
            if self.stock <= 10:
                return f"{self.name}'s stock is low."
            else:
                return f"{self.stock} units available."
        
        
    def __str__(self):
        return f"{self.name}'s per unit price {self.price} and {self.low_stock_status()}"
napa = Medicine("Napa","2Tk",10)
print(napa)
fexo = Medicine("Fexo 120","20Tk",100)
print(fexo)
