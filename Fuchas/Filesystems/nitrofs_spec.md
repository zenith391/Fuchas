# NitroFS
Numbers are ALWAYS little-endian

In case of use with OSDI, partition type is Nitro_FS

## Sizes and Computations
- Default Logical Sector Size (SS): 512
- Default Logical Sector Offset (SO): 512
- Content Address (CA) -> Physical Address: CA * SS + SO

## Head structure
The head structure contains the signature and some informations for booting, reading/writing attributes, etc. While MFSR use 30 bytes, the next entry written will be at 512, this is made for the filesystem to be synced with sectors and allow very easy and fast reads/writes.

- NTRFS1 - 6 bytes
- [OS] - 20 bytes - The OS/kernel that written attributes (to respect OS's attributes format). Current allocated are: FUCHAS, TSUKI
- [BOOT] - 2 bytes - Optional (set to 0 to ignore), CA pointing to a file that contains Lua code to execute. Pointless if using OSDI and init.lua at root directory is still a thing 
- [DIR] - CA pointing to root directory - 2 bytes - The CA by default equals 0, but is changeable
- Total MFSR size: 30 bytes

## Filesystem Structure

### Directory Entry
- D = Directory - 1 byte
- PADDING - 2 bytes - used for easier integration with file entry
- PARENT - 2 bytes (logical sector number of parent, from 0 to 65535)
- NAME - 32 bytes, note: this is not the path, the path is calculated from PARENT, the string is terminated with \0
- Attributes - 1 byte - System dependent
- NUMBER OF CHILDRENS - unsigned short
- CHILDRENS (TYPE + CA) - 3 bytes (1 for TYPE, 2 for CA) (TYPE = `D` for directory and TYPE = `F` for file)
- Childrens entry max length: 473 (or 157 childrens per directory)
Used space of empty directory: 132

An equivalent as C structure would be:
```c
struct ChildrenEntry {
	unsigned char type;
	unsigned short address;
};

struct DirectoryEntry {
	unsigned char type = 'D'; // always ASCII 'D'
	unsigned short size;
	unsigned short parent;
	unsigned char* name; // of length 32
	unsigned char attributes;
	unsigned short childrens;
	ChildrenEntry* entries;
};
```

### File Entry
- F = File - 1 byte
- SIZE - 2 bytes - size (in bytes) of this file
- PARENT - 2 bytes - parent of this file (must be a directory)
- NAME - 32 bytes
- Attributes - 1 byte - System dependent
- FRAGMENT - 2 bytes - the first fragment of the file, equals to 0 if file is empty

And as a C structure it would again give:
```c
struct FileEntry {
	unsigned char type = 'F'; // always ASCII 'F'
	unsigned short size;
	unsigned short parent;
	unsigned char* name; // of length 32
	unsigned char attributes;
	unsigned short fragment;
};
```

### Fragment Entry
- R = fRagment - 1 byte
- NEXT - 2 bytes - next fragment of the file, equals to 0 if file done
- TEXT FRAGMENT - 509 bytes

Finally, it's C structure would be:
```c
struct FragmentEntry {
	unsigned char type = 'R'; // always ASCII 'R'
	unsigned short next;
	char* text; // of length 509
};
```
