# Fuchas
**Fuchas is an operating system made for the OpenComputers minecraft mod.**

![image](http://gamexmc.000webhostapp.com/misc/fuchas.png)

Fuchas haves a lot of libraries inside it. (like shin32 or shinamp which are in the same order for multi-tasking and misc operations and for audio), the "NT" part is basically just the boot/init part, originally called by init.lua or the content inside driveinit.lua if on a unmanaged drive.

Fuchas is based on drivers instdead of APIs directly interfacing with components (except for components sure they are present and core to the operations), it allows for user drives, and mostly, having programs compatible with hardware from addons mod supported by Fuchas, that's a great step forward considering that without Fuchas, each software (even on MineOS) has to support the hardware themselves. For that, Fuchas will load the most relevant hardware for the configuration (e.g., for sound, if Computronics Sound Card present, use it instdead of PC Speaker), however in case of conflicts, (following is not yet implemented) it will be able to load multiple drivers and supply them, up to the program to choose the best (or to the user if it prompts for).

Fuchas is also multitasking, it works with a "main thread" (originating from the boot), it cycles through all active processes and execute a "tick" of them, processes's tick should only last a short time (a "tick", best around 20ms or lower, 50ms max for stability). (TODO ->) Long-term (more than 50ms) blocking operations (like I/O) gets a part (like 10 bytes of a file, can be set via priority) of the work time. Basically Fuchas uses cooperative multitasking