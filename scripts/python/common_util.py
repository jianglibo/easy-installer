# type(a)
# vars(a)
# inspect.getmembers(a, inspect.isfunction) 
# https://www.tutorialspoint.com/python/python_lists.htm
# https://www.python-course.eu/lambda.php

import os, urllib2, io, json, codecs
from global_static import PyGlobal, BorgConfiguration
import hashlib
from functools import partial
import psutil, re, shutil, base64, tempfile, subprocess

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
    
def get_filecontent_str(config_file, encoding="utf-8"):
    with io.open(config_file, 'rb') as opened_file:
        if opened_file.read(3) == codecs.BOM_UTF8:
            encoding = 'utf-8-sig'
    try:
        f = io.open(config_file,mode="r",encoding=encoding)
        return f.read()
    except UnicodeDecodeError:
        f = io.open(config_file,mode="r",encoding='utf-16')
        return f.read()
    finally:
        f.close()

def get_filecontent_lines(config_file, encoding="utf-8"):
    with io.open(config_file, 'rb') as opened_file:
        if opened_file.read(3) == codecs.BOM_UTF8:
            encoding = 'utf-8-sig'
    try:
        f = io.open(config_file,mode="r",encoding=encoding)
        return f.readlines()
    except UnicodeDecodeError:
        f = io.open(config_file,mode="r",encoding='utf-16')
        return f.readlines()
    finally:
        f.close()

def get_configration(config_file, encoding="utf-8", server_side=False):
    if (os.path.isfile(config_file) and os.path.exists(config_file)):
        content = get_filecontent_str(config_file, encoding=encoding)
        j = json.loads(content)
        os_type = j['OsType']
        os_config = j['SwitchByOs'][os_type]
        softwares = os_config['Softwares']
        if (server_side):
            dl = os_config['ServerSide']['PackageDir']
        else:
            dl = os.path.join(PyGlobal.project_dir, 'downloads', j['AppName'])
        # get_software_packages(dl, softwares)
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
    for dirName, sub_dirs, fileList in os.walk(dir_to_hash, topdown=False):
        pf = partial(os.path.join, dirName)
        pf1 = partial(get_one_filehash, mode=mode)
        result =  map(pf, fileList)
        l.extend(map(pf1, result))
    return l

def send_lines_to_client(content):
    print PyGlobal.line_start
    if isinstance(content, dict):
        print json.dumps(content)
    else:
        print content
    print PyGlobal.line_end


def get_diskfree():
    """
    "Used":  0,
    "Free":  256335872,
    "Percent":  "0.0%",
    "Freem":  "244.5",
    "Name":  "/dev/shm",
    "Usedm":  "0.0"
    """
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

def get_memoryfree():
    """
        format: total=8268038144L, available=1243422720L, percent=85.0, used=7024615424L, free=1243422720L
    """
    r = psutil.virtual_memory()
    percent = str(r.percent) + '%'
    freem = str(r.free / 1024)
    usedm = str(r.used / 1024)
    return [{"Name": '', "Used": r.used, "Percent": percent, "Free": r.free, "Freem": freem, "Usedm": usedm, "Total": r.total}]

def get_maxbackupnumber(path):
    p_tuple = os.path.split(path)
    if not os.path.exists(p_tuple[0]):
        os.makedirs(p_tuple[0])
    re_str = p_tuple[1] + r'\.(\d+)$'
    def sl(fn):
        m = re.match(re_str, fn)
        return int(m.group(1)) if m else 0
    nums = [sl(x) for x in os.listdir(p_tuple[0])]
    nums.sort()
    nums.reverse()
    return nums[0]

def get_next_backup(path):
    mn = 1 + get_maxbackupnumber(path)
    return "%s.%s" % (path, mn)

def get_maxbackup(path):
    mn = get_maxbackupnumber(path)
    return "%s.%s" % (path, mn) if mn else path

