from pyswift import translate_source


def messages(source: str) -> list[str]:
    return [d.message for d in translate_source(source).diagnostics]


def test_too_many_function_arguments_are_rejected():
    result = translate_source("def f(a):\n    return a\n\nf(1, 2)\n")
    assert not result.ok
    assert any("Too many positional arguments" in d.message for d in result.diagnostics)


def test_unknown_function_keyword_is_rejected():
    result = translate_source("def f(a):\n    return a\n\nf(b=1)\n")
    assert not result.ok
    assert any("Unexpected keyword argument 'b'" in d.message for d in result.diagnostics)


def test_duplicate_argument_is_rejected():
    result = translate_source("def f(a):\n    return a\n\nf(1, a=2)\n")
    assert not result.ok
    assert any("Multiple values for argument 'a'" in d.message for d in result.diagnostics)


def test_assert_is_not_silently_dropped():
    result = translate_source("assert 1 == 1\n")
    assert not result.ok
    assert any("assert" in d.message for d in result.diagnostics)
    assert "TODO(PySwift): untranslated assert" in result.swift


def test_nonlocal_is_explicitly_rejected():
    source = """
def outer():
    x = 1
    def inner():
        nonlocal x
        x = 2
    return x
"""
    result = translate_source(source)
    assert not result.ok
    assert any("nonlocal" in d.message for d in result.diagnostics)


def test_unknown_method_keywords_are_not_discarded():
    source = """
class A:
    pass

a = A()
a.unknown(value=1)
"""
    result = translate_source(source)
    assert not result.ok
    assert any("unknown method" in d.message for d in result.diagnostics)


def test_constructor_and_method_keywords_are_reordered():
    source = """
class Greeter:
    def __init__(self, name="world", punctuation="!"):
        self.name = name
        self.punctuation = punctuation

    def greet(self, prefix="Hello"):
        return prefix + self.name + self.punctuation

g = Greeter(punctuation="?", name="Swift")
print(g.greet(prefix="Hi"))
"""
    result = translate_source(source)
    assert result.ok
    assert 'Greeter(.string("Swift"), .string("?"))' in result.swift
    assert 'g!.greet(.string("Hi"))' in result.swift
