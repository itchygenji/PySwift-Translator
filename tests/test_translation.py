from pyswift import translate_source


def test_print_function_loop_translation():
    source = '''\ndef square(x):\n    return x * x\n\nvalues = [1, 2, 3]\nfor x in values:\n    print(x, square(x))\n'''
    result = translate_source(source)
    assert result.ok
    assert "func square" in result.swift
    assert "for __pyTmp" in result.swift
    assert "pyPrint" in result.swift


def test_keywords_are_normalized_for_known_functions():
    source = '''\ndef greet(name, punctuation="!"):\n    return name + punctuation\n\nprint(greet(punctuation="?", name="Swift"))\n'''
    result = translate_source(source)
    assert result.ok
    assert 'greet(.string("Swift"), .string("?"))' in result.swift


def test_unsupported_try_reports_error():
    source = '''\ntry:\n    print("x")\nexcept Exception:\n    print("bad")\n'''
    result = translate_source(source)
    assert not result.ok
    assert any("try/except" in d.message for d in result.diagnostics)


def test_multiprocessing_maps_to_real_process_runtime():
    source = '''\nimport multiprocessing as mp\n\ndef worker(x):\n    return x * x\n\nif __name__ == "__main__":\n    p = mp.Process(target=worker, args=(3,))\n    p.start()\n    p.join()\n'''
    result = translate_source(source)
    assert result.ok
    assert 'PyProcess(target: "worker"' in result.swift
    assert 'case "worker":' in result.swift
