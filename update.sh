#!/bin/bash
sudo rm -rf /var/lib/dpkg/lock-frontend
sudo rm -rf /var/lib/dpkg/lock
sudo aptitude update
sudo aptitude upgrade -y
sudo aptitude -o Aptitude::Delete-Unused=1 install
sudo -u homeassistant -H -s bash -c '/srv/homeassistant/bin/python -m pip install --upgrade homeassistant'
