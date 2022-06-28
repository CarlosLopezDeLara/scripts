#!/usr/bin/env bash

### Pass as an argument the number of the pool that yoou want to update: 1,2 or 3

set -e
# Unofficial bash strict mode.
# See: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -u
set -o pipefail

mkdir -p tmp

echo "Querying on-chain counter value"
currentKesPeriod=
currentCounter=$(cardano-cli query kes-period-info --testnet-magic 42 --op-cert-file node-spo"$1"/opcert.cert --out-file tmp/kesperiod.json | jq .qKesNodeStateOperationalCertificateNumber tmp/kesperiod.json)
currentKesPeriod=$(jq .qKesCurrentKesPeriod tmp/kesperiod.json)
nextCounter=$((1 + "$currentCounter"))

echo "Current on-chain counter:" "$currentCounter"
echo "Issue new certificate with counter:" "$nextCounter"
echo "Current KES period:" "$currentKesPeriod"

while true; do
    read -p "Do you wish to generate new temporary counter?" yn
    case $yn in
        [Yy]* ) cardano-cli node new-counter \
        --cold-verification-key-file pools/cold"$1".vkey \
        --counter-value "$nextCounter" \
        --operational-certificate-issue-counter-file tmp/opcert"$1".counter; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    read -p "Do you wish to renew KES keys?" yn
    case $yn in
        [Yy]* ) rm pools/kes"$1".vkey
                cardano-cli node key-gen-KES --verification-key-file pools/kes"$1".vkey --signing-key-file pools/kes"$1".skey; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    read -p "Do you wish to issue new OpCert?" yn
    case $yn in
        [Yy]* ) cardano-cli node issue-op-cert --kes-verification-key-file pools/kes"$1".vkey \
        --cold-signing-key-file pools/cold"$1".skey \
        --operational-certificate-issue-counter-file tmp/opcert"$1".counter \
        --kes-period "$currentKesPeriod" \
        --out-file node-spo"$1"/opcert.cert; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "Deleting old KES skey from BP node"
sleep 3
rm node-spo"$1"/kes.skey

echo "Moving New KES skey to BP node"
sleep 3
mv pools/kes"$1".skey node-spo"$1"/kes.skey

echo "Deleting tmp folder and files: opcert.counter and kesperiod.json"
sleep 3
rm -Rf tmp

echo "Restart the node now"
