## NAME
**ltsp** - entry point to Linux Terminal Server Project applets

## SYNOPSIS
**ltsp** [**-b** _base-dir_] [**-h**] [**-m** _home-dir_] [**-o**] [**-t** _tftp-dir_] [**-V**] [_applet_] [_applet-options_]

## DESCRIPTION
Run the specified LTSP _applet_ with _applet-options_. To get help with applets and their options, run \`**man ltsp** _applet_\` or \`**ltsp --help** _applet_\`.

## APPLETS
The following applets are currently defined:

 - **dnsmasq**: configure dnsmasq for LTSP
 - **image**: generate a squashfs image from an image source
 - **info**: gather support information about the LTSP installation
 - **initrd**: create the ltsp.img initrd add-on
 - **ipxe**: install iPXE binaries and configuration in TFTP
 - **kernel**: copy the kernel and initrd from an image to TFTP
 - **nfs**: configure NFS exports for LTSP

LTSP clients also have some additional applets, like **initrd-bottom**,
**init** and **login**, but they're not runnable by the user.

## OPTIONS
LTSP directories can be configured by passing one or more of the following
parameters, but it's recommended that an /etc/ltsp/ltsp.conf configuration
file is created instead, so that you don't have to pass them in each ltsp
command.

**-b**, **--base-dir=**_/srv/ltsp_
: This is where the chroots, squashfs images and virtual machine symlinks are;
so when you run `ltsp kernel img_name`, it will search either for a squashfs
image named **/srv/ltsp/images/img_name.img**, or for a chroot named
**/srv/ltsp/img_name**, if it's a directory that contains /proc. Additionally,
`ltsp image img_name` will also search for a symlink to a VM disk named
**/srv/ltsp/img_name.img**. $BASE_DIR is exported read-only by NFSv3, so do
not put sensitive data there.

**-h**, **--help**
:  Display a help message.

**-m**, **--home-dir=**_/home_
: The default method of making /home available to LTSP clients is SSHFS.
In some cases security isn't an issue, and sysadmins prefer the insecure
NFSv3 speed over SSHFS. $HOME_DIR is used by `ltsp nfs` to export the correct
directory, if it's different to /home, and by LTSP clients to mount it.

**-o**, **--overwrite**
: Overwrite all existing files. Usually applets refuse to overwrite
configuration files that may have been modified by the user, like ltsp.ipxe.

**-t**, **--tftp-dir=**_/srv/tftp_
: LTSP places the kernels, initrds and iPXE files in /srv/tftp/ltsp, to be
retrieved by the clients via the TFTP protocol. The TFTP server of dnsmasq
and tftpd-hpa are configured to use /srv/tftp as the TFTP root.

**-V**, **--version**
: Display the version information.

## FILES
**/etc/ltsp/ltsp.conf**
: All the long options can also be specified as variables in the **ltsp.conf** configuration file in UPPER_CASE, using underscores instead of hyphens.

## ENVIRONMENT
All the long options can also be specified as environment variables in
UPPER_CASE, for example:

```shell
BASE_DIR=/opt/ltsp ltsp kernel ...
```

## EXAMPLES
The following are the typical commands to install and maintain LTSP in
chrootless mode:

```shell
# To install:
ltsp image /
ltsp dnsmasq
ltsp nfs
ltsp ipxe

# To update the exported image, after changes in the server software:
ltsp image /
```

The following are the typical commands to provide an additional x86_32
image, assuming one uses VirtualBox. If you specifically name it x86_32,
then the ltsp.ipxe code automatically prefers it for 32bit clients:

```shell
ln -rs $HOME/VirtualBox\ VMs/x86_32/x86_32-flat.vmdk /srv/ltsp/x86_32.img
ltsp image x86_32
ltsp -o ipxe  # note, this overwrites ltsp.ipxe
```
