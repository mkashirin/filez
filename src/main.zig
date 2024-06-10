const std = @import("std");
const process = std.process;
const io = std.io;
const Allocator = std.mem.Allocator;

const socket = @import("socket.zig");
const actions = @import("actions.zig");
const messages = @import("messages.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout = io.getStdOut().writer();

    try run(allocator, stdout);
}

/// This function, in fact, runs the application. It processes the command
/// line arguments into the `socket.ActionOptions` struct which then gets
/// fed to the `actions.receive()` or `actions.dispatch()`.
fn run(allocator: Allocator, stdout: anytype) !void {
    var args = try process.argsWithAllocator(allocator);
    defer args.deinit();

    // This hash map will serve as a temporary storage for the argumnets.
    var args_map = std.StringHashMap([]const u8).init(allocator);
    defer args_map.deinit();
    var help_flag = false;

    var args_count: usize = 1;
    while (args.next()) |arg| : (args_count += 1) {
        if (std.mem.eql(u8, arg, "help")) {
            // Display the help message if command is "help".
            help_flag = true;
            return try stdout.print("{s}\n", .{messages.help_message});
        } else if (args_count > 1 and args_count <= 6) {
            // Otherwise continue iterating until arguments count does not
            // exceed 6.
            var arg_iter = std.mem.splitScalar(u8, arg, '=');
            // Exclude "--" at the start of an argument name.
            const name = arg_iter.next().?[2..];
            const value = arg_iter.next().?;

            try args_map.put(name, value);
        }
    }
    // Tell the user if the input is incorrect.
    if ((args_count - 1 != 6 and help_flag != true) or args_count < 2) {
        return try stdout.print("{s}\n", .{messages.incorr_input_res});
    }

    var options = try socket.ActionOptions.initFromArgs(allocator, args_map);
    defer options.deinit(allocator);
    const action = options.parseAction();

    switch (action) {
        .dispatch => try actions.dispatch(allocator, options, stdout),
        .receive => try actions.receive(allocator, options, stdout),
    }
}
