# ltsp-ipxe

## NAME

**ltsp ipxe** - install iPXE binaries and configuration in TFTP

## SYNOPSIS

**ltsp** [_ltsp-options_] **ipxe** [**-b** _binaries_]

## DESCRIPTION

Generate the ltsp.ipxe configuration file and install the required iPXE binaries
in /srv/tftp/ltsp: memtest.0, memtest.efi, snponly.efi and undionly.kpxe.

An ltsp-binaries package is available in the LTSP PPA that provides them;
otherwise, some of them are automatically found in the ipxe/memtest86+ packages.

## OPTIONS

See the **ltsp(8)** man page for _ltsp-options_.

**-b**, **--binaries**[=_0|1|""_]
:   Reinstall the iPXE binaries in TFTP even if they already exist.
    Defaults to "", which means "only install the missing ones".
    Note that the --overwrite flag doesn't affect the binaries, they're only
    controlled by the --binaries flag.

## ADVANCED IMAGE SOURCES

This section is for advanced LTSP sysadmins.
Normally, image sources are simple names like "x86_64" or full paths like
"../path/to/image".
But the "img_src" parameters are much more flexible than that; specifically,
they are series of mount sources:

```shell
img1,mount-options1,,img2,mount-options2,,...
```

...where img1 may be a simple name or full path relative to the current
directory, and img2+ are full paths relative to the target directory.

Let's see an advanced example: suppose that your clients came with
Windows, and that you copied a live CD into C:\ltsp\ubuntu.iso, and you
want your LTSP clients to use that for speed. First, disable Windows
fast boot and hibernation, so that Linux is able to mount its partition.
Then create the following "method" in ltsp.ipxe:

```ipxe
:local_image
# The "local_image" method boots C:\ltsp\ubuntu.iso
set cmdline_method root=/dev/sda1 ltsp.image=ltsp/ubuntu.iso,fstype=iso9660,loop,ro,,casper/filesystem.squashfs,squashfs,loop,ro loop.max_part=9
goto ltsp
```

Explanation:

- The root=/dev/sda1 parameter tells the initramfs to mount /dev/sda1 into
  /root.
- Then the LTSP code will look under /root/ltsp/ and mount ubuntu.iso using the
  loop,ro options over /root again.
- Then the LTSP code will look under /root/casper/ and mount
  filesystem.squashfs over /root again. This casper/filesystem.squashfs path is
  where the live filesystem exists inside the Ubuntu live CDs.

So while this long line gives a good example on using advanced image sources,
the LTSP code is actually smart enough to autodetect Ubuntu live CDs and
filesystem types, so one could simplify it to:

```ipxe
:local_image
# The "local_image" method boots C:\ltsp\${img}.img
set cmdline_method root=/dev/sda1 ltsp.image=ltsp/${img}.img loop.max_part=9
goto ltsp
```

The ${img} parameter is the name of the menu; it would be "ubuntu" if you
copied ubuntu.iso in /srv/ltsp/images/ubuntu.img and ran `ltsp ipxe`.

## EXAMPLES

Initial use:

```shell
ltsp ipxe
```

Regenerate ltsp.ipxe and reinstall the binaries:

```shell
ltsp ipxe -b
```

Copy the binaries from a USB stick before running ltsp ipxe:

```shell
mkdir -p /srv/tftp/ltsp
cd /media/administrator/usb-stick
cp {memtest.0,memtest.efi,snponly.efi,undionly.kpxe} /srv/tftp/ltsp
ltsp ipxe
```
