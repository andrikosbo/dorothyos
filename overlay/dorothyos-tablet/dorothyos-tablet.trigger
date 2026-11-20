#!/bin/sh
# fired by apk after another package changed the stock lock screen directory (plasma-desktop upgrade)
/usr/share/dorothyos-tablet/system/pipa-lockscreen apply || :
exit 0
