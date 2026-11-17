#!/bin/sh
# ipa.sh deletes every IPA in packages/, so move each one out
mkdir -p out
for v in 1.15.11 1.8.7; do
    make clean package APOLLO_VERSION=$v && mv packages/*.ipa out/
done
make clean
