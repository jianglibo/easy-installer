import unittest
import common_util
from global_static import PyGlobal
import tempfile
import os, sys, locale, re
import shutil, functools
import subprocess
import pytest
from collections import namedtuple
from typing import NamedTuple, Pattern

def test_var_args():
    def f(*args):
        return args
    r = f(1,2,3)
    assert isinstance(r, tuple)
    assert functools.reduce(lambda x,y: x+y, r) == 6

def test_kw_var_args():
    def f(**kwargs):
        return kwargs
    r = f(a=1,b=2,c=3)
    assert isinstance(r, dict)
    assert r['a'] == 1

def test_call():
    with pytest.raises(subprocess.CalledProcessError) as ae:
        _ = subprocess.check_output(['ls', '/404'], stderr=subprocess.STDOUT, shell=True)
    e: subprocess.CalledProcessError = ae.value
    assert isinstance(e.output, bytes)
    assert sys.getdefaultencoding() == 'utf-8'
    assert "'ls'" in e.output.decode(locale.getdefaultlocale()[1])

    try:
        subprocess.check_output(['ls', '/404'], shell=True)
    except subprocess.CalledProcessError as cpe:
        assert not cpe.output # doesn't redirect output.
        assert cpe.returncode == 1

def test_checkout_stderr():
    v = common_util.subprocess_checkout_print_error(['ls', '/404'], shell=True)
    assert v

def test_nt():
    Di = namedtuple('Di', ['x', 'y'])
    di = Di(1, 2)
    assert di.x == 1
    assert di.y == 2
    with pytest.raises(AttributeError) as ae:
        di.x = 10
    e: AttributeError = ae.value
    assert "can't set attribute" in str(e)

    assert di.count(1) == 1
    assert di._fields == ('x', 'y')
    dd = di._asdict()
    dd['y'] = 20
    di1 = Di(**dd)
    assert di1.y == 20

def test_namedtuple_inheritance():
    class Dic(NamedTuple):
        a: int
        b: str
    dic = Dic(1, 's')
    assert dic.a == 1
    assert dic.b == 's'
    assert type(dic) == Dic
    assert not isinstance(dic, NamedTuple)
    assert isinstance(dic, tuple)

def test_ptn():
    r: Pattern = re.compile('ab\\.*')
    assert r.match('abcd') # match at begin
    assert r.match('ab.............')
    assert r.match('ab')

    r = re.compile('ab\\\\.*')
    assert r.match('ab\\cd') # match at begin 1
    assert r.match('ab\\\\\\\\')


def test_ptn_1():
    string_with_newlines = """something
someotherthing"""

    assert re.match('some', string_with_newlines) # matches
    assert not re.match('someother', 
                string_with_newlines) # won't match
    assert not re.match('^someother', string_with_newlines, 
                re.MULTILINE) # also won't match
    assert re.search('someother', 
                    string_with_newlines) # finds something
    assert re.search('^someother', string_with_newlines, 
                    re.MULTILINE) # also finds something

    m = re.compile('thing$', re.MULTILINE)

    assert not m.match(string_with_newlines) # no match
    assert m.match(string_with_newlines, pos=4) # matches
    assert m.search(string_with_newlines, 
                re.MULTILINE) # also matches
    
    