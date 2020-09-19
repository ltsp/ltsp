## NAME
**ltsp.conf** - client configuration file for LTSP

## SYNOPSIS
The LTSP client configuration file is placed at `/etc/ltsp/ltsp.conf`
and it loosely follows the .ini format. It is able to control various
settings of the LTSP server and clients. After each ltsp.conf modification,
the `ltsp initrd` command needs to be run so that it's included in the
additional ltsp.img initrd that is sent when the clients boot.

## CREATION
To create an initial ltsp.conf, run the following command:

```shell
install -m 0660 -g sudo /usr/share/ltsp/common/ltsp/ltsp.conf /etc/ltsp/ltsp.conf
```

The optional `-g sudo` parameter allows users in the sudo group to edit
ltsp.conf with any editor (e.g. gedit) without running sudo.

## SYNTAX
Open and view the /etc/ltsp/ltsp.conf file that you just created, so that it's
easier to understand its syntax.

The configuration file is separated into sections:

 * The special [server] section is evaluated only by the ltsp server.
 * The special [common] section is evaluated by both the server and ltsp clients.
 * In the special [clients] section, parameters for all clients can be defined.
   Most ltsp.conf parameters should be placed there.
 * MAC address, IP address, or hostname sections can be used to apply settings
   to specific clients. Those support globs, for example [192.168.67.*].
 * It's also possible to group parameters into named sections like
   [crt_monitor] in the example, and reference them from other sections with
   the INCLUDE= parameter.
 * Advanced users may also use [applet/host] sections, for example
   [initrd-bottom/library*] would be evaluated by the `ltsp initrd-bottom`
   applet only for clients that have a hostname that starts with "library".

The ltsp.conf configuration file is internally transformed into a shell
script, so all the shell syntax rules apply, except for the sections headers
which are transformed into functions.

This means that you must not use spaces around the "=" sign,
and that you may write comments using the "#" character.

The `ltsp initrd` command does a quick syntax check by running
`sh -n /etc/ltsp/ltsp.conf` and aborts if it detects syntax errors.

## PARAMETERS
The following parameters are currently defined; an example is given in
each case.

**ADD_IMAGE_EXCLUDES=**_"/etc/ltsp/add-image.excludes"_<br/>
**OMIT_IMAGE_EXCLUDES=**_"home/*"_
: Add or omit items to the `ltsp image` exclusion list.
Some files and directories shouldn't be included in the generated image.
The initial list is defined in /usr/share/ltsp/server/image/image.excludes.
It can be completely overridden by creating /etc/ltsp/image.excludes.
ADD_IMAGE_EXCLUDES and OMIT_IMAGE_EXCLUDES can finetune the list by adding
or removing lines to it. They can either be filenames or multiline text.

**AUTOLOGIN=**_"user01"_<br/>
**RELOGIN=**_0|1_<br/>
**GDM3\_CONF=**_"WaylandEnable=false"_<br/>
**LIGHTDM_CONF=**_"greeter-hide-users=true"_<br/>
**SDDM_CONF=**_"/etc/ltsp/sddm.conf"_
: Configure the display manager to log in this user automatically.
If SSHFS is used, the PASSWORDS_x parameter (see below) must also be provided.
AUTOLOGIN can be a simple username like "user01", or it can be a partial
regular expression that transforms a hostname to a username.
For example, AUTOLOGIN="pc/guest" means "automatically log in as guest01 in
pc01, as guest02 in pc02 etc".<br/>
Setting RELOGIN=0 will make AUTOLOGIN work only once.
Finally, the *_CONF parameters can be either filenames or direct text, and
provide a way to write additional content to the generated display manager
configuration.

**CRONTAB_x=**_"30 15 * * *  poweroff"_
: Add a line in crontab. The example powers off the clients at 15:30.

