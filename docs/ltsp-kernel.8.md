## NAME
**ltsp kernel** - copy the kernel and initrd from an image to TFTP

## SYNOPSIS
**ltsp** [_ltsp-options_] **kernel** [**-k** _kernel-initrd_] [_image_] ...

## DESCRIPTION
Copy vmlinuz and initrd.img from an image or chroot to TFTP.
If _image_ is unspecified, process all of them.
For simplicity, only chroot directories and raw images are supported, either
full filesystems (squashfs, ext4) or full disks (flat VMs). They may be sparse
to preserve space. Don't use a separate /boot nor LVM in disk images.
The targets will always be named vmlinuz and initrd.img to simplify ltsp.ipxe.

## OPTIONS
See the **ltsp(8)** man page for _ltsp-options_.

**-k**, **--kernel-initrd=**_glob-regex_
: Specify a kernel glob and an initrd regex to locate them inside the _image_;
try to autodetect if undefined. See the EXAMPLES section below.

## DIRECT IMAGES
This section is for advanced LTSP sysadmins.
Let's suppose that you want to test if your users would prefer Xubuntu
to your existing Ubuntu MATE. First, move and rename your Xubuntu CD to this
location, without using symlinks, and then update kernels and ipxe:

```shell
mv xubuntu-18.04-desktop-amd64.iso /srv/ltsp/images/xubuntu-18.04.img
ltsp kernel xubuntu-18.04
ltsp -o ipxe  # note, this overwrites ltsp.ipxe
```

If you reboot your clients, they'll now have the option to boot with the
Xubuntu live CD in LTSP mode! This is like booting with the live CD, except
that all the users and their homes are available! So the users can normally
login and work for days or weeks in the new environment, before you decide
that they like Xubuntu and that you want to move from using the live CD to
maintaining a Xubuntu image using a virtual machine.

You can also do this with virtual machine images! For example:

```shell
    mv ~/VirtualBox\ VMs/debian/debian-flat.vmdk /srv/ltsp/images/debian-vm.img
    ln -rs /srv/ltsp/images/debian-vm.img ~/VirtualBox\ VMs/debian/debian-flat.vmdk
    ltsp kernel debian-vm
    ltsp -o ipxe  # note, this overwrites ltsp.ipxe
```

These commands move your "debian" VM to the LTSP images directory, symlink
it back to where VirtualBox expects it, and update the kernels and ipxe.
After these, you'll be able to boot directly from the "debian-vm" iPXE menu
item without having to run `ltsp image`! It's the fastest way to test image
changes without waiting 10 minutes for `ltsp image` each time.

Some advanced users may think of using the opposite symlink instead:

```shell
    ln -rs ~/VirtualBox\ VMs/debian/debian-flat.vmdk /srv/ltsp/images/debian-vm.img
```

Unfortunately NFS doesn't follow symlinks outside of the exported directories,
so the clients wouldn't be able to boot in this case. Advanced users may use
bind mounts though, e.g.:

```shell
    mount --bind ~/VirtualBox\ VMs/debian/debian-flat.vmdk /srv/ltsp/images/debian-vm.img
```

## EXAMPLES
Typical use:

```shell
ltsp kernel x86_64
```

Passing a glob to locate the kernel and a regex to locate the initrd in a
Debian live CD:

```shell
ltsp kernel --kernel-initrd="live/vmlinuz-* s|vmlinuz|initrd.img|"
```
