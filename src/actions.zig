const std = @import("std");

const log = std.log;
const meta = std.meta;
const net = std.net;

const Allocator = std.mem.Allocator;

const config = @import("config.zig");
const NetBuffer = @import("NetBuffer.zig");

pub const ActionOptions = struct {
    /// This struct stores command line arguments and provides the action
    /// options which should be passed to the `SocketBuffer`, `receive()` and
    /// `dispatch()` functions.
    const Self = @This();
    pub const Action = enum { dispatch, receive };

    action: []const u8,
    file_path: []const u8,
    host: []const u8,
    port: []const u8,

    /// Initilizes action options struct using a hash map of CLI arguments.
    pub fn initFromArgs(
        args_map: *std.StringHashMap([]const u8),
    ) Self {
        var new: Self = undefined;
        const fields = meta.fields(@This());
        inline for (fields) |field| {
            const arg_value = args_map.get(field.name);
            @field(new, field.name) = arg_value.?;
        }
        return new;
    }

    /// Returns an enum based on the active action field.
    pub fn parseAction(self: *Self) Action {
        return meta.stringToEnum(Action, self.action).?;
    }

    /// Returns a `u16` integer to passed as a port to the further functions.
    pub fn parsePort(self: *Self) !u16 {
        return try std.fmt.parseInt(u16, self.port, 10);
    }

    /// Frees all the memory been allocated to store the options.
    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }
};

/// Dispatches the file to the host with port specified in the `ActionConfig`
/// passed.
pub fn dispatch(
    arena: Allocator,
    action_options: *ActionOptions,
) !void {
    // The `std.net.Address` needs to be parsed at first to accept any TCP
    // converseur. But first `action_options` must become varibale in order to
    // be mutable.
    var options_variable = action_options;
    const address = try net.Address.parseIp(
        options_variable.host,
        try options_variable.parsePort(),
    );
    config.log(.info, "Listening on the {}...\n", .{address});
    var server = try address.listen(.{ .reuse_port = true });
    // Accept incoming connection and acquire the stream.
    const connection = try server.accept();
    config.log(.info, "{} connected. Transmitting file...\n", .{address});
    const stream = connection.stream;
    defer stream.close();

    const writer = stream.writer();
    // Initialize the `socket.SocketBuffer` based on the `ActionConfig`.
    var net_buffer = try NetBuffer.initFromOptions(
        arena,
        options_variable,
    );
    defer net_buffer.deinit();

    // Write the data into the socket and store the number of bytes written.
    const bytes_written = try net_buffer.writeIntoStream(writer);

    config.log(
        .info,
        "File successfully transmitted ({} bytes written).\n",
        .{bytes_written},
    );
}

/// Connects to the dispatching peer and saves the addressed file into the
/// directory specified in the `buffer.ActionOptions`.
pub fn receive(
    arena: Allocator,
    action_options: *ActionOptions,
) !void {
    // The `std.net.Address` needs to be parsed at first to connect to any TCP
    // converseur. But first `action_options` must become varibale in order to
    // be mutable.
    var voptions = action_options;
    const address = try std.net.Address.parseIp(
        voptions.host,
        try voptions.parsePort(),
    );
    // Connect to the dispatcher via TCP.
    const stream = try std.net.tcpConnectToAddress(address);
    defer stream.close();
    config.log(.info, "Connected to {}. Receiving file...\n", .{address});

    // Reader of the stream allows to read from a socket.
    const reader = stream.reader();
    // Buffer automatically fills it's fields based on the incoming data.
    var net_buffer = try NetBuffer.initFromStream(
        arena,
        reader,
    );
    defer net_buffer.deinit();

    // Finally, the received data gets written into the file placed in the
    // specified directory.
    try net_buffer.writeContentsIntoFile(
        voptions.file_path,
        &net_buffer.contents,
    );
    config.log(.info, "file successfully received.", .{});
}
