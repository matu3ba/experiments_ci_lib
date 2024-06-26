//! CI tcp server is started with configuration file to control child processes
//! for various tasks. Tasks are send by clients via simple request files
//! (SIMREQFILE). For (initial) implementation SIMREQFILE must be encoded as ASCII.

// TODO ensure file_size is little endian now matter what

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const mem = std.mem;
const net = std.net;

pub const SimReqFileInitError = error{
    OutOfBuffer,
    BufferContentTooShort,
    InvalidFormat,
    VersionNotSupported,
    ContentLengthMismatch,
} || std.fmt.ParseIntError;

pub const SimReqFileStrError = error{
    OutOfBuffer,
    BufferContentTooShort,
};

pub const SimReqFile = struct {
    // static for now
    const version = "0000000000000000";
    file_size: u32 = undefined,
    file_content: []const u8 = undefined,

    // | SOH | 16B version | 4B file size | STX | file content | ETX | EM |
    // | 1B  | 16B         | 4B           | 1B  | variable     | 1B  | 1B |
    pub fn init(stream_content: []const u8) SimReqFileInitError!SimReqFile {
        if (stream_content.len > std.math.maxInt(u32)) return error.OutOfBuffer;
        if (stream_content.len < 24) return error.BufferContentTooShort;
        // Check for SOH, STX, ETX and EM
        if (stream_content[0] != 1 and stream_content[21] != 2 and stream_content[stream_content.len - 2] != 3 and stream_content[stream_content.len - 1] != 25) return error.InvalidFormat;
        if (!std.mem.eql(u8, stream_content[1..17], "0000000000000000")) return error.VersionNotSupported;
        const claimed_content_len = std.mem.bytesAsValue(u32, stream_content[17..21]);
        if ((stream_content.len - 2 - 22) != claimed_content_len.*) return error.ContentLengthMismatch;

        return .{
            .file_size = claimed_content_len.*,
            .file_content = stream_content[22 .. stream_content.len - 2],
        };
    }

    pub fn asStr(buf: []u8, file_content: []const u8) SimReqFileStrError![]u8 {
        // | SOH | 16B version | 4B file size | STX | file content | ETX | EM |
        if (file_content.len > std.math.maxInt(u32)) return error.OutOfBuffer;
        if (buf.len < file_content.len + 24) return error.BufferContentTooShort;
        const file_size: u32 = @intCast(file_content.len);
        buf[0] = 1;
        @memcpy(buf[1..17], SimReqFile.version);
        @memcpy(buf[17..21], &std.mem.toBytes(file_size));
        buf[21] = 2;
        @memcpy(buf[22 .. 22 + file_content.len], file_content[0..]);
        buf[22 + file_content.len] = 3;
        buf[22 + file_content.len + 1] = 0x1b;
        return buf[0 .. file_content.len + 24];
    }
};

test "SimReqFile.init" {
    // | SOH | 16B version | 4B file size | STX | file content | ETX | EM |
    // "\x00\x00\x00\x04"
    const stream1 = "\x01" ++ "0000000000000000" ++ "\x04\x00\x00\x00" ++ "\x02" ++ "\x01\x02\x03\x04" ++ "\x03\x1b";
    var reqf1 = try SimReqFile.init(stream1);
    _ = &reqf1;
    const stream2 = "\x01" ++ "0000000000000000" ++ "\x02\x00\x00\x00" ++ "\x02" ++ "\x01\x02" ++ "\x03\x1b";
    var reqf2 = try SimReqFile.init(stream2);
    _ = &reqf2;
}

