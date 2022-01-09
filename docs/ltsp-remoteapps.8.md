# ltsp-remoteapps

## NAME

**ltsp remoteapps** - run applications on the LTSP server via ssh -X

## SYNOPSIS

**ltsp** [_ltsp-options_] **remoteapps** _application_ [_parameters_] ...  
**ltsp** [_ltsp-options_] **remoteapps** [**-r** _register_] _application_ ...

## DESCRIPTION

Setup passwordless SSH, by ensuring that ~/.ssh/authorized_keys contains one
of the public user's SSH keys. Then execute `ssh -X server app params`.
If the user has no SSH keys, a new one is generated.
For `ltsp remoteapps app` to work, /home/username should already be mounted via
NFS (on LTSP client boot) or SSHFS (on LTSP user login).

## OPTIONS

See the **ltsp(8)** man page for _ltsp-options_.

**-r**, **--register**
:   Register the specified applications as remoteapps, by creating symlinks in
    /usr/local/bin/_application_ for each one of them. Since `/usr/local/bin`
    usually comes before `/usr/bin` in `$PATH`, the remoteapps should be invoked
    even if the application is selected from the system menu.

## EXAMPLES

The following ltsp.conf parameter can be used to register the MATE applications
`users-admin` (Menu ▸ System ▸ Administration ▸ Users and Groups) and
`mate-about-me` (Menu ▸ System ▸ Preferences ▸ Personal ▸ About Me) as
remoteapps:

```shell
[clients]
REMOTEAPPS="users-admin mate-about-me"
```

That way, LTSP users are able to change their passwords or display names.
The password change takes effect immediately, while for the new display name
to appear in the LTSP client, the sysadmin must run `ltsp initrd` and the
client needs to be rebooted.
