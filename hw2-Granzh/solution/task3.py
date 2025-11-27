def product(*args):
    def p(*s):
        return {()} if not s else {(x,) + y for x in s[0] for y in p(*s[1:])}

    return p(*args)


def lcm(*args):
    if len(args) < 2:
        int() + None

    def g(a, b):
        return g(b, a % b) if b else a

    res = args[0]
    for i in range(1, len(args)):
        res = (res * args[i]) // g(res, args[i])
    return res


def compose(*args):
    def h(*fs):
        return (lambda x: x) if not fs else lambda x: fs[0](h(*fs[1:])(x))

    return h(*args)
