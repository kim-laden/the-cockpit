# Hardware overview (cockpit-hardware)

A local, read-only report: system, CPU threads, RAM, graphics and network
controllers with the driver in use (Linux), current OpenGL renderer (Linux),
graphics chipset (macOS/Windows), Wi-Fi interface modes (Linux) and which helper
tools are available.

What it never does:
- send anything over the network
- print MAC/IP addresses, serial numbers, UUIDs or PCI bus addresses
- change drivers, CPU governors, clocks, GPU selection or display layout
- scan nearby networks or devices

Missing tools (lspci, iw, glxinfo) just mean less detail. A "software OpenGL
renderer" note means GPU acceleration may be unavailable; it is advice, not a fault.
Run `cockpit-hardware.py --json` for machine-readable output.
