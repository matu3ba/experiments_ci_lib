//! Run Directed Acyclic Graph (RDAG) serialization and deserialization to file
//! Each RDAG describes the complete CI process.
//! Keep it a simple DOD structure to get something running.
//! - no path hackerino for debugging the system: use ssh/wrm for that
//! - profile means process start properties
//! - cache is just a process executing before and after other processes

// TODO: how to manage env variables
// => ideal: no dependencies, everything provided, no env
// => more pragmatic: strace + read-only access only to necessary args, minimal env
// => unclear how to keep system "secure" and minimize env
const std = @import("std");

pub const RdagInitError = error{};

pub const Profile = struct {
    name: std.ArrayList(u8),
    cwd: std.ArrayList(u8),
    // key-value list (key0:value0,..)
    env: std.ArrayList(u8),
    user: std.ArrayList(u8),
    // first entry cli, rest optional list of log filepaths (x/l[,value0,..])
    stdin: std.ArrayList(u8),
    stdout: std.ArrayList(u8),
    stderr: std.ArrayList(u8),
};

pub const Process = struct {
    id: u32,
    deps: std.ArrayList(u32),
    profile: ?*Profile,
    args: [][:0]u8,
};

/// Format
/// P_PROFILE;user:bob,cwd:$HOME;
/// P_minimal;user:bob,cwd:$HOME;
/// P_minimal;user:x,cwd:$HOME;
/// NR;DEP0,DEP1,..;:PROFILE;CMD,ARG0,..,
/// with \ and , needing to be escaped as \\ and \,
/// 0;x;ls,-a;
/// 1;0;ls,-ax;
/// Naive non-optimal encoding
pub const Rdag = struct {
    profiles: std.ArrayList(Profile),
    processes: std.ArrayList(Process),

    pub fn init(alloc: std.mem.Allocator, file_content: []const u8) RdagInitError!Rdag {
        _ = alloc; // autofix
        for (file_content, 0..) |_, i| {
            _ = i; // autofix
        }
    }
    pub fn deinit(alloc: std.mem.Allocator) void {
        _ = alloc; // autofix
    }

    // Assumes Rdag is well-formed.
    pub fn asStr(buf: []u8, rdag: *const Rdag) RdagInitError![]u8 {
        _ = buf;
        _ = rdag;
    }
};

test "parse profiles" {}

test "parse processes ignore profile" {}

test "minimal RDAG" {
    const file_content =
        \\\P_minimal;user:bob,cwd:$HOME;
        \\\0;x;ls;
    ;
    _ = file_content; // autofix
    // const rdag = Rdag.init(file_content);
    // _ = &rdag;
}

test "full RDAG" {}

test "validate users" {}

test "validate cwd reproducibility" {}

test "validate env" {}
