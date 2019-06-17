#!/bin/bash

#####################################################################
#                                                                   #
# Author:       Martin Boller                                       #
#                                                                   #
# Email:        martin@bollers.dk                                   #
# Last Update:  2019-06-17                                          #
# Version:      1.10                                                #
#                                                                   #
# Changes:  intitial update-leap service creator (1.00)             #
#           Added ntp/timesyncd/dhcp functions (1.10)               #
#                                                                   #
# Usage:    Installs systemd timer and service                      #
#           To update leap-seconds file at regular                  #
#           intervals                                               #
#                                                                   #
#####################################################################

install_ntp() {
    echo -e "\e[32minstall_ntp()\e[0m";
    export DEBIAN_FRONTEND=noninteractive;
    sudo apt-get update;
    sudo apt-get -y install ntp;
    sudo systemctl daemon-reload;
    sudo systemctl enable ntp.service;
    sudo systemctl start ntp.service;
    /usr/bin/logger 'install_ntp()' -t 'Stratum1 NTP Server';
}

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

disable_timesyncd() {
    echo -e "\e[32mDisable_timesyncd()\e[0m";
    sudo systemctl stop systemd-timesyncd
    sudo systemctl daemon-reload
    sudo systemctl disable systemd-timesyncd
    /usr/bin/logger 'disable_timesyncd()' -t 'Stratum1 NTP Server';
}

configure_dhcp_ntp() {
    echo -e "\e[32mconfigure_dhcp()\e[0m";
    ## Remove ntp and timesyncd exit hooks to cater for server using DHCP
    echo -e "\e[36m-Remove scripts utilizing DHCP\e[0m";
    sudo rm /etc/dhcp/dhclient-exit-hooks.d/ntp
    sudo rm /etc/dhcp/dhclient-exit-hooks.d/timesyncd
    ## Remove ntp.conf.dhcp if it exist
    echo -e "\e[36m-Removing ntp.conf.dhcp\e[0m";    
    sudo rm /run/ntp.conf.dhcp
    ## Disable NTP option for dhcp
    echo -e "\e[36m-Disable ntp_servers option from dhclient\e[0m";   
    sudo sed -i -e "s/option ntp_servers/#option ntp_servers/" /etc/dhcpcd.conf;
    ## restart NTPD yet again after cleaning up DHCP
    sudo systemctl restart ntp
    /usr/bin/logger 'configure_dhcp()' -t 'Stratum1 NTP Server';
}

#################################################################################################################
## Main Routine                                                                                                 #
#################################################################################################################

main() {
    # Install NTP
    install_ntp;

    # Install NTP tools
    install_ntp_tools;

    # Disable timesyncd to let ntp take care of time
    disable_timesyncd;

    # Ensure that DHCP does not affect ntp - do make sure that valid ntp servers are configured in ntp.conf
    configure_dhcp_ntp:

    # Create and configure systemd unit files to update leapseconds file
    configure_update_leap;

    # Add other stuff to install here as required

    ## Finish with encouraging message
    echo -e "\e[32mInstallation and configuration of NTP and update-leap complete.\e[0m";
    echo -e;
}

main;

exit 0