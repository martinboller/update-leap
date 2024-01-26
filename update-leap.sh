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
    /usr/bin/logger 'install_ntp()' -t 'Stratum1 NTP Server';
    echo -e "\e[32m - install_ntp()\e[0m";
    export DEBIAN_FRONTEND=noninteractive;
    echo -e "\e[36m ... installing ntp\e[0m";
    apt-get -qq -y install ntp > /dev/null 2>&1;
    /usr/bin/logger 'install_ntp() finished' -t 'Stratum1 NTP Server';
    echo -e "\e[32m - install_ntp() finished\e[0m";
}

configure_ntp() {
    echo -e "\e[32m - configure_ntp()\e[0m";
    echo -e "\e[36m ... stopping ntp.service\e[0m";
    systemctl stop ntp.service > /dev/null 2>&1;

    echo -e "\e[36m ... updating ntp.service\e[0m";
    echo -e "\e[36m ... adding \e[35mRequires gpsd.service\e[36m to ntp.service\e[0m";
    sed -i "/After=/a Requires=gpsd.service" /lib/systemd/system/ntp.service > /dev/null 2>&1;
    echo -e "\e[36m ... creating new ntp.conf\e[0m";
    cat << __EOF__  > /etc/ntpsec/ntp.conf
##################################################
#
# GPS / PPS Disciplined NTP Server @ stratum-1
#      /etc/ntpsec/ntp.conf
#
##################################################

driftfile /var/lib/ntpsec/ntp.drift

# Statistics will be logged. Comment out next line to disable
statsdir /var/log/ntpstats/
statistics loopstats peerstats clockstats
filegen  loopstats  file loopstats  type week  enable
filegen  peerstats  file peerstats  type week  enable
filegen  clockstats  file clockstats  type week  enable

# Separate logfile for NTPD
logfile /var/log/ntpd/ntpd.log
logconfig =syncevents +peerevents +sysevents +allclock

server	$NTP_SERVER_1	iburst
server	$NTP_SERVER_2	iburst
server	$NTP_SERVER_3	iburst
server	$NTP_SERVER_4	iburst
server	$NTP_SERVER_5	iburst

# Access control configuration; see /usr/share/doc/ntp-doc/html/accopt.html for
# details.  The web page <http://support.ntp.org/bin/view/Support/AccessRestrictions>
# might also be helpful.
#
# Note that restrict applies to both servers and clients, so a configuration
# that might be intended to block requests from certain clients could also end
# up blocking replies from your own upstream servers.

# By default, exchange time with everybody, but do not allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod notrap nomodify nopeer noquery

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1

# Clients from this (example!) subnet have unlimited access, but only if
# cryptographically authenticated.
#restrict $RESTRICT_NET mask $NET_MASK $TRUST_NET

# If you want to provide time to your local subnet, change the next line.
# (Again, the address is an example only.)
#broadcast $BROADCAST_ADDR

# If you want to listen to time broadcasts on your local subnet, de-comment the
# next lines.  Please do this only if you trust everybody on the network!
#disable auth
#broadcastclient
#leap file location
leapfile $LEAPFILE_DIR
__EOF__

    # Create directory for logfiles and let ntp own it
    echo -e "\e[36m ... Create directory for logfiles and let ntp own it\e[0m";
    mkdir -p /var/log/ntpd > /dev/null 2>&1;
    mkdir -p /var/log/ntpstats > /dev/null 2>&1;
    chown ntpsec:ntpsec /var/log/ntpd > /dev/null 2>&1;
    chown ntpsec:ntpsec /var/log/ntpstats > /dev/null 2>&1;   
    sync;
    ## Restart NTPD
    systemctl daemon-reload > /dev/null 2>&1;
    systemctl restart ntp.service > /dev/null 2>&1;
    echo -e "\e[32m - configure_ntp() finished\e[0m";
    /usr/bin/logger 'configure_ntp() finished' -t 'Stratum1 NTP Server';
}


configure_update_leap() {
    echo -e "\e[32m - configure_update-leap()\e[0m";
    /usr/bin/logger 'configure_update-leap()' -t 'Stratum1 NTP Server';
    echo -e "\e[36m ... Getting initial leap-seconds.list from IANA\e[0m";
    wget $LEAPFILE_URL -O /var/lib/ntpsec/leap-seconds.list > /dev/null 2>&1;
    chown -R ntpsec:ntpsec /var/lib/ntpsec/leap-seconds.list > /dev/null 2>&1;
    echo -e "\e[36m ... Creating update-leap.service unit file\e[0m";
    cat << __EOF__  > /lib/systemd/system/update-leap.service
# service file running update-leap
# triggered by update-leap.timer

[Unit]
Description=service file running update-leap
Documentation=man:update-leap

[Service]
User=ntpsec
Group=ntpsec
ExecStart=-/usr/sbin/ntpleapfetch -s $LEAPFILE_URL -f /etc/ntpsec/ntp.conf -l
WorkingDirectory=/var/lib/ntpsec/

[Install]
WantedBy=multi-user.target
__EOF__

   echo -e "\e[36m ... creating timer unit file\e[0m";

   cat << __EOF__  > /lib/systemd/system/update-leap.timer
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
__EOF__

    sync;
    echo -e "\e[36m ... downloading leap file and making sure timer and service will run\e[0m";
    chown -R ntpsec:ntpsec /var/lib/ntpsec > /dev/null 2>&1;
    systemctl daemon-reload > /dev/null 2>&1;
    echo -e "\e[36m ... enabling update-leap timer and service\e[0m";
    systemctl enable update-leap.timer > /dev/null 2>&1;
    systemctl enable update-leap.service > /dev/null 2>&1;
    echo -e "\e[36m ... starting timer and service to download leap-file\e[0m";
    systemctl start update-leap.timer > /dev/null 2>&1;
    systemctl start update-leap.service > /dev/null 2>&1;
    echo -e "\e[32m - configure_update-leap() finished\e[0m";
    /usr/bin/logger 'configure_update-leap() finished' -t 'Stratum1 NTP Server';
}

disable_timesyncd() {
    echo -e "\e[32mDisable_timesyncd()\e[0m";
    sudo systemctl stop systemd-timesyncd
    sudo systemctl daemon-reload
    sudo systemctl disable systemd-timesyncd
    /usr/bin/logger 'disable_timesyncd()' -t 'NTP Server';
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
    /usr/bin/logger 'configure_dhcp()' -t 'NTP Server';
}

#################################################################################################################
## Main Routine                                                                                                 #
#################################################################################################################

main() {
    
    # Directory of script
    export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    
    # Configure environment from .env file
    set -a; source $SCRIPT_DIR/.env;
    echo -e "\e[1;36m....env file version $ENV_VERSION used\e[0m"


    # Install NTP
    install_ntp;

    # Install NTP tools
    install_ntp_tools;

    # Disable timesyncd to let ntp take care of time
    disable_timesyncd;

    # Ensure that DHCP does not affect ntp - do make sure that valid ntp servers are configured in ntp.conf
    configure_dhcp_ntp:

    # Create and configure ntpsec with sane defaults 4+ servers
    configure_ntp;

    # Create and configure systemd unit files to update leapseconds file
    configure_update_leap;

    # Add other stuff to install here as required

    ## Finish with encouraging message
    echo -e "\e[32mInstallation and configuration of NTP and update-leap complete.\e[0m";
    echo -e;
}

main;

exit 0