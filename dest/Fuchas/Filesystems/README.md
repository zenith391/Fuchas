# Filesystems
Here are all unmanaged drive filesystems supported by Fuchas.
Note: Manually using filesystems api is non-recommended as they use local pathes instdead of absolute one
(like A:/test.txt, here it would be test.txt)

Filesystems must return in the following order: their name, is the drive formatted with this filesystem, filesystem library
## Library Structure
The library must contains the following methods:
- format(addr) - Formats the drive
- asFilesystem(addr) - return this filesystem as a "filesystem" component (like if the drive was in Managed mode)
- isDirectory(addr, path)
- isFile(addr, path)
- getMaxFileNameLength() - returns max length of a file name
- exists(addr, path)
- makeDirectory(addr, path)
- isValid(addr) - returns `true` if the drive at addr is compatible with the formated filesystem (basically check signature)
- open(addr, path, mode) - return a *file object* with the mode or nil + error message if error, if mode is "w" and file doesn't exists, then create it
Note: if a file is arleady opened and not yet closed, open(mode) will return nil with error message "file arleady opened",
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