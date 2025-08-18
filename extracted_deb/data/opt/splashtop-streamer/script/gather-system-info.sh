#!/bin/sh

TMP_PATH=/tmp/splashtop

#
# Gather various system information
#

mkdir -p ${TMP_PATH}/system-info

# id/env/xrandr
id > ${TMP_PATH}/system-info/id.txt || true
env > ${TMP_PATH}/system-info/env.txt || true

# xrandr output list of monitors
xrandr > ${TMP_PATH}/system-info/xrandr.txt || true

# OS release
mkdir -p ${TMP_PATH}/system-info/etc
cp /etc/*version* /etc/*release* ${TMP_PATH}/system-info/etc || true

# Hardware list
mkdir -p ${TMP_PATH}/system-info/hardware
lshw -html > ${TMP_PATH}/system-info/hardware/lshw.html || true

# Kernel version
mkdir -p ${TMP_PATH}/system-info/kernel
uname -a > ${TMP_PATH}/system-info/kernel/uname_a.txt || true

# Display Manager
mkdir -p ${TMP_PATH}/system-info/display-manager
cp /etc/X11/default-display-manager ${TMP_PATH}/system-info/display-manager || true
cp /etc/systemd/system/display-manager.service ${TMP_PATH}/system-info/display-manager || true
systemctl status display-manager.service > ${TMP_PATH}/system-info/display-manager/display-manager_status.txt || true

# NetworkManager service journal
mkdir -p ${TMP_PATH}/system-info/journals
journalctl --unit=NetworkManager > ${TMP_PATH}/system-info/journals/NetworkManager.txt || true

# SRStreamer service journal
journalctl --unit=SRStreamer > ${TMP_PATH}/system-info/journals/SRStreamer.txt || true

# Auto update service journal
journalctl --unit=splashtop_streamer_auto_update.service > ${TMP_PATH}/system-info/journals/splashtop_streamer_auto_update.txt || true

#
# Systemd login manager
#
mkdir -p ${TMP_PATH}/system-info/systemd-login-manager/seats
mkdir -p ${TMP_PATH}/system-info/systemd-login-manager/users
mkdir -p ${TMP_PATH}/system-info/systemd-login-manager/sessions
mkdir -p ${TMP_PATH}/system-info/systemd-login-manager/sessions/journals

# Systemd login manager - seats
loginctl list-seats > ${TMP_PATH}/system-info/systemd-login-manager/seats/list-seats.txt || true
for seat in $(loginctl list-seats --no-legend); do
    loginctl seat-status $seat > ${TMP_PATH}/system-info/systemd-login-manager/seats/seat-status-$seat.txt || true
done

# Systemd login manager - sessions
loginctl list-sessions > ${TMP_PATH}/system-info/systemd-login-manager/sessions/list-sessions.txt || true
loginctl session-status > ${TMP_PATH}/system-info/systemd-login-manager/sessions/session-status.txt || true
for session in $(loginctl list-sessions --no-legend | awk '{ print $1 }'); do
    loginctl show-session $session > ${TMP_PATH}/system-info/systemd-login-manager/sessions/session-$session.txt || true
    journalctl --boot --unit=session-$session.scope > ${TMP_PATH}/system-info/systemd-login-manager/sessions/journals/session-$session.scope.txt || true
done

# Systemd login manager - users
loginctl list-users > ${TMP_PATH}/system-info/systemd-login-manager/users/list-users.txt || true
loginctl user-status > ${TMP_PATH}/system-info/systemd-login-manager/users/user-status.txt || true
for user in $(loginctl list-users --no-legend | awk '{ print $2 }'); do
    loginctl show-user $user > ${TMP_PATH}/system-info/systemd-login-manager/users/user-$user.txt || true
done

#
# Compress the files as system-info.tar.bz2
#
tar -C ${TMP_PATH} -cjf system-info.tar.bz2 system-info || true
rm -rf ${TMP_PATH}/system-info
