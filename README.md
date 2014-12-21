irssiScripts
============

Some useful scripts I created for use with great IRC client `irssi`.

## xmobar.pl
Binding for `xmobar`. It uses pipe reader on `xmobar` side:

    Config { ...
    , commands = [ Run PipeReader "/tmp/irssi2xmobar" "irssi" ]
    }

This script supports channel/window activity watching (with selectable
notification levels), and watching of activity of selected nicks.
It saves its setting is `irssi` configuration file, but preferred way of
changing it is using `/xmobar` command (see `/xmobar help`).

The disadvantage is that `irssi` can only monitor window changes in currently
invisible windows. Otherwise, this script should be working quite well.

## xaway.pl
Automatically switch irssi window to 1 when terminal is going invisible and back.
This script is considerably unstable (it crashes about once few days) and has
no configuration. Hopefully I will redo it one day.

