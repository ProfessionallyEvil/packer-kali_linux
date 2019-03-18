#!/bin/bash

# this sets the dock to a fixed width instead of autohiding.
# you can change it to false if you want to make it autohide
dconf write /org/gnome/shell/extensions/dash-to-dock/dock-fixed true

# this disables the power settings so the screen doesn't auto lock
gsettings set org.gnome.desktop.session idle-delay 0

# disable sleeping
# on battery
# gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
# plugged in
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
