# Fuchas
**Fuchas is an operating system made for the OpenComputers minecraft mod.**

Fuchas haves a lot of libraries inside it. (like shin32 or shinamp which are in the same order for multi-tasking and misc operations and for audio), the "NT" part is basically just the boot/init part, originally called by init.lua or the content inside driveinit.lua if on a unmanaged drive.
  
It is based on a driver architecture to fullfil all components, like sound drivers for allowing programs
to easily get adapter to Computronics's Sound Card or the default PC Speaker.
Shindows is capable of all that by using a different kernel from most graphical OSs made before.

Fuchas is based on drivers instdead of APIs directly interfacing with components (except for components sure they are present and core to the operations), it allows for user drives, and mostly, having programs compatible with hardware from addons mod supported by Fuchas, that's a great step forward considering that without Fuchas, each software (even on MineOS) has to support the hardware themselves. For that, Fuchas will load the most relevant hardware for the configuration (e.g., for sound, if Computronics Sound Card present, use it instdead of PC Speaker), however in case of conflicts, (following is not yet implemented) it will be able to load multiple drivers and supply them, up to the program to choose the best (or to the user if it prompts for).

Fuchas is also multitasking, it works with a "main thread" (originating from the boot), it cycles thru all active processes and execute a "tick" of them, processes should execute only a short time (a "tick", best around 20ms or lower, 50ms max for stability) long-term (more than 50ms) blocking operations (like I/O) gets a part (like 10 bytes of a file, can be set via priority (TODO)) of the work time. Basically Fuchas uses cooperative multitasking
