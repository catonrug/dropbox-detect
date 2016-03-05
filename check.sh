#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/dropbox-detect.git && cd dropbox-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

#set name
name=$(echo "Dropbox")

#this link redirects to the latest version
link=$(echo "https://www.dropbox.com/download?full=1&amp;plat=win")

#use spider mode to output all information abaout request
#do not download anything
wget -S --spider -o $tmp/output.log "$link"

#start basic check if the page even have the right content
grep -A99 "^Resolving" $tmp/output.log | grep "https.*client.*Dropbox.*Offline.*exe" > /dev/null
if [ $? -eq 0 ]; then

#take the first link which starts with http and ends with exe
url=$(grep -A99 "^Resolving" $tmp/output.log | \
sed "s/https/\nhttps/g" | \
sed "s/exe/exe\n/g" | \
grep "^https.*exe$" | head -1)

#calculate exact filename of link
filename=$(echo $url | sed "s/^.*\///g")

#check if this filename is in database
grep "$filename" $db > /dev/null
if [ $? -ne 0 ]; then
echo new version detected!

echo Downloading $filename
wget $url -O $tmp/$filename -q
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

#detect exact verison of Dropbox
version=$(echo "$filename" | sed "s/%20/\n/g" | grep "^[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+")
echo $version | grep "^[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+"
if [ $? -eq 0 ]; then
echo

echo "$filename">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version" "$url 
$md5
$sha1"
} done
echo

else
#version pattern do not work
echo version pattern do not work
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "version pattern do not work: 
$link"
} done
fi

else
#file already in database
echo file already in database
fi

else
#if output.log do not contains any 'Dropbox' filenames wich ends with exe 
#lets send emails to all people in "maintenance" file
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "The following link do not longer retreive installer: 
$link"
} done

fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
