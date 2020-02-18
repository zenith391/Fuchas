# Filesystems
Here are all unmanaged drive filesystems supported by Fuchas.
Note: Manually using filesystems api is non-recommended as they use filesystem-relative paths instdead of absolute ones
(like A:/test.txt, here it would be test.txt)

## Words
- Medium: drive, partition, or any other with random-access reads and writes compatible with filesystem's drive API (a tape, or tape partition)

## Driver Structure
Filesystems must return in the following order: their name, is the drive formatted with this filesystem, filesystem library
The driver must contains the following methods:
- format() - Formats the drive
- asFilesystem() - return this filesystem as a "filesystem" component (like if the drive was in Managed mode)
- isDirectory(path)
- isFile(path)
- getMaxFileNameLength() - returns max length of a file name (name + dot + extension!)
- exists(path)
- makeDirectory(path)
- size(allocated) - If allocated is false or not defined, returns the USED size of a file (error for directories!), otherwise returns the ALLOCATED size of an object (file/directory)
- lastModified(path) - return the last time the object has been modified in Unix timestamp, returns -1 if feature not available.
- createdAt(path) - return the time the object has been created in Unix timestamp, returns -1 if feature not available.
- isFormatted(addr) - returns `true` if the drive at addr is formatted with the current filesystem (in most cases is equivalent to check the signature)
- open(addr, path, mode) - return a *file object* with the mode or nil + error message if error, if mode is "w" and file doesn't exists, then create it
**WARNING**: if a file is already opened and not yet closed, open(mode) will return nil and "file already opened",
this is made to avoid having files written while being read, which could cause several bugs

### Modes
It can either be "r" for read-only or "w" for write-only (from start, not append)

### File Objects
They implement the following methods:
- close(self)
- read(self, length) (Only if in "r" mode)
- write(self, str) (Only if in "w" mode) - Appends str to the file

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
