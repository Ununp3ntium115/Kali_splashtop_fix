#!/bin/sh

#
# Allow GDM3 to save file to disk by changing it's dconf settings
# This is for taking screenshot of GDM greeter (login screen) in wayland mode
#
# Returns 1 if error, 0 if gsettings updated or nothing happens
#
# NOTE: Make sure to back up system files before modifying them
#

# First argument must be "true" or "false"
if [ "$1" != "true" ] && [ "$1" != "false" ]; then
    echo "sudo $0 \"true\" or \"false\""
    exit 1
fi

# Do nothing if current settings already matches first argument
GDM_DISABLE_SAVE_TO_DISK=$(DCONF_PROFILE=gdm gsettings get org.gnome.desktop.lockdown disable-save-to-disk | tr -d '\n')
if [ "$1" = "$GDM_DISABLE_SAVE_TO_DISK" ]; then
    echo "DCONF_PROFILE=gdm org.gnome.desktop.lockdown.disable-save-to-disk is already $1";
    exit 0
fi

# Must be root to proceed
if [ ${EUID:-`id -u`} != 0 ]; then
    echo "Must be root to change GDM settings"
    exit 1
fi

GDM3_GREETER_DCONF_DEFAULTS=/etc/gdm3/greeter.dconf-defaults # Only in Debian/Ubuntu distros
DCONF_GDM_SETTINGS_DEFAULT=/usr/share/gdm/greeter-dconf-defaults
DCONF_DB_GDM_DIR=/etc/dconf/db/gdm.d
DCONF_DB_GDM_LOCKS_DIR=/etc/dconf/db/gdm.d/locks
DCONF_GDM_SETTINGS=/etc/dconf/db/gdm.d/00-disable-save-to-disk-set-to-false
DCONF_GDM_SETTINGS_LOCK=/etc/dconf/db/gdm.d/locks/00-disable-save-to-disk-locked
DCONF_GDM_PROFILE=/etc/dconf/profile/gdm
DCONF_GDM_PROFILE_DEFAULT=/usr/share/dconf/profile/gdm
REBOOT_REQUIRED="0"
if [ "$1" = "false" ]; then
    if [ -f $GDM3_GREETER_DCONF_DEFAULTS ]; then
        # This is Debian/Ubuntu
        REBOOT_REQUIRED="1"
        echo "Set gdm's gsettings org.gnome.desktop.lockdown.disable-save-to-disk to $1"

        # Back up GDM3_GREETER_DCONF_DEFAULTS with a random suffix
        bak_file=$(mktemp "$GDM3_GREETER_DCONF_DEFAULTS.XXXXXXXXX")
        set -x
        cp $GDM3_GREETER_DCONF_DEFAULTS $bak_file
        printf "\n[org/gnome/desktop/lockdown]\ndisable-save-to-disk=false\n" >>$GDM3_GREETER_DCONF_DEFAULTS
        set +x
    else
        # This is Fedora/CentOS/RHEL
        if [ -f $DCONF_GDM_SETTINGS_DEFAULT ]; then
            REBOOT_REQUIRED="1"
            echo "Set gdm's gsettings org.gnome.desktop.lockdown.disable-save-to-disk to $1"

            # 1. Make sure /etc/dconf/db/gdm.d/locks and parent directories exists (Fedora needs this)
            mkdir -p $DCONF_DB_GDM_LOCKS_DIR

            # 2. Create new DCONF_GDM_SETTINGS and DCONF_GDM_SETTINGS_LOCK
            rm -f $DCONF_GDM_SETTINGS
            touch $DCONF_GDM_SETTINGS

            set -x
            printf "[org/gnome/desktop/lockdown]\ndisable-save-to-disk=false\n" >>$DCONF_GDM_SETTINGS
            set +x

            rm -f $DCONF_GDM_SETTINGS_LOCK
            touch $DCONF_GDM_SETTINGS_LOCK
            set -x
            printf "/org/gnome/desktop/lockdown/disable-save-to-disk\n" >>$DCONF_GDM_SETTINGS_LOCK
            set +x

            # 3. Create dconf profile 'gdm', if not exist
            if [ ! -f $DCONF_GDM_PROFILE ]; then
                # DCONF_GDM_PROFILE not exist ...
                if [ -f $DCONF_GDM_PROFILE_DEFAULT ]; then
                    # Copy from template
                    set -x
                    cp $DCONF_GDM_PROFILE_DEFAULT $DCONF_GDM_PROFILE
                    set +x
                else
                    # No template, create one with minimum contents
                    set -x
                    touch $DCONF_GDM_PROFILE
                    printf "user-db:user\n" >>$DCONF_GDM_PROFILE
                    printf "file-db:$DCONF_GDM_SETTINGS_DEFAULT\n" >>$DCONF_GDM_PROFILE
                    set +x
                fi
            else
                # DCONF_GDM_PROFILE exists, back it up with a random suffix
                bak_file=$(mktemp "$DCONF_GDM_PROFILE.XXXXXXXXX")
                set -x
                cp $DCONF_GDM_PROFILE $bak_file
                set +x
            fi

            # 4. Make sure "system-db:gdm" is the last line in DCONF_GDM_PROFILE to override settings
            set -x
            sed -i '/system-db:gdm/d' $DCONF_GDM_PROFILE
            printf "system-db:gdm\n" >>$DCONF_GDM_PROFILE
            set +x

            # 4. Update dconf database
            set -x
            dconf update
            set +x
        fi

    fi
elif [ "$1" = "true" ]; then
    if [ -f $GDM3_GREETER_DCONF_DEFAULTS ]; then
        # This is Debian/Ubuntu
        REBOOT_REQUIRED="1"
        echo "Set gdm's gsettings org.gnome.desktop.lockdown.disable-save-to-disk to $1"

        # Back up GDM3_GREETER_DCONF_DEFAULTS with a random suffix
        bak_file=$(mktemp "$GDM3_GREETER_DCONF_DEFAULTS.XXXXXXXXX")

        set -x
        cp $GDM3_GREETER_DCONF_DEFAULTS $bak_file
        sed -i '/^\[org\/gnome\/desktop\/lockdown\]/d' $GDM3_GREETER_DCONF_DEFAULTS
        sed -i '/^disable-save-to-disk=false$/d' $GDM3_GREETER_DCONF_DEFAULTS
        set +x
    else
        # This is Fedora/CentOS/RHEL
        if [ -f $DCONF_GDM_SETTINGS ]; then
            REBOOT_REQUIRED="1"
            echo "Set gdm's gsettings org.gnome.desktop.lockdown.disable-save-to-disk to $1"

            set -x
            # These files are created by this script, no need to backup?
            rm -f $DCONF_GDM_SETTINGS
            rm -f $DCONF_GDM_SETTINGS_LOCK
            dconf update
            set +x
        fi
    fi
fi

exit 0
