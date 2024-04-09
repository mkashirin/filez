const std = @import("std");
const Allocator = std.mem.Allocator;

const buffer = @import("buffer.zig");
const ActionConfig = buffer.ActionConfig;
const SocketBuffer = buffer.SocketBuffer;

/// Dispatches the file to the host with port specified in the `ActionConfig`
/// passed.
pub fn dispatch(allocator: Allocator, action_config: ActionConfig) !usize {
    const address = try std.net.Address.parseIp(
        action_config.host,
        action_config.port,
    );
    // Connect to the receiver via TCP.
    const stream = try std.net.tcpConnectToAddress(address);
    defer stream.close();

    const stream_writer = stream.writer();
    // Initialize the `SocketBuffer` based on the `ActionConfig`.
    var socket_buffer = try SocketBuffer.initFromConfig(
        allocator,
        action_config,
    );
    defer socket_buffer.deinit(allocator);

    // Write the data into the socket and store the number of bytes written.
    const bytes_written = try socket_buffer.writeIntoStream(stream_writer);
    return bytes_written;
}