def backup_localdirectory(path, keep_origin=True):
    if not os.path.exists(path):
        raise ValueError("%s doesn't exists." % path)
    m = re.match(r'^(.*?)\.\d+$', path)
    nx = get_next_backup(m.group(1)) if m else get_next_backup(path)
    if os.path.isfile(path):
        if keep_origin:
            shutil.copy(path, nx)
        else:
            shutil.move(path, nx)
    else:
        if keep_origin:
            shutil.copytree(path, nx)
        else:
            shutil.move(path, nx)
    return nx

def get_file_frombase64(base64_str, out_file=None):
    decoded_str = base64.b64decode(base64_str)
    if out_file is None:
        out_file = tempfile.mktemp()
    with io.open(out_file, 'wb') as opened_file:
        opened_file.write(decoded_str)
    return out_file

def unprotect_password_by_openssl_publickey(base64_str, private_key=None, openssl=None):
    in_file = get_file_frombase64(base64_str)
    out_file = tempfile.mktemp()
    if openssl is None:
        openssl = PyGlobal.configuration.json['openssl']
    if private_key is None:
        private_key = PyGlobal.configuration.json['ServerPrivateKeyFile']
    subprocess.call([openssl, 'pkeyutl', '-decrypt', '-inkey', private_key, '-in', in_file, '-out', out_file])
    with io.open(out_file, 'rb') as opened_file:
        return opened_file.read()

def get_lines(path_or_lines):
    if isinstance(path_or_lines, str):
        with io.open(path_or_lines, 'r') as opened_file:
            lines = [line.strip() for line in opened_file.readlines()]
    else:
        lines = [line.strip() for line in path_or_lines]
    return lines

def get_block_config_value(path_or_lines, block_name, key):
    lines = get_lines(path_or_lines)
    block_found = False
    for line in lines:
        if block_found:
            m = re.match(r'^\s*(\[.*\])\s*$', line)
            if m: # block had found, but found another block again. so value is None
                return None
            else:
                m = re.match(r'^\s*%s=(.+)$' % key, line)
                if m:
                    return m.group(1)
        else:
            if line == block_name:
                block_found = True

def update_block_config_file(path_or_lines, key, value=None, block_name="mysqld"):
    lines = get_lines(path_or_lines)
    if block_name[0] != '[':
        block_name = "[%s]" % block_name

    block_idx = -1
    next_block_idx = -1
    for idx, line in enumerate(lines):
        if block_idx != -1:
            m = re.match(r'^\s*(\[.*\])\s*$', line)
            if m:
                next_block_idx = idx
                break
        else:
            if line == block_name:
                block_idx = idx
    block_before = []
    block_found = []
    block_after = []

    if block_idx == -1:
        block_after = lines[:]
    else:
        block_before = lines[:block_idx]
        if next_block_idx == -1:
            block_found = lines[block_idx:]
        else:
            block_found = lines[block_idx: next_block_idx]
            block_after = lines[:next_block_idx]
    block_found_len = len(block_found)
    if block_found_len == 0:
        block_found.append(block_name)
        block_found.append("%s=%s" % (key, value))
    elif block_found_len == 1:
        block_found.append("%s=%s" % (key, value))
    else:
        processed = False
        for idx, line in enumerate(block_found):
            m = re.match(r'^\s*#+\s*%s=(.+)$' % key, line)
            if m:
                if value: # found comment outed line.
                    block_found[idx] = "%s=%s" % (key, value)
                processed = True
                break
            m = re.match(r'^\s*%s=(.+)$' % key, line)
            if m:
                if not value:
                    block_found[idx] = "#%s" % line
                processed = True
                break
        if not processed and value:
            block_found.append("%s=%s" % (key, value))
    block_before.extend(block_found)
    block_before.extend(block_after)
    return block_before

def subprocess_checkout_print_error(cmd_list, redirect_err=True, shell=False):
    try:
        return subprocess.check_output(cmd_list, stderr=subprocess.STDOUT, shell=shell)
    except subprocess.CalledProcessError as cpe:
        print cpe
        return cpe.output