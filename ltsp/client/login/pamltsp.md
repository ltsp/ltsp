# PAM notes

## Design
All LTSP code is interpreted, to be sent via the initramfs in systems of
different architectures. Thus, pamltsp is written in shell/python and runs
from pam_exec hooks; which results in certain limitations.
To allow both local and pamltsp users to login, pam_exec is run after pam_unix.
This means that pamltsp users must have a password that:
 * Is invalid, so that pam_unix fails
 * Is not a locked password, so that display managers won't hide them

This is implemented by putting "pamltsp[=base64-password]" in the place of
the password hash in the shadow file, and comes with the following benefits:
 * The sysadmin and pamltsp can easily detect remote users; it wouldn't be
   nice if roaming laptop users were attempting to authenticate against the
   server every time they misttyped their password
 * Passwordless logins can be implemented if the sysadmin provides the
   password in base64 encoding there. Plaintext passwords can't be used as
   they may contain invalid characters; and base64 additionally hides them
   from over-the-shoulder spying
 * To convert remote users to local, the sysadmin may run `passwd user`
 * Converting local users to remote is done with `usermod -p pamltsp[=...]`

Another limitation is that pam_exec sometimes runs without root permissions,
for example for screensaver unlocking. In this case, pamltsp isn't able to run
`getent shadow` and see if the user is local or remote. To overcome this,
pamltsp caches the necessary data in /run/ltsp/pam on user login.

## Autologin and passwordless login
Implementing autologin is easy; LTSP scripts or the sysadmin store the base64
password in shadow and configure the DM; pamltsp is not called for the
auth phase, so it does the SSHFS mount in the open_session phase.

One way to do passwordless logins is by running `passwd -d`; some DMs
then even allow single-click logins, without asking for a password.
This isn't a suitable method because pam_unix then authenticates the user and
pamltsp is never called, so users would be able to login in vt1 without their
home mounted over SSHFS, they'd be able to run `passwd` and change it etc.

So the best passwordless login that we can offer, is a [click] to select the
user, and [enter] to enter an empty password that pamltsp will accept.
This rationale is valid for screensaver unlocking as well.

TODO: are all pamltsp=base64-pass entries automatically passwordless?
      Or is pamltsp=base64-pass,passwordless=1 needed?
TODO: is a global SSHFS=[01] option enough, or is ",sshfs=[01]" needed?
TODO: is a global server= option enough?
TODO: is old password caching helpful, i.e. ",cached="?
      Only makes sense with local home, of course...

## Notes for DM behavior for locked/blank passwords
B=blank password (can run `passwd` but not `ssh`; `passwd -S` returns P, not B)
L=locked password
NP=no password (empty, e.g. live user)
O=if there's an "other user/non listed user" entry
P=valid password

https://termbin.com/ml6d
blank=$(python3 -c 'import crypt; print(crypt.crypt(""))')
echo -e '1\n1\n' | sudo adduser b; sudo usermod -p "$blank" b
echo -e '1\n1\n' | sudo adduser l; sudo passwd -l l
echo -e '1\n1\n' | sudo adduser np; sudo passwd -d np
echo -e '1\n1\n' | sudo adduser p
ps aux | grep dm

bionic-gnome (gdm)
    B=prompt, L=hidden, NP=single-click, O="Not listed?", P=prompt
disco-mate (lightdm/slick greeter)
    B=?, L=prompt, NP="Log In", O=no, P=prompt
bionic-kde (kdm?)
    B=?, L=prompt, NP=prompt, O="Different User", P=prompt
disco-budgie (lightdm/slick greeter)
    B=prompt, L=prompt, NP="Log In", O=no, P=prompt

jessie-mate screensaver:
    B=disappear-on-move, L=prompt, NP=disappear-on-move, P=prompt

## Alternative ideas that were dropped
An alternative idea was to use the pw_pass field of passwd, but it was dropped
because if a sysadmin later on ran `passwd user`, the new hash would be stored
in passwd instead of shadow.

A pamltsp group similar to nopasswdlogin could also help, but since we need
an invalid hash anyway, it wasn't chosen. The nopasswdlogin group is mostly
a PAM thing anyway, e.g. the gdm code doesn't even mention it anymore.
https://bugzilla.gnome.org/show_bug.cgi?id=675780