test "SimReqFile.asStr" {
    // | SOH | 16B version | 4B file size | STX | file content | ETX | EM |
    // "\x00\x00\x00\x04"
    var buf: [256]u8 = undefined;
    const fcontent1 = "\x01\x02\x03\x04";
    const stream1 = try SimReqFile.asStr(buf[0..], fcontent1);
    const want_stream1 = "\x01" ++ "0000000000000000" ++ "\x04\x00\x00\x00" ++ "\x02" ++ "\x01\x02\x03\x04" ++ "\x03\x1b";
    try std.testing.expectEqualSlices(u8, want_stream1, stream1);

    const fcontent2 = "\x01\x02";
    const stream2 = try SimReqFile.asStr(buf[0..], fcontent2);
    const want_stream2 = "\x01" ++ "0000000000000000" ++ "\x02\x00\x00\x00" ++ "\x02" ++ "\x01\x02" ++ "\x03\x1b";
    try std.testing.expectEqualSlices(u8, want_stream2, stream2);
}

test "non-blocking tcp server" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const localhost = try net.Address.parseIp("127.0.0.1", 0);
    var server = try localhost.listen(.{ .force_nonblocking = true });
    defer server.deinit();

    const accept_err = server.accept();
    try testing.expectError(error.WouldBlock, accept_err);

    const socket_file = try net.tcpConnectToAddress(server.listen_address);
    defer socket_file.close();

    var client = try server.accept();
    defer client.stream.close();
    const stream = client.stream.writer();
    try stream.print("hello from server\n", .{});

    var buf: [100]u8 = undefined;
    const len = try socket_file.read(&buf);
    const msg = buf[0..len];
    try testing.expect(mem.eql(u8, msg, "hello from server\n"));
}
//
test "server accepts blocking connections" {
    if (builtin.single_threaded) return error.SkipZigTest;
    if (builtin.os.tag == .wasi) return error.SkipZigTest;
    if (builtin.os.tag == .windows) {
        _ = try std.os.windows.WSAStartup(2, 2);
    }
    defer {
        if (builtin.os.tag == .windows) {
            std.os.windows.WSACleanup() catch unreachable;
        }
    }
    const localhost = try net.Address.parseIp("127.0.0.1", 0);
    var server = try localhost.listen(.{});
    defer server.deinit();

    const S = struct {
        fn clientFn(server_address: net.Address) !void {
            const socket = try net.tcpConnectToAddress(server_address);
            defer socket.close();
            _ = try socket.writer().writeAll("Hello world!");
        }
    };

    const t = try std.Thread.spawn(.{}, S.clientFn, .{server.listen_address});
    defer t.join();

    var client = try server.accept();
    defer client.stream.close();
    var buf: [16]u8 = undefined;
    const n = try client.stream.reader().read(&buf);

    try testing.expectEqual(@as(usize, 12), n);
    try testing.expectEqualSlices(u8, "Hello world!", buf[0..n]);
}

test "non-blocking server accepts files from clients" {
    // files encoded
    if (builtin.os.tag == .wasi or builtin.os.tag == .windows or builtin.os.tag == .macos)
        return error.SkipZigTest;

    const localhost = try net.Address.parseIp("127.0.0.1", 0);
    var server = try localhost.listen(.{ .force_nonblocking = true });
    defer server.deinit();

    const accept_err = server.accept();
    try testing.expectError(error.WouldBlock, accept_err);

    const socket_file = try net.tcpConnectToAddress(server.listen_address);
    defer socket_file.close();

    var client = try server.accept();
    defer client.stream.close();
    const stream = client.stream.writer();

    const filecont1 = "blablablablabl";
    var buf_client: [256]u8 = undefined;
    const msg_to_server = try SimReqFile.asStr(buf_client[0..], filecont1);
    try stream.writeAll(msg_to_server);

    var buf_server: [256]u8 = undefined;
    const len = try socket_file.read(&buf_server);
    const msg = buf_server[0..len];
    const sreqfile = try SimReqFile.init(msg);

    try testing.expectEqual(@as(u32, @intCast(filecont1.len)), sreqfile.file_size);
    try testing.expectEqualSlices(u8, filecont1, sreqfile.file_content);
}

// test "too big files from clients are rejected" {}

test "server reads minimal DAG" {}
