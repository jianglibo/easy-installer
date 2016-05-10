# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA


# Script used by systemd mysqld.service to run before executing mysqld

get_option () {
    local section=$1
    local option=$2
    local default=$3
    ret=$(/usr/bin/my_print_defaults $section | grep '^--'${option}'=' | cut -d= -f2- | tail -n 1)
    [ -z "$ret" ] && ret=$default
    echo $ret
}

install_validate_password_sql_file () {
    local dir
    local initfile
    if [ -d /var/lib/mysql-files ]; then
        dir=/var/lib/mysql-files
    else
        dir=/tmp
    fi
    initfile="$(mktemp $dir/install-validate-password-plugin.XXXXXX.sql)"
    chown mysql:mysql "$initfile"
    echo "INSERT INTO mysql.plugin (name, dl) VALUES ('validate_password', 'validate_password.so');" > $initfile
    echo $initfile
}

install_db () {
    # Note: something different than datadir=/var/lib/mysql requires SELinux policy changes (in enforcing mode)
    datadir=$(get_option mysqld datadir "/var/lib/mysql")
    log=$(get_option mysqld log-error /var/log/mysqld.log)

    # Restore log, dir, perms and SELinux contexts

    [ -d "$datadir" ] || install -d -m 0751 -omysql -gmysql "$datadir" || exit 1

    [ -e $log ] || touch $log
    chmod 0640 $log
    chown mysql:mysql $log || exit 1

    if [ -x /usr/sbin/restorecon ]; then
        /usr/sbin/restorecon "$datadir"
        /usr/sbin/restorecon $log
        for dir in /var/lib/mysql-files /var/lib/mysql-keyring ; do
            if [ -x /usr/sbin/semanage -a -d /var/lib/mysql -a -d $dir ] ; then
                /usr/sbin/semanage fcontext -a -e /var/lib/mysql $dir >/dev/null 2>&1
                /usr/sbin/semanage fcontext -a -e /var/lib/mysql $dir >/dev/null 2>&1
                /sbin/restorecon $dir
            fi
        done
    fi

    # If special mysql dir is in place, skip db install
    [ -d "$datadir/mysql" ] && exit 0

    # Create initial db and install validate_password plugin
    initfile="$(install_validate_password_sql_file)"
    /usr/sbin/mysqld --initialize --datadir="$datadir" --user=mysql --init-file="$initfile"
    rm -f "$initfile"

    # Generate certs if needed
    if [ -x /usr/bin/mysql_ssl_rsa_setup -a ! -e "${datadir}/server-key.pem" ] ; then
        /usr/bin/mysql_ssl_rsa_setup --datadir="$datadir" --uid=mysql >/dev/null 2>&1
    fi
    exit 0
}
install_db

exit 0
