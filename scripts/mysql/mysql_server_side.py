#!/usr/bin/python

import getopt
from global_static import PyGlobal
import common_util
import shutil
import StringIO
import sys, os, io, time, re, tempfile, json, subprocess
import itertools
import xml.etree.ElementTree as ET

if not PyGlobal.config_file:
    PyGlobal.config_file = os.path.join(os.path.split(__file__)[0], 'config.json')
if os.path.exists(PyGlobal.config_file):
    common_util.get_configration(PyGlobal.config_file, "utf-8", True)
    j = PyGlobal.configuration.json
    client_bin = j['ClientBin']
    os_config = PyGlobal.configuration.get_os_config()
    server_side = os_config["ServerSide"]



def usage():
    print "usage message printed."

# "ho:" mean -h doesn't need a argument, but -o needs.

def main(action, args):
    if action == 'MysqlExtraFile':
        common_util.send_lines_to_client(new_mysql_extrafile())
    elif action == 'FlushLogs':
        common_util.send_lines_to_client(invoke_mysql_flushlogs())
    elif action == 'Dump':
        common_util.send_lines_to_client(invoke_mysqldump())
    elif action == 'GetMycnf':
        common_util.send_lines_to_client(get_mycnf_file())
    elif action == 'DownloadPublicKey':
        common_util.send_lines_to_client(get_openssl_publickey())
    elif action == 'DirFileHashes':
        common_util.send_lines_to_client(common_util.get_dir_filehashes(args[0]))
    elif action == 'FileHashes':
        common_util.send_lines_to_client(common_util.get_filehashes(args))
    elif action == 'FileHash':
        common_util.send_lines_to_client(common_util.get_one_filehash(args[0]))
    elif action == 'FlushLogFileHash':
        common_util.send_lines_to_client(flushlogs_filehash())
    elif action == 'GetVariables':
        common_util.send_lines_to_client(get_mysql_variables(args))
    elif action == 'Echo':
        common_util.send_lines_to_client(' '.join(args))

def get_openssl_publickey():
    openssl_exec = j["openssl"]
    private_key_file = j["ServerPrivateKeyFile"]
    with tempfile.NamedTemporaryFile(delete=False) as tf:
        subprocess.call([openssl_exec, 'rsa', '-in' , private_key_file, '-pubout', '-out', tf.name])
        return tf.name

def get_enabled_version(lines):
    founded = []
    current_version = None
    for line in lines:
        line = line.strip()
        m = re.match(r'^\[.*?(\d+)-.*\]$', line)
        if m:
            current_version = m.group(1)
        else:
            if line == 'enabled=1' and current_version:
                founded.append(current_version)
                current_version = None
    return founded


def enable_repoversion(repo_file, version):
    common_util.backup_localdirectory(repo_file)
    lines = _enable_repoversion(repo_file, version)
    with io.open(repo_file, 'wb') as opened_file:
        opened_file.writelines(["%s%s" % (line, "\n") for line in lines])
    
def _enable_repoversion(repo_file, version):
    current_version = None
    with io.open(repo_file, mode='r') as opened_file:
        lines = [line.strip() for line in opened_file.readlines()]
        new_lines = []
    for line in lines:
        m = re.match(r'^\[.*?(\d+)-.*\]$', line)
        if m:
            current_version = m.group(1)
        else:
            m = re.match(r'^\[.*\]$', line)
            if m:
                current_version = 'others'
            else:
                m = re.match('^enabled=(0|1)$', line)
                if m:
                    if current_version == version:
                        line = 'enabled=1'
                    elif current_version != 'others':
                        line = 'enabled=0'
        new_lines.append(line)
    return new_lines

def new_mysql_extrafile(plain_password=None):
    mysql_user = j['MysqlUser']
    if mysql_user is None:
        raise ValueError('MysqlUser property in configuration file is empty.')
    if plain_password:
        plain_password = plain_password if plain_password != PyGlobal.empty_password else ''
        tf = tempfile.mktemp()
        with io.open(tf, mode='wb') as opened_file:
            opened_file.writelines(["%s%s" % (line, "\n") for line in ["[client]", "user=%s" % mysql_user, 'password="%s"' % plain_password]])
        return tf
    else:
        if PyGlobal.mysql_extrafile is None:
            plain_password = common_util.unprotect_password_by_openssl_publickey(j['MysqlPassword'])
            tf = tempfile.mktemp()
            with io.open(tf, mode='wb') as opened_file:
                opened_file.writelines(["%s%s" % (line, "\n") for line in ["[client]", "user=%s" % mysql_user, 'password="%s"' % plain_password]])
            PyGlobal.mysql_extrafile = tf
            return tf
        else:
            return PyGlobal.mysql_extrafile

