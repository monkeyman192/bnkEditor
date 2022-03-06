This structure is used in a few places.

It has the following structure:

- `uint8` -> bool - Override parent FX
- `uint8` - Number of effects
** IF `Number of effects > 0`: **
	- `uint8` - Bypass bitmask
** FOR *count* in `Number of effects`:**
	- `uint8`  - Effect index (0x00 -> 0x03)
	-	`uint32` - Effect object ID
	- `byte[2]` - Two zero bytes
** END IF **
- `uint8` - Override attachment parameters
- `uint32` - Override Bus ID
- `uint32` - Parent object ID
- `uint8` - Overrides:
	- bit 0 - Priority override parent
	- bit 1 - Priority apply distance factor
	- bit 2 - Override midi events behaviour
	- bit 3 - Override midi note tracking
	- bit 4 - Enable midi note tracking
	- bit 5 - Is midi break loop on note off
- `uint8` - Number of additional parameters
** FOR *count* in `Number of additional parameters`: **
	- `uint8` - Parameter type. One of:
		- 0x00 - float - Voice volume
		- 0x02 - float - Voice pitch
		- 0x03 - float - Voice low-pass filter
		- TODO: MORE
** FOR EACH *parameter* in above list: **
	- `datatype` - value
- TODO: Positioning data