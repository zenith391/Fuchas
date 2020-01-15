#!/bin/sh
cd dest
cd .efi/Source
find . | cpio -oHbin > "../fuchas.efi2"
cd ../..
find Fuchas Users/Shared .efi | cpio -oHbin > "release.cpio"