def get_sql_commandline(sql, plain_password):
    extra_file = new_mysql_extrafile(plain_password)
    cmd_line = [
        j['ClientBin'],
        "--defaults-extra-file=%s" % extra_file,
        "-X",
        "-e",
        sql
    ]
    return {"cmd_line": cmd_line, "extrafile": extra_file}

def invoke_mysql_sql_command(sql, plain_password, combine_error=False):
    cmd_dict = get_sql_commandline(sql, plain_password)
    return common_util.subprocess_checkout_print_error(cmd_dict['cmd_line'], redirect_err=combine_error)

def get_mysql_variables(variable_names=None, plain_password=None):
    result = invoke_mysql_sql_command('show variables', None, combine_error=True)
    # result may start with some warning words.
    angle_idx = result.index('<')
    if angle_idx > 0:
        result = result[angle_idx:]
    rows = [(x[0].text, x[1].text) for x in ET.fromstring(result)] # tuple (auto_increment_increment, 1)
    if (variable_names is None) or (len(variable_names) == 0):
        return rows
    elif isinstance(variable_names, str):
        result = filter(lambda x: x[0] == variable_names, rows)
        if len(result) > 0:
            return {'name': result[0][0], 'value': result[0][1]}
    else:
        result = filter(lambda x: x[0] in variable_names, rows)
        result = map(lambda t: {'name': t[0], 'value': t[1]}, result)
        return result

def flushlogs_filehash(plain_password=None):
    idx_file = get_mysql_variables('log_bin_index', plain_password)['value']
    parent = os.path.split(idx_file)[0]
    with io.open(idx_file, 'rb') as opened_file:
        lines = opened_file.readlines()
        lines = [line.strip() for line in lines]
        def to_file_desc(relative_file):
            ff = os.path.join(parent, relative_file)
            return common_util.get_one_filehash(ff)
        return map(to_file_desc, lines)

def invoke_mysql_flushlogs(plain_password=None):
    extra_file = new_mysql_extrafile(plain_password)
    flush_cmd = [
        j['MysqlAdminBin'],
        "--defaults-extra-file=%s" % extra_file,
        "flush-logs"
    ]
    return_code = subprocess.call(flush_cmd)
    # time.sleep(5)
    if (PyGlobal.verbose):
        print "invoke_mysql_flushlogs subprocess call return %s" % return_code
    return flushlogs_filehash(plain_password)


def invoke_mysqldump(plain_password=None):
    extra_file = new_mysql_extrafile(plain_password)
    dumpfile = j['DumpFilename']
    dump_cmd = [j['DumpBin'],
                "--defaults-extra-file=%s" % extra_file,
                '--max_allowed_packet=512M',
                '--quick',
                '--events',
                '--all-databases',
                '--flush-logs',
                '--delete-master-logs',
                '--single-transaction']
    with io.open(dumpfile, 'wb') as opened_file:
        subprocess.call(dump_cmd, stdout=opened_file)

    return common_util.get_one_filehash(dumpfile)

def enable_logbin(mycnf_file, logbin_base_name='hm-log-bin', server_id='1'):
    common_util.backup_localdirectory(mycnf_file)
    with io.open(mycnf_file, 'r') as opened_file:
        lines = [line.strip() for line in opened_file.readlines()]
        lines = common_util.update_block_config_file(lines, 'log-bin', logbin_base_name)
        lines = common_util.update_block_config_file(lines, 'server-id', server_id)
    
    with io.open(mycnf_file, 'wb') as opened_file:
        opened_file.writelines(["%s%s" % (line, "\n") for line in lines])

def get_mycnf_file():
    out = subprocess.check_output([client_bin, '--help'])
    sio = StringIO.StringIO(out)
    line = sio.readline()
    found = False
    result = None
    while line:
        line = line.strip()
        if found:
            result = line
            break
        if "Default options are read from the following files in the given order:" in line:
            found = True
        line = sio.readline()
    sio.close()
    results = result.split()
    for r in results:
        if os.path.exists(r):
            return r

if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hv:a:", ["help", "action=", "notclean", "verbose"])
    except getopt.GetoptError as err:
        # print help information and exit:
        print str(err)  # will print something like "option -a not recognized"
        sys.exit(2)
    verbose = False
    clean = True
    action = None
    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o == '--notclean':
            clean = False
        elif o == '--verbose':
            PyGlobal.verbose = True
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("--action", '-a'):
            action = a
        else:
            assert False, "unhandled option"
    try:
        main(action, args)
    except Exception as e:
        print type(e)
        print e
        print e.message
    finally:
        if PyGlobal.mysql_extrafile and clean:
            if os.path.exists(PyGlobal.mysql_extrafile):
                os.remove(PyGlobal.mysql_extrafile)
        PyGlobal.mysql_extrafile = None

