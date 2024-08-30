const clap = @import("clap");
const std = @import("std");

const debug = std.debug;
const io = std.io;
const allocator = std.heap.page_allocator;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

fn replace(self: []const u8, old: u8, new: u8) []const u8 {
    const buffer = std.mem.bytes(self);
    for (buffer) |*c| {
        if (c.* == old) {
            c.* = new;
        }
    }
    return buffer;
}

pub fn main() anyerror!void {
    defer _ = gpa.deinit();
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-s, --seconds <i64>    Seconds added to timespan which file will be replayed over.
        \\-m, --minutes <i64>    Minutes added to timespan which file will be replayed over.
        \\-H, --hours <i64>      Hours added to timespan which file will be replayed over.
        \\-t, --time <str>       Time added to timespan which file will be replayed over in the format XXhXXmXXs.
        \\-p, --port <u16>       The port to send the replayed file to.
        \\-i, --ip <str>    The address to send the replayed file to.
        \\-b, --buffersize <u64> The size of the buffer to send the file in.
        \\ <str>...                The file to replay.
    );
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        // Report useful error and exit
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    var timespan = TimeSpan{ .hours = 0, .minutes = 0, .seconds = 0 };
    var port: u16 = 6969;
    var buffer_size: u64 = 4096;
    // declare string, set later
    var ip: []const u8 = "127.0.0.1";

    if (res.args.help != 0)
        debug.print("--help\n", .{});
    if (res.positionals.len == 0)
        debug.print("no positionals\n", .{});
    if (res.args.seconds) |secs|
        timespan.seconds = secs;
    if (res.args.minutes) |mins|
        timespan.minutes = mins;
    if (res.args.hours) |hs|
        timespan.hours = hs;
    if (res.args.time) |time|
        timespan = try parse_timespan(time);
    if (res.args.port) |portarg|
        port = portarg;
    if (res.args.ip) |iparg|
        ip = iparg;
    if (res.args.buffersize) |bs|
        buffer_size = bs;
    for (res.positionals) |pos| {
        // open file
        const file = try open_file_readonly(pos);
        defer file.close();
        const addr = try std.net.Address.parseIp(ip, port);
        const real_path = try std.fs.realpathAlloc(allocator, pos);
        debug.print("Streaming file: {s} - over: {d} hours {d} minutes {d} seconds - to: {s}:{d}\n", .{ real_path, timespan.hours, timespan.minutes, timespan.seconds, ip, port });
        try stream_file(file, timespan, addr, buffer_size);
        debug.print("hours: {d}\n", .{timespan.hours});
        debug.print("minutes: {d}\n", .{timespan.minutes});
        debug.print("seconds: {d}\n", .{timespan.seconds});
    }
}

fn stream_file(file: std.fs.File, timespan: TimeSpan, addr: std.net.Address, buffer_size: u64) anyerror!void {
    const socket = try std.net.tcpConnectToAddress(addr);
    const file_stat = try file.stat();
    const file_size = file_stat.size;
    const total_seconds: u64 = @intCast(timespan.hours * 3600 + timespan.minutes * 60 + timespan.seconds);
    var bytes_per_seconds: u64 = 1;
    var ns_per_buffer: u64 = 0;
    debug.print("total_seconds: {d}\n", .{total_seconds});
    if (total_seconds == 0) {
        ns_per_buffer = 0;
    } else {
        // uint64.max is the max value for u64
        bytes_per_seconds = file_size / total_seconds;
        const buffers_per_seconds = bytes_per_seconds / buffer_size;
        ns_per_buffer = 1_000_000_000 / buffers_per_seconds;
    }
    const now: u64 = @intCast(std.time.nanoTimestamp());
    debug.print("ms_per_buffer: {d}\n", .{ns_per_buffer});
    var next_buffer = now + ns_per_buffer;

    const buffer = try allocator.alloc(u8, buffer_size);
    defer allocator.free(buffer);
    while (true) {
        const read = try file.read(buffer);
        if (read == 0) {
            break;
        }
        // Send buffer to addr
        try socket.writeAll(buffer[0..read]);
        const time_now: u64 = @intCast(std.time.nanoTimestamp());
        if (next_buffer > time_now) {
            const time_until_next_buffer = next_buffer - time_now;
            std.time.sleep(time_until_next_buffer);
        }
        next_buffer += ns_per_buffer;
    }
}

fn open_file_readonly(filename: []const u8) anyerror!std.fs.File {
    const open_flags = std.fs.File.OpenFlags{ .mode = .read_only };
    return try std.fs.cwd().openFile(filename, open_flags);
}

fn parse_timespan(time: []const u8) anyerror!TimeSpan {
    var hours: i64 = 0;
    var minutes: i64 = 0;
    var seconds: i64 = 0;
    const size = std.mem.replacementSize(u8, time, "h", " ");
    const time_replaced = try allocator.alloc(u8, size);
    _ = std.mem.replace(u8, time, "h", " ", time_replaced);
    _ = std.mem.replace(u8, time_replaced, "m", " ", time_replaced);
    _ = std.mem.replace(u8, time_replaced, "s", " ", time_replaced);
    var time_split = std.mem.split(u8, time_replaced, " ");
    if (time_split.next()) |x|
        hours = try std.fmt.parseInt(i64, x, 10);
    if (time_split.next()) |x|
        minutes = try std.fmt.parseInt(i64, x, 10);
    if (time_split.next()) |x|
        seconds = try std.fmt.parseInt(i64, x, 10);
    return TimeSpan{ .hours = hours, .minutes = minutes, .seconds = seconds };
}

const TimeSpan = struct {
    hours: i64,
    minutes: i64,
    seconds: i64,
};

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "parse timespan" {
    const time = "1h2m3s";
    const timespan = try parse_timespan(time);
    try std.testing.expectEqual(timespan.hours, 1);
    try std.testing.expectEqual(timespan.minutes, 2);
    try std.testing.expectEqual(timespan.seconds, 3);
}

test "parse timespan with zero pads" {
    const time = "01h02m03s";
    const timespan = try parse_timespan(time);
    try std.testing.expectEqual(timespan.hours, 1);
    try std.testing.expectEqual(timespan.minutes, 2);
    try std.testing.expectEqual(timespan.seconds, 3);
}

test "parse timespan with no minutes gives error" {
    const time = "1h3s";
    _ = parse_timespan(time) catch {
        return;
    };
    try std.testing.expect(false);
}

test "open testfile" {
    const filename = "testfile";
    _ = try open_file_readonly(filename);

    const no_file = "no_file";
    _ = open_file_readonly(no_file) catch {
        return;
    };
    try std.testing.expect(false);
}
