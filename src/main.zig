const std = @import("std");

const log = std.log;
const mem = std.mem;
const process = std.process;
const io = std.io;

const Allocator = mem.Allocator;

const socket = @import("socket.zig");
const actions = @import("actions.zig");
const config = @import("config.zig");

pub const std_options: std.Options = .{ .log_level = .info };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    run(allocator) catch |err| log.err(
        "Could not run the application due to the following error: {any}",
        .{err},
    );
}

/// This function, in fact, runs the application. It processes the command
/// line arguments into the `socket.ActionOptions` struct which then gets
/// fed to the `actions.receive()` or `actions.dispatch()`.
fn run(arena: Allocator) !void {
    var args = try process.argsWithAllocator(arena);
    defer args.deinit();

    // This hash map will serve as a temporary storage for the argumnets.
    var args_map = std.StringHashMap([]const u8).init(arena);
    defer args_map.deinit();
    var help_flag = false;

    var args_count: usize = 1;
    while (args.next()) |arg| : (args_count += 1) {
        if (mem.eql(u8, arg, "help")) {
            // Display the help message if command is "help".
            help_flag = true;
            return log.info("{s}\n", .{config.help_message});
        } else if (args_count > 1 and args_count <= 6) {
            // Otherwise continue iterating until arguments count does not
            // exceed 6.
            var arg_iter = mem.splitScalar(u8, arg, '=');
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
    if ((args_count - 1 != 6 and help_flag != true) or args_count < 2) {
        return log.info("{s}\n", .{config.incorr_input_res});
    }

    var options = socket.ActionOptions.initFromArgs(&args_map);
    defer options.deinit();
    const action = options.parseAction();
    if (action == .dispatch) {
        actions.dispatch(arena, &options) catch |err| log.err(
            "Unexpected error during dispatch: {any}",
            .{err},
        );
    } else if (action == .receive) {
        actions.receive(arena, &options) catch |err| log.err(
            "Unexpected error during receive: {any}",
            .{err},
        );
    }
}
