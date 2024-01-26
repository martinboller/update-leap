# update-leap
Small shell script to:
- install ntp-sec.
- configure with sane defaults. .env file contain some good stratum-1 servers in northern europe, replace with good ones for your location. Choose 4 to 5 as per [RFC8633}(https://datatracker.ietf.org/doc/html/rfc8633).
- create systemd unit files keeping the leapseconds file up-to-date.

This script is tested to work on Debian/Raspbian/Ubuntu. Please note that some of the file locations are different for other distros
