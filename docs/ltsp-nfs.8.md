# ltsp-nfs

## NAME

**ltsp nfs** - configure NFS exports for LTSP

## SYNOPSIS

**ltsp** [_ltsp-options_] **nfs** [**-h** _nfs-home_] [**t** _nfs-tftp_]

## DESCRIPTION

Install /etc/exports.d/ltsp-nfs.conf in order to export /srv/ltsp ($BASE_DIR),
/srv/tftp/ltsp ($TFTP_DIR) and optionally /home ($HOME_DIR).

## OPTIONS

See the **ltsp(8)** man page for _ltsp-options_.

**-h**, **--nfs-home**=_0|1_
:   Export /home over NFS3. Defaults to 0.
    Note that NFS3 is insecure for home, so by default SSHFS is used.
    To specify a different directory, set $HOME_DIR in /etc/ltsp/ltsp.conf.

**-t**, **--nfs-tftp**=_0|1_
:   Export /srv/tftp/ltsp over NFS3. Defaults to 1.
    To specify a different directory, set $TFTP_DIR in /etc/ltsp/ltsp.conf.

## EXAMPLES

To export /home over NFS (insecure), use the following ltsp.conf parameters:

```shell
[server]
NFS_HOME=1

[clients]
FSTAB_HOME="server:/home /home nfs defaults,nolock 0 0"
```

And run these commands on the server:

```shell
ltsp initrd  # This is needed whenever ltsp.conf is modified
ltsp nfs
```

To export only some user homes over NFS while the rest still use SSHFS,
use these lines in ltsp.conf instead:

```shell
[server]
NFS_HOME=1
HOME_DIR=/home/nfs

[clients]
FSTAB_HOME="server:/home/nfs /home nfs defaults,nolock 0 0"
```

Then run the following commands on the server, to move some home directories
under /home/nfs and to create appropriate symlinks in case the users ever
need to SSH to the server. Note that the NFS server doesn't follow symlinks
outside of an export:

```shell
mkdir /home/nfs
for u in guest01 guest02; do
    mv "/home/$u" /home/nfs/
    ln -s "nfs/$u" "/home/$u"
done

ltsp initrd
ltsp nfs
```
