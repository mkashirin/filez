const std = @import("std");
const Allocator = std.mem.Allocator;

const buffer = @import("buffer.zig");
const ActionConfig = buffer.ActionConfig;
const SocketBuffer = buffer.SocketBuffer;

const ReceiveError = error{PasswordMismatch};

/// Receives the incoming connection and saves the addressed file into the
/// directory specified in the `ActionConfig`.
pub fn receive(allocator: Allocator, action_config: ActionConfig) !void {
    // The `StreamServer` needs to be initialized at first to accept any
    // incoming connection.
    var server = std.net.StreamServer.init(.{ .reuse_port = true });
    defer server.deinit();

    const address = try std.net.Address.parseIp(
        action_config.host,
        action_config.port,
    );
    try server.listen(address);
    var client = try server.accept();
    defer client.stream.close();

    // Reader of the stream allows to read from a socket.
    const stream_reader = client.stream.reader();
    // Buffer automatically fills its fields based on the incoming data.
    var socket_buffer = try SocketBuffer.initFromStream(
        allocator,
        stream_reader,
    );
    defer socket_buffer.deinit(allocator);

    // The following statement insures that passwords for server and client
    // sides are equal.
    const buffer_password: []const u8 = socket_buffer.password;
    if (!std.mem.eql(u8, action_config.password, buffer_password))
        return ReceiveError.PasswordMismatch;

    // Finally, the received data gets written into the file placed in the
    // specified directory.
    try socket_buffer.writeContentsIntoFile(
        action_config.path,
        &socket_buffer.contents,
    );
}
