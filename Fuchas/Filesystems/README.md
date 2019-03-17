# Filesystems
Here are all unmanaged drive filesystems supported by Fuchas.
Note: Manually using filesystems api is non-recommended as they use local pathes instdead of absolute one
(like A:/test.txt, here it would be test.txt)

Filesystems must return in the following order: their name, is the drive formatted with this filesystem, filesystem library
## Library Structure
The library must contains the following methods:
- format(name) - Formats the drive and set label to name
- asFilesystem() - return this filesystem as a "filesystem" component (like if the drive was in Managed mode)
- isDirectory(path)
- isFile(path)
- getMaxFileNameLength()
- exists(path)
- open(path, mode) - return a *file object* with the mode or nil + error message if error, if mode is "w" and file doesn't exists, then create it
Note: if a file is arleady opened and not yet closed, open(mode) will return nil with error message "file arleady opened",
this is made to avoid having files written while being read, which could cause several bugs
### Modes
It can either be "r" for read-only or "w" for write-only (from start, not append)

### File Objects
They implement the following methods:
- close(self)
- read(self, length) (Only if in "r" mode)
- write(self, str) (Only if in "w" mode) - Writes str at the start of the file

Examples:
```lua
local fs = ...

-- Write "Hello Fuchas!"
local file = fs.open("test.txt", "w")
file:write("Hello Fuchas!")
file:close()

file = fs.open("test.txt", "r")
print(file:read(math.huge)) -- value higher than file size will automatically be set to file size
file:close() -- never forget to close
```
## Others
The first filesystem should be OCFS.
### OCFS specification (not yet published on forum)
NOTE THAT A CORRECT IMPLEMENTATION SHOULDN'T RELY ON SECTOR SIZE FOR ENTRIES, REMEMBER SECTORS SIZE CAN VARY

([CODE] is before filesystem header+data to ensure compatibility with most of BIOS supporting unmanaged mode)
Also, with 2 bytes for default logical sector position, "only" 32 MiB can be used
so, if a file/directory is created after all 65535 addresses are used,
due to some I/O logic, it will revert to 0, that will hopefully
stay ok, but if it's a file or a directory with more than 2 childrens,
or if we create a new one, it will erase root directory, and make the fs unusable :|
For this reason, i would recommend people which implement OCFS to use only the first 32 MiB of the drive.

Default Logical Sector Size: 512
Default Logical Sector Offset: 1031
MFSR (Master File System Record):

[CODE] - 1024 bytes ( only 512 used by advancedLoader :( )
OCFS1 - 5 bytes
[DIR] - 2 byte (Root Directory) (multiply by default logical sector size and aff offset to get address)
MFSR size (without padding and code): 8 bytes

Directory Entry:
D = Directory - 1 byte
SIZE - 2 bytes - size (in bytes) of this directory entry
PARENT - 2 bytes (logical sector number of parent, from 0 to 65535)
NAME - 32 bytes, note: this is not the path, the path is calculated from PARENT)
NUMBER OF CHILDRENS - 2 bytes
CHILDRENS (ID + SECTOR) - 3 bytes (1 for ID, 2 for SECTOR, 128 for NAME) (ID = 1 for directory and ID = 2 for file)
Childrens entry max length: 474 (or 158 childrens per directory)

Size of empty directory: 133

File Entry:
F = File - 1 byte
SIZE - 2 bytes - size (in bytes) of this file's fragment
PARENT - 2 bytes - parent of this file (must be a directory)
NAME - 32 bytes
FRAGMENT - 474 bytes
NEXT - 2 bytes - next sector of file entry (with different fragment), equals to 0 if file done