**CUPS_SERVER=**_"$SERVER"_
: Set the CUPS server in the client /etc/cups/client.conf. Defaults to $SERVER.
You're supposed to also enable printer sharing on the server by running
`cupsctl _share_printers=1` or `system-config-printer` or by visiting
[http://localhost:631](http://localhost:631).
Then all printers can be managed on the LTSP server.
Other possible values are CUPS_SERVER="localhost", when a printer is connected
to a client, or CUPS_SERVER="ignore", to skip CUPS server handling.

**DEBUG_LOG=**_0|1_
: Write warnings and error messages to /run/ltsp/debug.log. Defaults to 0.

**DEBUG_SHELL=**_0|1_
: Launch a debug shell when errors are detected. Defaults to 0.

**DEFAULT_IMAGE=**_"x86_64"_<br/>
**KERNEL_PARAMETERS=**_"nomodeset noapic"_<br/>
**MENU_TIMEOUT=**_"5000"_
: These parameters can be defined under [mac:address] sections in ltsp.conf,
and they are used by `ltsp ipxe` to generate the iPXE menu.
They control the default menu item, the additional kernel parameters and
the menu timeout for each client. They can also be defined globally
under [server].

**DNS_SERVER=**_"8.8.8.8 208.67.222.222"_
: Specify the DNS servers for the clients.

**FSTAB_x=**_"server:/home /home nfs defaults,nolock,rsize=32768,wsize=32768 0 0"_
: All parameters that start with FSTAB_ are sorted and then their values
are written to /etc/fstab at the client init phase.

**HOSTNAME=**_"pc01"_
: Specify the client hostname. Defaults to "ltsp%{IP}".
HOSTNAME may contain the %{IP} pseudovariable, which is a sequence number
calculated from the client IP and the subnet mask, or the %{MAC}
pseudovariable, which is the MAC address without the colons.

**HOSTS_x=**_"192.168.67.10 nfs-server"_
: All parameters that start with HOSTS_ are sorted and then their values
are written to /etc/hosts at the client init phase.

**IMAGE_TO_RAM=**_0|1_
: Specifying this option under the [clients] section copies the rootfs
image to RAM during boot. That makes clients less dependent on
the server, but they must have sufficient memory to fit the image.

**INCLUDE=**_"other-section"_
: Include another section in this section.

**KEEP_SESSION_SERVICES=**_"at-spi-dbus-bus"_
: Whitelist some session (user) services so that they're not deleted, even if
they're listed in MASK_SESSION_SERVICES. Space separated list.

**KEEP_SYSTEM_SERVICES=**_"apparmor ssh"_
: Whitelist some system services so that they're not deleted, even if
they're listed in MASK_SYSTEM_SERVICES. Space separated list.

**LOCAL_SWAP=**_0|1_
: Activate local swap partitions. Defaults to 1.

**MASK_SESSION_SERVICES=**_"ubuntu-mate-welcome"_
: Mask some session services that shouldn't be started on LTSP clients.
Space separated list. See /usr/share/ltsp/client/init/56-mask-services.sh
for the default. Setting MASK_SESSION_SERVICES in ltsp.conf adds to that list.

**MASK_SYSTEM_SERVICES=**_"teamviewerd"_
: Mask some system services that shouldn't be started on LTSP clients.
Space separated list. See /usr/share/ltsp/client/init/56-mask-services.sh
for the default. Setting MASK_SYSTEM_SERVICES in ltsp.conf adds to that list.

**NAT=**_0|1_
: Only use this under the [server] section. Normally, `ltsp service`
runs when the server boots and detects if a server IP is 192.168.67.1,
in which case it automatically enables IP forwarding for the clients to
be able to access the Internet in dual NIC setups. But if there's a chance
that the IP isn't set yet (e.g. disconnected network cable), setting NAT=1
enforces that.

**OMIT_FUNCTIONS=**_"pam_main mask_services_main"_
: A space separated list of function names that should be omitted.
The functions specified here will not be executed when called.
This option can be specified in any [section].

**PASSWORDS_x=**_"teacher/cXdlcjEyMzQK [a-z][-0-9]\*/MTIzNAo= guest[^:]\*/"_
: A space separated list of regular expressions that match usernames, followed
by slash and base64-encoded passwords. At boot, `ltsp init` writes those
passwords for the matching users in /etc/shadow, so that then pamltsp can
pass them to SSH/SSHFS. The end result is that those users are able to
login either in the console or the display manager by just pressing [Enter]
at the password prompt.<br/>
Passwords are base64-encoded to prevent over-the-shoulder spying and to
avoid the need for escaping special characters. To encode a password in
base64, run `base64`, type a single password, and then Ctrl+D.<br/>
In the example above, the teacher account will automatically use "qwer1234"
as the password, the a1-01, b1-02 etc students will use "1234", and the
guest01 etc accounts will be able to use an empty password without even
authenticating against the server; in this case, SSHFS can't be used,
/home should be local or NFS.

**POST_APPLET_x=**_"ln -s /etc/ltsp/xorg.conf /etc/X11/xorg.conf"_
: All parameters that start with POST_ and then have an ltsp client applet
name are sorted and their values are executed after the main function of
that applet. See the ltsp(8) man page for the available applets.
The usual place to run client initialization commands that don't need to
daemonize is POST_INIT_x.

**PRE_APPLET_x=**_"debug_shell"_
: All parameters that start with PRE_ and then have an ltsp client applet
name are sorted and their values are executed before the main function of
that applet.

**PWMERGE_SUR=**, **PWMERGE_SGR=**, **PWMERGE_DGR=**, **PWMERGE_DUR=**
: Normally, all the server users are listed on the client login screens
and are permitted to log in. To exclude some of them, define one or
more of those regular expressions. For more information, read
/usr/share/ltsp/client/login/pwmerge. For example, if you name your clients
pc01, pc02 etc, and your users a01, a02, b01, b02 etc, then the following
line only shows/allows a01 and b01 to login to pc01:
`PWMERGE_SUR=".*%{HOSTNAME#pc}"`

**RPI_IMAGE=**_"raspbian"_
: Select this LTSP image to boot Raspberry Pis from.
This symlinks all $BASE_DIR/$RPI_IMAGE/boot/* files directly under $TFTP_DIR
when `ltsp kernel $RPI_IMAGE` is called.
See the [Raspberry Pi documentation page](https://ltsp.org/docs/installation/raspbian)
for more information.

**SEARCH_DOMAIN=**_"ioa.sch.gr"_
: A search domain to add to resolv.conf and to /etc/hosts. Usually provided
by DHCP.

**SERVER=**_"192.168.67.1"_
: The LTSP server is usually autodetected; it can be manually specified
if there's need for it.

**UDEV_SEAT_n_x=**_"*/usb?/?-[2,4,6,8,10,12,14,16,18]/*"_
: Support multiseat by putting udev rules that match hardware to seats to a
file named /etc/udev/rules.d/72-ltsp-seats.rules. See the EXAMPLES section.

**X_DRIVER=**"_vesa_"<br/>
**X_HORIZSYNC=**"_28.0-87.0_"<br/>
**X_MODELINE=**'_"1024x768_85.00"   94.50  1024 1096 1200 1376  768 771 775 809 -hsync +vsync_'<br/>
**X_MODES=**'"_1024x768" "800x600" "640x480"_'<br/>
**X_PREFERREDMODE=**"_1024x768_"<br/>
**X_VERTREFRESH=**"_43.0-87.0_"<br/>
**X_VIRTUAL**="_800 600_"
: If any of these parameters are set, the /usr/share/ltsp/client/init/xorg.conf
template is installed to /etc/X11/xorg.conf, while applying the parameters.
Read that template and consult xorg.conf(5) for more information.
The most widely supported method to set a default resolution is X_MODES.
If more parameters are required, create a custom xorg.conf as described in
the EXAMPLES section.

## EXAMPLES
To specify a hostname and a user to autologin in a client:

```shell
[3c:07:71:a2:02:e3]
HOSTNAME=pc01
AUTOLOGIN=user01
PASSWORDS_PC01="user01/cGFzczAxCg=="
```

The password above is "pass01" in base64 encoding. To calculate it, the
`base64` command was run in a terminal:

```shell
base64
pass01
<press Ctrl+D at this point>
cGFzczAxCg==
```

If some clients need a custom xorg.conf file, create it in e.g.
`/etc/ltsp/xorg-nvidia.conf`, and put the following in ltsp.conf
to dynamically symlink it for those clients at boot:

```shell
[pc01]
INCLUDE=nvidia

[nvidia]
POST_INIT_LN_XORG="ln -sf ../ltsp/xorg-nvidia.conf /etc/X11/xorg.conf"
```

To implement multiseat, where an LTSP client might have 2 or more seats,
with separate monitors, keyboard and mice, the following section can
be INCLUDEd. The "1" number maps the rule to "seat-1", while the rest
of the parameter name ("GRAPHICS" etc) is ignored. You can check which
hardware was assigned to which seat with `loginctl seat-status seat0`.


```shell
[multiseat]
UDEV_SEAT_1_GRAPHICS="*/pci*/*/0000:01:00.0*"
UDEV_SEAT_1_SOUND="*/sound/card1*"
UDEV_SEAT_1_EVEN_USB_PORTS="*/usb?/?-[2,4,6,8,10,12,14,16,18]/*"
```

Since ltsp.conf is transformed into a shell script and sections into
functions, it's possible to directly include code or to call sections
at POST_APPLET_x hooks.

```shell
[clients]
# Allow local root logins by setting a password hash for the root user.
# The hash contains $, making it hard to escape in POST_INIT_x="sed ...".
# So put sed in a section and call it at POST_INIT like this:
POST_INIT_SET_ROOT_HASH="section_set_root_hash"

# This is the hash of "qwer1234"; cat /etc/shadow to see your hash.
[set_root_hash]
sed 's|^root:[^:]*:|root:$6$bKP3Tahd$a06Zq1j.0eKswsZwmM7Ga76tKNCnueSC.6UhpZ4AFbduHqWA8nA5V/8pLHYFC4SrWdyaDGCgHeApMRNb7mwTq0:|' -i /etc/shadow
```
