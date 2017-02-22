#!/bin/bash

USER=${MONGODB_USER:-"admin"}
DATABASE=${MONGODB_DATABASE:-"admin"}
PASS=${MONGODB_PASS:-$(pwgen -s 12 1)}
_word=$( [ ${MONGODB_PASS} ] && echo "preset" || echo "random" )

RET=1
while [[ RET -ne 0 ]]; do
    echo "=> Waiting for confirmation of MongoDB service startup"
    sleep 5
    mongo admin --eval "help" >/dev/null 2>&1
    RET=$?
done


echo "=> Set authSchema version to 3"
mongo admin --eval "db.system.users.remove({})"
mongo admin --eval "db.system.version.remove({})"
mongo admin --eval "db.system.version.insert({ '_id' : 'authSchema', 'currentVersion' : 3 })"

echo "=> Creating an ${USER} user with a ${_word} password in MongoDB"
mongo admin --eval "db.createUser({user: '$USER', pwd: '$PASS', roles:[{role:'root',db:'admin'}]});"

if [ "$DATABASE" != "admin" ]; then
    echo "=> Creating an ${USER} user with a ${_word} password in MongoDB"
    mongo admin -u $USER -p $PASS << EOF
use $DATABASE
db.createUser({user: '$USER', pwd: '$PASS', roles:[{role:'dbOwner',db:'$DATABASE'}]})
EOF
fi

echo "=> Done"
touch /mongodb/data/db/.mongodb_password_set

echo "Restart mongod"
mongod --dbpath /mongodb/data/db --shutdown
mongodb_cmd="mongod --smallfiles --storageEngine $STORAGE_ENGINE --dbpath /mongodb/data/db"
cmd="$mongodb_cmd --master --auth"

if [ "$JOURNALING" == "no" ]; then
    cmd="$cmd --nojournal"
fi

if [ "$OPLOG_SIZE" != "" ]; then
    cmd="$cmd --oplogSize $OPLOG_SIZE"
fi

$cmd

echo "========================================================================"
echo "You can now connect to this MongoDB server using:"
echo ""
echo "    mongo $DATABASE -u $USER -p $PASS --host <host> --port <port>"
echo ""
echo "Please remember to change the above password as soon as possible!"
echo "========================================================================"
