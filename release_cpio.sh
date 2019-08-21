#!/bin/sh
find .efi/Source | cpio -oHbin > ".efi/fuchas.efi2"
find Fuchas Users/Shared zorya-modules .efi | cpio -oHbin > "release.cpio"