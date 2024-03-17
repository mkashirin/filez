const std = @import("std");
const net = std.net;
const Address = net.Address;
const Allocator = std.mem.Allocator;

const specs = @import("specs.zig");
const ActionConfig = specs.ActionConfig;
const SocketBuffer = specs.SocketBuffer;

pub fn dispatch(allocator: Allocator, action_config: ActionConfig) !usize {
    const address = try Address.parseIp(action_config.host, action_config.port);
    const stream = try net.tcpConnectToAddress(address);
    defer stream.close();

    const stream_writer = stream.writer();
    var socket_buffer = try SocketBuffer.initFromConfig(
        allocator,
        action_config,
    );
    defer socket_buffer.deinit();

    const bytes_written = try socket_buffer.writeIntoStream(stream_writer);
    return bytes_written;
}
