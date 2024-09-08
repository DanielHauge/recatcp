# Recatcp

A simple tool to replay/transmit bytes of a file on a TCP connection over a period of time.
This tool was created as a fun project to learn more about Zig and to help facilitate testing of network applications.

## Install

Clone repository and build with Zig:

```sh
git clone https://github.com/DanielHauge/recatcp.git
cd recatcp
zig build
```

Binary is then located in `zig-out/bin`, and can be copied to a location in your PATH.
Can also just be used from repository root with:

```sh
zig build run -- [options] <files...>
```

## Usage

Help:

```

Usage:
        recatcp [options] <files...>

Options:
    -h, --help
            Display this help and exit.
    -s, --seconds <i64>
            Seconds added to timespan which file will be replayed over.
    -m, --minutes <i64>
            Minutes added to timespan which file will be replayed over.
    -H, --hours <i64>
            Hours added to timespan which file will be replayed over.
    -t, --time <str>
            Time added to timespan which file will be replayed over in the format XXhXXmXXs.
    -p, --port <u16>
            The port to send the replayed file to. Defaults to 6969.
    -i, --ip <str>
            The address to send the replayed file to. Defaults to 127.0.0.1
    -b, --buffersize <u64>
            The size of the buffer to send the file in. Defaults to 32 KB (32768).
    <str>...
            The files to replay.

```

Example:

```sh
# Replay testfile byte for byte over 10 seconds to localhost (127.0.0.1) at port 1234 via tcp in chunks of 4096 bytes.
recatcp testfile1 -s 10 -p 1234 -i 127.0.0.1 -b 4096
```
