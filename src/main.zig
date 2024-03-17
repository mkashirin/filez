const std = @import("std");
const io = std.io;
const Allocator = std.mem.Allocator;

const clap = @import("clap");

const specs = @import("specs.zig");
const ActionConfig = specs.ActionConfig;
const SocketBuffer = specs.SocketBuffer;
const receive = @import("receiver.zig").recieve;
const dispatch = @import("dispatcher.zig").dispatch;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    try run(allocator);
}

pub fn run(allocator: Allocator) !void {
    // Clap parses all the arguments and their types from this comptime string.
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this message and exit.
        \\    --action <ACTION>  Receive or dispatch file.
        \\    --path <PATH>      Absolute path to the file to dispatch or 
        \\                       directory, where to put the received file.
        \\-H, --host <HOST>      Host to be listened on/connected to.
        \\-P, --port <PORT>      Port to be listened on/connected to.
        \\-p, --password <PASS>  Passwords set for receiver and dispatcher must 
        \\                       match. Otherwise an error would be returned.
        \\
    );
    // Then the custom parsers need to be defined since special types are
    // dealcared for the arguments.
    const parsers = comptime .{
        .ACTION = clap.parsers.enumeration(ActionConfig.Action),
        .PATH = clap.parsers.string,
        .HOST = clap.parsers.string,
        .PORT = clap.parsers.int(u16, 10),
        .PASS = clap.parsers.string,
    };

    var res = try clap.parse(clap.Help, &params, parsers, .{
        .allocator = allocator,
    });
    defer res.deinit();

    // The following logic handles the user input.
    if (res.args.help != 0)
        return clap.help(io.getStdErr().writer(), clap.Help, &params, .{});
    if (res.args.action) |action| {
        const action_config = ActionConfig{
            .host = res.args.host.?,
            .port = res.args.port.?,
            .path = res.args.path.?,
            .password = res.args.password.?,
        };
        switch (action) {
            .receive => try receive(allocator, action_config),
            // `dispatch()` returns the number of bytes written.
            .dispatch => _ = try dispatch(allocator, action_config),
        }
    }
}
