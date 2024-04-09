const std = @import("std");
const io = std.io;

const clap = @import("clap");

const buffer = @import("buffer.zig");
const receive = @import("receiver.zig").receive;
const dispatch = @import("dispatcher.zig").dispatch;
const settings = @import("settings.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    try run(allocator);
}

fn run(allocator: std.mem.Allocator) !void {
    var res = try clap.parse(clap.Help, &settings.params, settings.parsers, .{
        .allocator = allocator,
    });
    defer res.deinit();

    // The following logic handles the user input.
    const stdout = io.getStdOut().writer();
    if (res.args.help != 0) {
        try stdout.print("{s}\n", .{settings.help_message});
        return clap.help(
            stdout,
            clap.Help,
            &settings.params,
            settings.help_options,
        );
    }

    if (res.args.action) |action| {
        const action_config = buffer.ActionConfig{
            .host = res.args.host orelse @panic("Missing host!"),
            .port = res.args.port orelse @panic("Missing port!"),
            .password = res.args.password orelse @panic("Missing password!"),
            .path = res.args.path orelse @panic("Missing path!"),
        };

        switch (action) {
            .receive => try receive(allocator, action_config),
            // `dispatch()` returns the number of bytes written.
            .dispatch => _ = try dispatch(allocator, action_config),
        }
    }
}
