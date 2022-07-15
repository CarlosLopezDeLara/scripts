#!/usr/bin/env bash

# To use with scripts/babbage/mkfiles.sh cluster
# https://github.com/input-output-hk/cardano-node/blob/master/scripts/babbage/mkfiles.sh
#
# Pass as an argument the number of the pool that you want to update: 1,2 or 3

set -e
set -u
set -o pipefail

poolNo="$1"
temp=$(mktemp -d)

cardano-cli query kes-period-info \
--testnet-magic 42 \
--op-cert-file "node-spo$poolNo/opcert.cert" \
--out-file "$temp/kesperiod.json"

currentCounter=$(jq .qKesNodeStateOperationalCertificateNumber "$temp/kesperiod.json")
currentKesPeriod=$(jq .qKesCurrentKesPeriod "$temp/kesperiod.json")
nextCounter=$((1 + "$currentCounter"))

echo "Current on-chain counter: $currentCounter"
echo "Issue new certificate with counter: $nextCounter"
echo "Current KES period: $currentKesPeriod"

cardano-cli node new-counter \
--cold-verification-key-file "pools/cold$poolNo.vkey" \
--counter-value "$nextCounter" \
--operational-certificate-issue-counter-file "$temp/opcert$poolNo.counter"

rm "pools/kes$poolNo.vkey"

cardano-cli node key-gen-KES --verification-key-file "pools/kes$poolNo.vkey" \
--signing-key-file "pools/kes$poolNo.skey"

cardano-cli node issue-op-cert --kes-verification-key-file "pools/kes$poolNo.vkey" \
--cold-signing-key-file "pools/cold$poolNo.skey" \
--operational-certificate-issue-counter-file "$temp/opcert$poolNo.counter" \
--kes-period "$currentKesPeriod" \
--out-file "node-spo$poolNo/opcert.cert"

rm "node-spo$poolNo/kes.skey"
mv "pools/kes$poolNo.skey" "node-spo$poolNo/kes.skey"

rm -Rf "$temp"
echo "Restart the node now"
