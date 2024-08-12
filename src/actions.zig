const std = @import("std");

const log = std.log;
const net = std.net;

const Allocator = std.mem.Allocator;

const socket = @import("socket.zig");

/// Dispatches the file to the host with port specified in the `ActionConfig`
/// passed.
pub fn dispatch(arena: Allocator, action_options: *socket.ActionOptions) !void {
    // The `std.net.Address` needs to be parsed at first to accept any TCP
    // converseur. But first `action_options` must become varibale in order to
    // be mutable.
    var options_variable = action_options;
    const address = try net.Address.parseIp(
        options_variable.host,
        try options_variable.parsePort(),
    );
    log.info("Filez: Listening on the {}...\n", .{address});
    var server = try address.listen(.{ .reuse_port = true });
    // Accept incoming connection and acquire the stream.
    const connection = try server.accept();
    log.info("Filez: {} connected. Transmitting file...\n", .{address});
    const stream = connection.stream;
    defer stream.close();

    const writer = stream.writer();
    // Initialize the `socket.SocketBuffer` based on the `ActionConfig`.
    var socket_buffer = try socket.SocketBuffer.initFromOptions(
        arena,
        options_variable,
    );
    defer socket_buffer.deinit();

    // Write the data into the socket and store the number of bytes written.
    const bytes_written = try socket_buffer.writeIntoStream(writer);
    log.info(
        "Filez: File successfully transmitted ({} bytes written).\n",
        .{bytes_written},
    );
}

/// Connects to the dispatching peer and saves the addressed file into the
/// directory specified in the `buffer.ActionOptions`.
pub fn receive(
    arena: Allocator,
    action_options: *socket.ActionOptions,
) !void {
    // The `std.net.Address` needs to be parsed at first to connect to any TCP
    // converseur. But first `action_options` must become varibale in order to
    // be mutable.
    var options_variable = action_options;
    const address = try std.net.Address.parseIp(
        options_variable.host,
        try options_variable.parsePort(),
    );
    // Connect to the dispatcher via TCP.
    const stream = try std.net.tcpConnectToAddress(address);
    defer stream.close();
    log.info(
        "Filez: Connected to {}. Receiving file...\n",
        .{address},
    );

    // Reader of the stream allows to read from a socket.
    const reader = stream.reader();
    // Buffer automatically fills it's fields based on the incoming data.
    var socket_buffer = try socket.SocketBuffer.initFromStream(
        arena,
        reader,
    );
    defer socket_buffer.deinit();

    // The following statement insures that passwords for server and client
    // sides are equal.
    const password_buffer: []const u8 = socket_buffer.password;
    if (!std.mem.eql(u8, options_variable.password, password_buffer))
        return error.PasswordMismatch;

    // Finally, the received data gets written into the file placed in the
    // specified directory.
    try socket_buffer.writeContentsIntoFile(
        options_variable.fdpath,
        &socket_buffer.contents,
    );
    log.info("Filez: file successfully received.", .{});
}
