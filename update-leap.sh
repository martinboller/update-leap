#!/bin/bash

#####################################################################
#                                                                   #
# Author:       Martin Boller                                       #
#                                                                   #
# Email:        martin@bollers.dk                                   #
# Last Update:  2019-06-17                                          #
# Version:      1.00                                                #
#                                                                   #
# Changes:  intitial update-leap service creator                    #
#                                                                   #
# Usage:    Installs systemd timer and service                      #
#           To update leap-seconds file at regular                  #
#           intervals                                               #
#                                                                   #
#####################################################################


configure_update_leap() {
    echo -e "\e[32mconfigure_update-leap()\e[0m";
    echo -e "\e[36m-Creating service unit file\e[0m";

    sudo sh -c "cat << EOF  > /lib/systemd/system/update-leap.service
# service file running update-leap
# triggered by update-leap.timer

[Unit]
Description=service file running update-leap
Documentation=man:update-leap

[Service]
User=ntp
Group=ntp
ExecStart=-/usr/bin/update-leap -F -f /etc/ntp.conf -s http://www.ietf.org/timezones/data/leap-seconds.list /var/lib/ntp/leap-seconds.list
WorkingDirectory=/var/lib/ntp/

[Install]
WantedBy=multi-user.target
EOF";

   echo -e "\e[36m-creating timer unit file\e[0m";

   sudo sh -c "cat << EOF  > /lib/systemd/system/update-leap.timer
# runs update-leap Weekly.
[Unit]
Description=Weekly job to check for updated leap-seconds.list file
Documentation=man:update-leap

[Timer]
# Don't run for the first 15 minutes after boot
OnBootSec=15min
# Run Weekly
OnCalendar=Weekly
# Specify service
Unit=update-leap.service

[Install]
WantedBy=multi-user.target
EOF";
    sync;
    echo -e "\e[36m-Get initial leap file making sure timer and service can run\e[0m";
    wget -O /var/lib/ntp/leap-seconds.list http://www.ietf.org/timezones/data/leap-seconds.list;
    # Telling NTP where the leapseconds file is
    echo "leapfile /var/lib/ntp/leap-seconds.list" | tee -a /etc/ntp.conf;
    sudo systemctl daemon-reload;
    sudo systemctl enable update-leap.timer;
    sudo systemctl enable update-leap.service;
    sudo systemctl daemon-reload;
    sudo systemctl start update-leap.timer;
    sudo systemctl start update-leap.service;
    /usr/bin/logger 'configure_update-leap()' -t 'update-leap';
}

#################################################################################################################
## Main Routine                                                                                                 #
#################################################################################################################

main() {
# Install NTP tools
install_ntp_tools;
# Create and configure systemd unit files to update leapseconds file
configure_update_leap;
# Add other stuff to install here as required

## Finish with encouraging message
echo -e "\e[32mInstallation and configuration of update-leap complete.\e[0m";
echo -e;
}

main;

exit 0