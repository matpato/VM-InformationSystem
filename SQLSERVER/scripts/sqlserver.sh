#   File name: sqlserver
#     Copyright (C) 2018  Matilde Pos-de-Mina Pato
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.
# ------------------------------------------------------------------------ #
# PLEASE DON'T CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING
# ------------------------------------------------------------------------ #
#!/bin/bash -e

#Based on Unattended SQL Server installation script available at https://docs.microsoft.com/en-us/sql/linux/sample-unattended-install-ubuntu?view=sql-server-2017

# Password for the SA (SYSTEM ADMINISTRATOR) user (required)
MSSQL_SA_PASSWORD='#_sa!si1'

# Product ID of the version of SQL server you're installing
# Must be evaluation, developer, express, web, standard, enterprise, or your 25 digit product key
# Defaults to developer
MSSQL_PID='developer'

# Create an additional user with sysadmin privileges (optional)
SQL_INSTALL_USER='si1su'
SQL_INSTALL_USER_PASSWORD='#_su!si1'

if [ -z $MSSQL_SA_PASSWORD ]
then
  echo Environment variable MSSQL_SA_PASSWORD must be set for unattended install
  exit 1
fi

#register Microsoft repositories
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo add-apt-repository "$(curl https://packages.microsoft.com/config/ubuntu/16.04/mssql-server-2017.list)"
sudo add-apt-repository "$(curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list)"


#install MSSQL dependencies in 18.04
wget http://archive.ubuntu.com/ubuntu/pool/main/c/ca-certificates/ca-certificates_20160104ubuntu1_all.deb
sudo dpkg -i ca-certificates_20160104ubuntu1_all.deb
rm -f ca-certificates_20160104ubuntu1_all.deb

wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/openssl_1.0.2g-1ubuntu4_amd64.deb
sudo dpkg -i openssl_1.0.2g-1ubuntu4_amd64.deb
rm -f openssl_1.0.2g-1ubuntu4_amd64.deb

sudo apt-get install -y libcurl3

#upgrade system
sudo apt-get -y update && sudo apt-get -y upgrade

#install MSSQL - server
sudo apt-get install -y mssql-server

#install MSSQL - client tools
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev

#config MSSQL
sudo MSSQL_SA_PASSWORD=$MSSQL_SA_PASSWORD \
     MSSQL_PID=$MSSQL_PID \
     /opt/mssql/bin/mssql-conf -n setup accept-eula

# Add SQL Server tools to the path by default:
echo Adding SQL Server tools to your path...
echo PATH="$PATH:/opt/mssql-tools/bin" >> /home/vagrant/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /home/vagrant/.bashrc

# Configure firewall to allow TCP port 1433:
echo Configuring UFW to allow traffic on port 1433...
sudo ufw allow 1433/tcp
sudo ufw reload

#restart mssql
sudo systemctl restart mssql-server.service


counter=1
errstatus=1
while [ $counter -le 5 ] && [ $errstatus = 1 ]
do
  echo Waiting for SQL Server to start...
  sleep 3s
  /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U SA \
    -P $MSSQL_SA_PASSWORD \
    -Q "SELECT @@VERSION" 2>/dev/null
  errstatus=$?
  ((counter++))
done

# Display error if connection failed:
if [ $errstatus = 1 ]
then
  echo Cannot connect to SQL Server, installation aborted
  exit $errstatus
fi

# Optional new user creation:
if [ ! -z $SQL_INSTALL_USER ] && [ ! -z $SQL_INSTALL_USER_PASSWORD ]
then
  echo Creating user $SQL_INSTALL_USER
  /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U SA \
    -P $MSSQL_SA_PASSWORD \
    -Q "CREATE LOGIN [$SQL_INSTALL_USER] WITH PASSWORD=N'$SQL_INSTALL_USER_PASSWORD', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF; ALTER SERVER ROLE [sysadmin] ADD MEMBER [$SQL_INSTALL_USER]"
fi

echo Done!