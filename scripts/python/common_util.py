# type(a)
# vars(a)
# inspect.getmembers(a, inspect.isfunction) 
# https://www.tutorialspoint.com/python/python_lists.htm
# https://www.python-course.eu/lambda.php

import os
import urllib2
import io
import json
from global_static import PyGlobal, BorgConfiguration
import hashlib
from functools import partial
import psutil

def split_url(url, parent=False):
    parts = url.split('://', 1)
    if (len(parts) == 2):
        has_protocol = True
        [before_protocol, after_protocol] = parts
    else:
        has_protocol = False
        after_protocol = parts[0]
    
    idx = after_protocol.rfind('/')
    if (idx == -1):
        return (url, '')[parent]
    else: 
        if (parent):
            after_protocol = after_protocol[0:idx+1]
            return (after_protocol, "%s://%s" % (before_protocol, after_protocol))[has_protocol]
        else:
            return after_protocol[idx+1:]

def get_software_package_path(software_name=None):
    pd = PyGlobal.configuration.get_packagedir()
    if not(software_name):
        software = PyGlobal.configuration.get_os_config()["Softwares"][0]
        if not(software['LocalName']):
            software_name = split_url(software['PackageUrl'])
        else:
            software_name = software['LocalName']
    return os.path.join(pd, software_name)
        
def get_software_packages(target_dir, softwares):
    if (not(os.path.exists(target_dir))):
        os.makedirs(target_dir)
    for software in softwares:
        url = software['PackageUrl']
        ln = software['LocalName']
        if (not(ln)):
            ln = split_url(url, False)
        lf = os.path.join(target_dir, ln)
        if (not(os.path.exists(lf))):
            print "start downloading..."
            downloading_file = urllib2.urlopen(url)
            with open(lf,'wb') as output:
                output.write(downloading_file.read())
    

def get_configration(config_file, encoding="utf-8", server_side=False):
    if (os.path.isfile(config_file) and os.path.exists(config_file)):
        try:
            f = io.open(config_file,mode="r",encoding=encoding)
            s = f.read()
        except UnicodeDecodeError:
            f = io.open(config_file,mode="r",encoding='utf-16')
            s = f.read()
        finally:
            f.close()
        j = json.loads(s)
        os_type = j['OsType']
        os_config = j['SwitchByOs'][os_type]
        softwares = os_config['Softwares']
        if (server_side):
            dl = os_config['ServerSide']['PackageDir']
        else:
            dl = os.path.join(PyGlobal.project_dir, 'downloads', j['AppName'])
        get_software_packages(dl, softwares)
        PyGlobal.configuration = BorgConfiguration(j)
        return j
    else:
        raise ValueError("config file %s doesn't exists." % config_file)

def get_one_filehash(file_to_hash, mode="SHA256"):
    h = hashlib.new(mode)
    o = {}
    with open(file_to_hash, 'rb') as file:
            block = file.read(512)
            while block:
                h.update(block)
                block = file.read(512)
    o['Algorithm'] = mode
    o['Hash'] = str.upper(h.hexdigest())
    o['Path'] = os.path.abspath(file_to_hash)
    o['Length'] = os.path.getsize(file_to_hash)
    return o

def get_filehashes(dir_to_hash, mode="SHA256"):
    l = []
    for dirName, subdirList, fileList in os.walk(dir_to_hash, topdown=False):
        pf = partial(os.path.join, dirName)
        pf1 = partial(get_one_filehash, mode=mode)
        result =  map(pf, fileList)
        l.extend(map(pf1, result))
    return l

def send_lines_to_client(content):
    print PyGlobal.line_start
    print content
    print PyGlobal.line_end

#    "Used":  0,
#    "Free":  256335872,
#    "Percent":  "0.0%",
#    "Freem":  "244.5",
#    "Name":  "/dev/shm",
#    "Usedm":  "0.0"
def get_diskfree():
    mps = filter(lambda dv: dv.fstype, psutil.disk_partitions())
    mps = map(lambda dv: dv.mountpoint, mps)
    def format_result(name):
        du = psutil.disk_usage(name)
        used = du.used
        free = du.total - used
        percent = str(du.percent) + '%'
        freem = str(free / 1024)
        usedm = str(used / 1024)
        return {"Name": name, "Used": used, "Percent": percent, "Free": free, "Freem": freem, "Usedm": usedm}
    return map(format_result, mps)

# total=8268038144L, available=1243422720L, percent=85.0, used=7024615424L, free=1243422720L
def get_memoryfree():
    r = psutil.virtual_memory()
    percent = str(r.percent) + '%'
    freem = str(r.free / 1024)
    usedm = str(r.used / 1024)
    return [{"Name": '', "Used": r.used, "Percent": percent, "Free": r.free, "Freem": freem, "Usedm": usedm, "Total": r.total}]

    
