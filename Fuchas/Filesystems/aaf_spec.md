## Adaptive Audio Format
Here is a proposal for OC audio format. In AAF a channel data (part of audio fragment)
can only do one action at a time, meaning a channel cannot play a note while changing
volume, setting up ADSR or changing wave type.

Here are all common data you will find:
```
Signature: <DC3> <A> <A> <F> <ETX>
Wave Type: SQUARE (0) | SINE (1) | TRIANGLE (2) | SAWTOOTH (3)
Action: WAVE (0) | ADSR (1) | VOLUME (2) | WAVETYPE (3)
```

### CAPABILITIES
```
- 
```

### Header
```
- [SIGNATURE]
- [CAPABILITIES]
- [AUDIO LENGTH] - number of audio fragment
- [AUDIO FRAGMENTS]
```

### Audio fragment
Total:
```
Channel data is organized starting from 0 up into channel number - 1
(so if 1 channel it's from 0 to 0, so one channel)
- [PER CHANNEL DATA] x (channel number)
```
Channel Data:
```
- [ACTION] - described below
If ACTION == WAVETYPE:
  - [WAVE TYPE] - described below
If ACTION == ADSR:
  - [ATTACK] - unsigned short, duration in milliseconds
  - [DELAY] - unsigned short, duration in milliseconds
  - [SUSTAIN] - unsigned short, duration in milliseconds
  - [RELEASE] - unsigned short, duration in milliseconds
If ACTION == VOLUME:
  - [VOLUME] - unsigned byte, decimal obtained by dividing by 100 (giving 100 volume levels)
If ACTION == WAVE:
  - [FREQUENCY] - unsigned short, in Hertz
  - [DURATION] - unsigned short, duration in milliseconds
```