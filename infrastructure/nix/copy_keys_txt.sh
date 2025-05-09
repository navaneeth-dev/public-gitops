#!/bin/sh

mkdir -p var/lib/sops-nix
cp $HOME/.config/sops/age/keys.txt var/lib/sops-nix/key.txt
