!#/bin/bash
sudo apt-get remove libappstream3
sudo apt-get update

#Install Guest Additions
sudo mount -o loop,ro ~/VBoxGuestAdditions.iso /mnt/
sudo /mnt/VBoxLinuxAdditions.run || :
sudo umount /mnt/
rm -f ~/VBoxGuestAdditions.iso

sudo apt-get install dpkg

#Specify which file of ATOM to download (in this case 64.deb)
toBeDownloaded=$(curl -L https://api.github.com/repos/atom/atom/releases/latest | grep browser_download_url | grep '64[.]deb' |  cut -d '"' -f 4)
wget "$toBeDownloaded"
sudo dpkg -i atom-amd64.deb

