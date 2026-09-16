# If a linear type is also Copyable, does the copy mint a second tracked
# obligation — or launder one free death?

@explicit_destroy("must die via .kill()")
struct Token(Deinitable where False, Copyable):
    var id: Int
    def __init__(out self, id: Int):
        self.id = id
    def __init__(out self, *, copy: Self):
        self.id = copy.id
    def kill(deinit self):
        print("killed", self.id)

def main():
    var a = Token(1)
    var b = a.copy()    # explicit copy — does the duplicate carry its own debt?
    a^.kill()
    # b still alive and linear — if the checker tracks copies, this errors
