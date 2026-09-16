# 440_007 shape: `use` re-issues the obligation (net nonzero — NOT a discharger),
# `shut` releases it. Koru's checker reads the signatures and knows the difference.
# Mojo: both are just `deinit self` methods — the checker is blind to which
# actually releases.

struct Chan(Deinitable where False, Movable):
    var handle: Int
    def __init__(out self, handle: Int):
        self.handle = handle

    # the REAL discharger — releases the channel
    def shut(deinit self):
        print("SHUT")

    # the re-issuer: Koru spelling is use { c: *Chan<!open> } -> *Chan<open!>
    # — obligation survives the consume. Mojo version returns a fresh linear
    # Chan, so the debt follows the result: still safe.
    def use(deinit self) -> Chan:
        print("USE")
        return Chan(self.handle)

    # ...but nothing stops the AUTHOR-SHAPE bug: a "use" that consumes and
    # reissues only in name — returns Void, obligation evaporates, checker
    # blesses it as a discharge. In Koru the return type <open!> makes the
    # accounting visible; here there is no count.
    def use_lying(deinit self):
        print("USED (but channel still open on the far side)")


def open() -> Chan:
    return Chan(7)

def main():
    var c = open()
    c^.use_lying()      # compiles — treated as a legal death
    # semantic obligation (channel open on the far side) leaks silently
