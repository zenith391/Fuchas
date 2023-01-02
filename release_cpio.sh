#!/bin/sh
cd .efi/Source
find . | cpio -oHbin > "../fuchas.efi2"
cd ../..
find Fuchas Users/Shared/Libraries Users/Shared/account.lon Users/Shared/Binaries/stardust.lua .efi | cpio -oHbin > "release.cpio"
cd ..