Instead of /run/ltsp/pam, the date of last password change in shadow could be
abused, and set to a far distant future date. `passwd -S` then would have
enough permissions then retrieve that. `pwck` would report a warning for this,
but all programs should be able to cope with it, e.g. imagine BIOS battery
failures. The date would be automatically reset by the password change if the
sysadmin decided to make the user local again.

## common-auth
PAM_TYPE=auth means that the user typed a password. At that point we can use
ssh to authenticate them, or sshfs to authenticate them and mount their home.

We mount their home if $SSHFS!=0 and :ssh: is in passwd and it's not already
mounted.

If seteuid is not passed to pam_exec, then running `su - user2` as user1,
can't sshfs-mount /home/user2 as TODO pam is running as user1?

Maybe running without seteuid, and with fuse allow_root, is the safest option.

## common-session open
PAM_TYPE=open_session means that a user switch has happened without the need of
a password. Examples:
 * Display manager autologin
 * (as root) `su - user`
 * Note, /etc/pam.d/sudo includes common-session-noninteractive,
   not common-session. This means it doesn't trigger `systemd --user`,
   it doesn't involve a seat etc. We probably shouldn't hook there,
   and document that `sudo -u user` doesn't sshfs-mount the home directory.

## sshfs-unmount
Ideally, we can `fusermount -u /home/user` on PAM_TYPE=close_session if no user
processes are still running. In this case pam_exec must be listed after
pam_systemd, so that `systemd --user` has finished?
==> no, systemd --user is still running at that point; we'd need to delay
1 sec or exclude it, i.e. hacky code.
And maybe for the non-ideal cases like mate-session bugs, an LTSP hook
can pkill dbus-daemon etc, so that the pam related code is clean and constant.
HMMM systemd is probably using cgroups to see when to mount/unmount
/run/user/XXX
let's try to bind to that, it appears very consistent!

## KillUserProcesses - HERE
We want KillUserProcesses=yes because of various bugs in sessions etc.
It's doing a great job at killing processes.
It won't kill sshfs even if we run it with the user uid, as it's in a
different scope (we wouldn't want sshfs to die before user processes
get a chance to flush their file buffers).
We can't run fusermount on PAM_TYPE=session_close as KillUserProcesses
hasn't take effect yet. No, not even if we (sleep 5; fusermount) &
first; somehow systemd manages to wait that (cgroups/scopes?)
OOOOh wait, maybe on session_close we can run:
systemd-run on-different-scope 'sleep 5; check if /run/user gone; fusermount -u`
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

## Password caching
When ssh authentication succeeds, I could store the hash to shadow!!!,
so that if "offline" is detected, the user would authenticate locally.
This would be useful for ...roaming/laptop ltsp clients with local disk,
squashfs mirror locally, ...
Nope. It would be better if it's a local account, not a :pamltsp: one.
Use case:
administrator = teacher can take the school laptop and work at home,
yet he'd allow :ssh: student accounts to work via sshfs at school.
We actually don't want caching there.
===> Well at least keep it in mind, so that it might be stored in
pamltsp=base64-pass,cached=xxx ==> comma separated variables.

## To delete user settings, for benchmarking sshfs/nfs:
find ~ -mindepth 1 -maxdepth 1 -name '.*' -exec rm -rf {} +
sshfs first login: 105 sec?!! => gnome-keyring problem
sshfs first logout: 30 sec, at_spi hang
sshfs second login: 6 sec
sshfs second logout: 1 sec
(clear again)
sshfs third login: 120 sec?!!
sshfs third logout: 30 sec, at_spi hang
-o kernel_cache => 114, meh
nfs first login: 7 sec
firefox: 6 sec

## pam_mount, autofs, ipsec
Those don't sound very suitable; but here's a link for pam_mount and sshfs:
https://sourceforge.net/p/fuse/mailman/message/32563925/
http://manpages.ubuntu.com/manpages/bionic/man8/pam_mount.8.html
http://manpages.ubuntu.com/manpages/bionic/man5/pam_mount.conf.5.html
