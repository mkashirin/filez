const std = @import("std");
const net = std.net;
const Address = net.Address;
const Allocator = std.mem.Allocator;

const specs = @import("specs.zig");
const ActionConfig = specs.ActionConfig;
const SocketBuffer = specs.SocketBuffer;

/// Dispatches the file to the host with port specified in the `ActionConfig`
/// passed.
pub fn dispatch(allocator: Allocator, action_config: ActionConfig) !usize {
    const address = try Address.parseIp(action_config.host, action_config.port);
    // Connect to the receiver via TCP.
    const stream = try net.tcpConnectToAddress(address);
    defer stream.close();

    const stream_writer = stream.writer();
    // Initialize the `SocketBuffer` based on the `ActionConfig`.
    var socket_buffer = try SocketBuffer.initFromConfig(
        allocator,
        action_config,
    );
    defer socket_buffer.deinit();

    // Write the data into the socket and store the number of bytes written.
    const bytes_written = try socket_buffer.writeIntoStream(stream_writer);
    return bytes_written;
}
