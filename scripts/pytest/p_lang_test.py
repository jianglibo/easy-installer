import unittest
import common_util
from global_static import PyGlobal
import tempfile
import os, sys, locale
import shutil, functools
import subprocess
import pytest
from collections import namedtuple

def test_varargs():
    def f(*args):
        return args
    r = f(1,2,3)
    assert isinstance(r, tuple)
    assert functools.reduce(lambda x,y: x+y, r) == 6

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
