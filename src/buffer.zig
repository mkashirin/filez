const std = @import("std");
const Allocator = std.mem.Allocator;
const StreamReader = std.net.Stream.Reader;
const StreamWriter = std.net.Stream.Writer;

pub const ActionConfig = struct {
    /// This struct provides the action configuration which should be passed to
    /// the `SocketBuffer`, `receive()` and `dispatch()` functions.
    pub const Action = enum { dispatch, receive };

    host: []const u8,
    port: u16,
    password: []const u8,
    path: []const u8,
};

pub const SocketBuffer = struct {
    /// This structure is the core of the application. As both `receive()` and
    /// `dispatch()` simply manipulate data coming from and going to the
    /// socket, it would be appropriate to transfer all responsibility for this
    /// functionality to a separate socket management structure. Therefore, the
    /// `SocketBuffer`, which serves as an interface for manipulating socket
    /// data, is introduced.
    password: []u8 = undefined,
    path: []u8 = undefined,
    contents: []u8 = undefined,

    /// Initializes a new `SocketBuffer` based on the `ActionConfig` data.
    pub fn initFromConfig(
        allocator: Allocator,
        action_config: ActionConfig,
    ) !SocketBuffer {
        return .{
            .password = try allocator.dupe(u8, action_config.password),
            .path = try allocator.dupe(u8, action_config.path),
            .contents = try readFileContents(allocator, action_config.path),
        };
    }

    /// Initializes a new `SocketBuffer` based on the data coming from the
    /// connection stream.
    pub fn initFromStream(
        allocator: Allocator,
        stream_reader: StreamReader,
    ) !SocketBuffer {
        // This loop has to be inline to make use of a comptime known
        // `SocketBuffer` field names.
        var new = SocketBuffer{};
        const fields = std.meta.fields(@This());
        inline for (fields) |field| {
            // This `list` serves as a buffer, since the object with writer is
            // required to be passed as an argument to the
            // `net.Stream.Reader.streamUntilDelimiter()` function.
            var list = std.ArrayList(u8).init(allocator);
            const list_writer = list.writer();

            if (!std.mem.eql(u8, field.name, "contents")) {
                try stream_reader.streamUntilDelimiter(
                    list_writer,
                    '\n',
                    null,
                );
            } else {
                // Reading the file contents with maximum size of 8192 bits.
                try stream_reader.readAllArrayList(&list, 8192);
            }
            // The data read from the stream must be duped since `list.items`
            // contains a slice. (Slice is essentially a pointer to memory
            // which can be corrupted due to the function return.)
            @field(new, field.name) = try allocator.dupe(u8, list.items);
            // Temporary buffer must be deinitialized to be flused and for the
            // resources allocated to be freed.
            list.deinit();
        }
        return new;
    }

    /// Writes the conetents stored in the `self` into the file.
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
        // Acquire the name of the file received.
        const file_name = file_path_iterator.first();
        var file = try directory.createFile(file_name, .{ .read = true });
        defer file.close();
        try file.seekTo(0);
        try file.writeAll(contents.*);
    }

    /// Writes the data stored in `self` into the connection stream.
    pub fn writeIntoStream(
        self: *SocketBuffer,
        stream_writer: StreamWriter,
    ) !usize {
        // Store the size of the data being written in bytes.
        var bytes_written: usize = 0;
        const fields = std.meta.fields(@This());
        inline for (fields) |field| {
            const value = &@field(self, field.name);
            bytes_written += try stream_writer.write(value.*);
            try stream_writer.writeByte('\n');
            bytes_written += 1;
        }
        return bytes_written;
    }

    /// Deinitializes the existing `SocketBuffer` discarding all the memory
    /// that was allocated for it to prevent memory leaks.
    pub fn deinit(self: *SocketBuffer, allocator: Allocator) void {
        const fields = std.meta.fields(@This());
        inline for (fields) |field| {
            allocator.free(@field(self, field.name));
        }
    }

    /// Utility function to read the contents of the file specified.
    fn readFileContents(
        allocator: std.mem.Allocator,
        file_absolute_path: []const u8,
    ) ![]u8 {
        const file = try std.fs.openFileAbsolute(file_absolute_path, .{});
        defer file.close();
        try file.seekTo(0);
        const contents = try file.readToEndAlloc(allocator, 8192);
        return contents;
    }
};
