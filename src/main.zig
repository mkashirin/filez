const std = @import("std");
const testing = std.testing;

const mem = std.mem;
const process = std.process;

const Allocator = mem.Allocator;

const actions = @import("actions.zig");
const config = @import("config.zig");
const NetBuffer = @import("NetBuffer.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var args = try process.argsWithAllocator(allocator);
    var args_map = try parse_args(allocator, &args);

    var options = actions.ActionOptions.initFromArgs(&args_map);

    run(allocator, &options) catch |err| {
        config.log(
            .err,
            "Could not run the application due to the following error: {s}\n",
            .{@errorName(err)},
        );
        std.process.exit(config.err_scode);
    };
}

/// This function, in fact, runs the application. It processes the command
/// line arguments into the `socket.ActionOptions` struct which then gets
/// fed to the `actions.receive()` or `actions.dispatch()`.
fn run(arena: Allocator, options: *actions.ActionOptions) !void {
    var voptions = options.*;
    const action = voptions.parseAction();
    if (action == .dispatch) {
        try actions.dispatch(arena, &voptions);
    } else if (action == .receive) {
        try actions.receive(arena, &voptions);
    }
}

fn parse_args(
    arena: Allocator,
    args: *std.process.ArgIterator,
) !std.StringHashMap([]const u8) {
    var vargs = args.*;
    // This hash map will serve as a temporary storage for the argumnets.
    var args_map = std.StringHashMap([]const u8).init(arena);
    var help_flag = false;

    var args_count: usize = 1;
    while (vargs.next()) |arg| : (args_count += 1) {
        if (mem.eql(u8, arg, "help")) {
            // Display the help message if command is "help".
            help_flag = true;
            config.log(.info, "{s}\n", .{config.help_message});
            return error.HelpFound;
        } else if (args_count > 1 and args_count <= 6) {
            // Otherwise continue iterating until arguments count does not
            // exceed 6.
            var arg_iter = mem.splitAny(u8, arg, " =");
            // Exclude "--" at the start of an argument name.
            const name = blk: {
                const arg_passed = arg_iter.next().?[2..];
                for (config.args_names) |arg_name| {
                    if (mem.eql(u8, arg_passed, arg_name)) {
                        break :blk arg_passed;
                    }
                } else return error.InvalidArgument;
            };
            const value = arg_iter.next().?;

            try args_map.put(name, value);
        }
    }
    // Tell the user if the input is incorrect.
    if ((args_count - 1 != 5 and help_flag != true) or args_count < 2) {
        config.log(.info, "{s}\n", .{config.incorr_input_res});
        return error.InvalidInput;
    }
    return args_map;
}

test "end-to-end" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var cwd = try std.fs.cwd().openDir(".", .{});
    try cwd.makeDir("test");

    try cwd.makeDir("test/dispatcher");
    var dispatch_file = try cwd.createFile("test/message.txt", .{});
    try dispatch_file.writeAll("Hello from dispatcher!!!\r\n");
    dispatch_file.close();
    try cwd.makeDir("test/receiver");

    var _dispatch_out_buffer: []u8 = try allocator.alloc(u8, 256);
    const dfp = try cwd.realpath(
        "test/message.txt",
        _dispatch_out_buffer[0..],
    );

    var _receive_out_buffer: []u8 = try allocator.alloc(u8, 256);
    const rfp = try cwd.realpath("test/receiver", _receive_out_buffer[0..]);

    var dispatch_options = actions.ActionOptions{
        .action = "dispatch",
        .filepath = dfp,
        .host = "127.0.0.1",
        .port = "8080",
    };
    // Create a thread for the dispatch task.
    const dispatch_thread = try std.Thread.spawn(
        .{ .allocator = allocator },
        run,
        .{ allocator, &dispatch_options },
    );

    var receive_options = actions.ActionOptions{
        .action = "receive",
        .filepath = rfp,
        .host = "127.0.0.1",
        .port = "8080",
    };
    // Create a thread for the receive task.
    const receive_thread = try std.Thread.spawn(
        .{ .allocator = allocator },
        run,
        .{ allocator, &receive_options },
    );

    // Join both threads.
    inline for (.{ dispatch_thread, receive_thread }) |thread| {
        thread.join();
    }

    var received_file = try cwd.openFile("test/receiver/message.txt", .{});
    try cwd.deleteTree("test");
    var buffer: []u8 = try allocator.alloc(u8, 24);
    _ = try received_file.readAll(buffer);
    try testing.expectEqualSlices(u8, "Hello from dispatcher!!!"[0..], buffer[0..]);
}
