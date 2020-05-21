sudo apt-get update  
sudo apt-get upgrade 
sudo apt-get install mono-complete screen unzip  

wget https://github.com/NyxStudios/TShock/releases/download/v4.3.26/tshock_4.3.26.zip  
unzip tshock_4.3.26.zip -d tshock  

wget https://terraria.org/system/dedicated_servers/archives/000/000/036/original/terraria-server-1402.zip  
unzip terraria-server-1402.zip -d terraria-vanilla  
chmod 777 terraria-vanilla/1402/Linux/TerrariaServer* 

mv WorldFile.wld terraria-vanilla/1402/
mono-sgen terraria-vanilla/1402/Linux/TerrariaServer.exe -world terraria-vanilla/1402/WorldFile.wld  
