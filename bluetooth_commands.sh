sudo hciconfig hci0 up
sudo systemctl restart bluetooth
sudo modprobe -r btusb
sudo modprobe btusb

