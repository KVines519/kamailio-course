#  PROCEED WITH CAUTION - as this will delete the db folder 
#  This script will provide the initial database config
#  needed to start kamailio from the main branch w/out starting from the first course/branch

# Shutdown docker-compose  
echo "*Shutdown the docker compose environment*"
docker compose down
#
echo "*Deleting the DB volume*"
sudo rm -rf db

#obtain the minimal config to start kamailio
echo "*Obtaining the Kamailio Minimal Config and renaming to kamailio.cfg*"
curl https://raw.githubusercontent.com/kamailio/kamailio/master/misc/examples/mixed/kamailio-minimal-proxy.cfg -o ./kamailio-default/etc/kamailio/kamailio.cfg

# Run the Docker container
echo "*Starting Docker the inital DB will be created, yet blank* "
docker compose up --build -d

# FIX: Leverage Docker's native health status instead of testing the raw ping port
echo "*Waiting for MySQL to finish its multi-stage first-boot initialization...*"
until [ "$(docker inspect --format='{{.State.Health.Status}}' db01)" = "healthy" ]; do
    echo -n "."
    sleep 2
done
echo ""
echo "*MySQL is completely responsive, healthy, and ready for production commands!*"
echo "*Waiting 30 seconds anyway...becuase fuck Gemini!*"
sleep 30

# Force the kamailio user to use native passwords and require a valid TLS channel
echo "*Upgrading Kamailio user authentication profile*"
# FIX: Use localhost to firmly match MySQL's internal administrative root mappings
docker exec db01 mysql -h localhost -u root -p=rw_password -e \
"ALTER USER 'kamailio'@'%' IDENTIFIED WITH mysql_native_password BY 'kamailiorw' REQUIRE SSL; FLUSH PRIVILEGES;"

# Run kamdbctl create inside the Docker container
echo "*RECREATE AND REINIT THE KAMAILIO DB*" 
docker exec kamailio-edge sh -c  "yes y | kamdbctl reinit kamailio"

# add the RTPEngine instance to the DB
echo "*ADDING RTPENGINE TO THE DB" 
docker exec kamailio-edge sh -c "query=\$(cat /etc/kamailio/sql/rtpengine.sql) ; kamctl db exec \"\$query\""

# create a few registered users
echo "*creating registered users*"
docker exec kamailio-edge kamctl add b2bua_external@192.168.254.100 password1
docker exec kamailio-edge kamctl add b2bua_internal_01@172.16.254.100 password1

# setup dispatcher entires
echo "*adding dispatchers*"
docker exec kamailio-edge sh -c "kamctl dispatcher add 1 sip:172.16.254.100:5060 0 0 '' 'internal_b2bua_01'"
docker exec kamailio-edge sh -c "kamctl dispatcher add 1 sip:172.16.254.101:5060 0 0 '' 'internal_b2bua_02'"

# Production Hardening: Re-enable global strict TLS/Secure Transport enforcement via runtime SQL
echo "*Enforcing strict production-grade TLS secure transport*"
docker exec db01 mysql -h localhost -u root -p=rw_password -e \
"SET GLOBAL require_secure_transport = ON;"

# Move the proper file back to kamailio.cfg
echo "*Obtaining the proper kamailio.cfg*"
curl https://raw.githubusercontent.com/KVines519/kamailio-course/main/kamailio-default/etc/kamailio/kamailio.cfg -o ./kamailio-default/etc/kamailio/kamailio.cfg

docker restart kamailio-edge
