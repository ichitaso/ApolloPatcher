#!/bin/sh
# ipa.sh deletes every IPA in packages/, so move each one out
mkdir -p out
rm -f out/*.ipa
for v in 1.15.11 1.8.7; do
    make clean package APOLLO_VERSION=$v && mv packages/*.ipa out/
done
make clean
# App extensions make sideloading tools warn and need extra App IDs.
# Keep a _full copy of 1.15.11 for paid developer certificates.
for f in out/*.ipa; do
    case "$f" in *1.15.11*) cp "$f" "${f%.ipa}_full.ipa" ;; esac
    zip -dq "$f" "Payload/Apollo.app/PlugIns/*"
done
