const std = @import("std");
const StreamReader = std.net.Stream.Reader;
const StreamWriter = std.net.Stream.Writer;
const Allocator = std.mem.Allocator;

pub const ActionConfig = struct {
    pub const Action = enum { dispatch, receive };

    host: []const u8,
    port: u16,
    password: []const u8,
    path: []const u8,
};

pub const SocketBuffer = struct {
    password: []u8 = undefined,
    path: []u8 = undefined,
    contents: []u8 = undefined,

    pub fn initFromConfig(
        allocator: Allocator,
        action_config: ActionConfig,
    ) !SocketBuffer {
        const new = SocketBuffer{
            .password = try allocator.dupe(u8, action_config.password),
            .path = try allocator.dupe(u8, action_config.path),
            .contents = try readFileContents(allocator, action_config.path),
        };
        return new;
    }

    pub fn initFromStream(
        allocator: Allocator,
        stream_reader: StreamReader,
    ) !SocketBuffer {
        var new = SocketBuffer{};
        inline for (std.meta.fields(@This())) |field| {
            var list = std.ArrayList(u8).init(allocator);
            const list_writer = list.writer();

            if (!std.mem.eql(u8, field.name, "content")) {
                try stream_reader.streamUntilDelimiter(
                    list_writer,
                    '\n',
                    null,
                );
            } else {
                try stream_reader.readAllArrayList(&list, 8192);
            }
            @field(new, field.name) = try allocator.dupe(u8, list.items);

            list.deinit();
        }
        return new;
    }

    pub fn writeContentsIntoFile(
        self: *SocketBuffer,
        dir_absolute_path: []const u8,
        contents: *[]u8,
    ) !void {
        var directory = try std.fs.openDirAbsolute(
            dir_absolute_path,
            .{ .no_follow = true },
        );
        defer directory.close();

        var file_path_iterator = std.mem.splitBackwardsScalar(
            u8,
            @as([]const u8, self.path),
            '/',
        );
        const file_name = file_path_iterator.first();
        var file = try directory.createFile(file_name, .{ .read = true });
        defer file.close();
        try file.seekTo(0);
        try file.writeAll(contents.*);
    }

    pub fn writeIntoStream(
        self: *SocketBuffer,
        stream_writer: StreamWriter,
    ) !usize {
        var bytes_written: usize = 0;
        inline for (std.meta.fields(@TypeOf(self.*))) |field| {
            const value = &@field(self, field.name);
            bytes_written += try stream_writer.write(value.*);
            try stream_writer.writeByte('\n');
            bytes_written += 1;
        }
        return bytes_written;
    }

    pub fn deinit(self: *SocketBuffer, allocator: Allocator) void {
        inline for (std.meta.fields(@TypeOf(self.*))) |field| {
            allocator.free(@field(self, field.name));
        }
    }

    fn readFileContents(
        allocator: Allocator,
        file_absolute_path: []const u8,
    ) ![]u8 {
        const file = try std.fs.openFileAbsolute(file_absolute_path, .{});
        defer file.close();
        try file.seekTo(0);
        const contents = try file.readToEndAlloc(allocator, 8192);
        return contents;
    }
};
