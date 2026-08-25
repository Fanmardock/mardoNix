#!/bin/bash
set -ouex pipefail

if [ -f /etc/pam.d/greetd ]; then
    sed -i -E 's/^-([a-z]+[[:space:]]+.*pam_gnome_keyring\.so)/\1/' /etc/pam.d/greetd
fi

systemctl enable power-profiles-daemon.service
systemctl enable bluetooth.service
systemctl enable podman.socket

mkdir -p /usr/lib/udev/rules.d
cat > /usr/lib/udev/rules.d/99-bluetooth-rfkill.rules << 'EOF'
SUBSYSTEM=="rfkill", ATTR{type}=="bluetooth", RUN+="/usr/sbin/rfkill unblock bluetooth"
EOF

mkdir -p /usr/share/polkit-1/rules.d
cat > /usr/share/polkit-1/rules.d/99-bluetooth-dms.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.set-rfkill-state" ||
         action.id.indexOf("org.bluez.") === 0) &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# Greetd setup
mkdir -p /etc/greetd/
cat > /etc/greetd/config.toml << EOF
[terminal]
vt = "next"

[default_session]
user = "greeter"
command = "dms greeter --command niri"
EOF
chmod 0755 /etc/greetd
chown -R root:root /etc/greetd

cat > /usr/lib/sysusers.d/greetd.conf << EOF
g video 44 -
g render 989 -
u greeter - "Greetd Greeter" - /usr/sbin/nologin
m greeter video
m greeter render
EOF

# Permessi cache per DMS Greeter
mkdir -p /var/cache/dms
mkdir -p /usr/lib/tmpfiles.d

cat > /usr/lib/tmpfiles.d/dms.conf << EOF
d /var/cache/dms 0770 greeter greeter - -
Z /var/cache/dms 0770 greeter greeter - -
EOF

# Abilitazione Display Manager (greetd)
systemctl enable --force greetd.service
