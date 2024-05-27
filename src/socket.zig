const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;

pub const ActionOptions = struct {
    /// This struct provides the action configuration which should be passed to
    /// the `SocketBuffer`, `receive()` and `dispatch()` functions.
    pub const Action = enum {
        dispatch,
        receive,

        pub fn fromString(str: []const u8) ?Action {
            return std.meta.stringToEnum(Action, str);
        }
    };

    action: []const u8 = undefined,
    fdpath: []const u8 = undefined,
    host: []const u8 = undefined,
    port: []const u8 = undefined,
    password: []const u8 = undefined,

    pub fn init(
        allocator: Allocator,
        args_map: std.StringHashMap([]const u8),
    ) !ActionOptions {
        var new = ActionOptions{};
        const fields = std.meta.fields(@This());
        inline for (fields) |field| {
            const arg_value = args_map.get(field.name).?;
            @field(new, field.name) = try allocator.dupe(u8, arg_value);
        }
        return new;
    }

    pub fn parseAction(self: *ActionOptions) Action {
        return std.meta.stringToEnum(Action, self.action).?;
    }

    pub fn parsePort(self: *ActionOptions) !u16 {
        return try std.fmt.parseInt(u16, self.port, 10);
    }

    pub fn deinit(self: *ActionOptions, allocator: Allocator) void {
        const fields = std.meta.fields(@This());
        inline for (fields) |field| {
            allocator.free(@field(self, field.name));
        }
        self.* = undefined;
    }
};

pub const SocketBuffer = struct {
    /// This structure is the core of the application. As both `receive()` and
    /// `dispatch()` simply manipulate data coming from and going into the
    /// socket, it would be appropriate to transfer all responsibility for this
    /// functionality to a separate socket management structure. Therefore, the
    /// `SocketBuffer`, which serves as an interface for manipulating socket
    /// data, is introduced.
    fdpath: []u8 = undefined,
    password: []u8 = undefined,
    contents: []u8 = undefined,

    /// Initializes a new `SocketBuffer` based on the `ActionConfig` data.
    pub fn initFromOptions(
        allocator: Allocator,
        options: ActionOptions,
    ) !SocketBuffer {
        return .{
            .password = try allocator.dupe(u8, options.password),
            .fdpath = try allocator.dupe(u8, options.fdpath),
            .contents = try readFileContents(allocator, options.fdpath),
        };
    }

    /// Initializes a new `SocketBuffer` based on the data coming from the
    /// connection stream.
    pub fn initFromStream(
        allocator: Allocator,
        stream_reader: net.Stream.Reader,
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
            @as([]const u8, self.fdpath),
            '/',
        );
        // Acquire the name of the file received.
        const file_name = file_path_iterator.first();
        var file = try directory.createFile(file_name, .{ .read = true });
        defer file.close();
        // Write into file.
        try file.seekTo(0);
        try file.writeAll(contents.*);
    }

    /// Writes the data stored in `self` into the connection stream.
    pub fn writeIntoStream(
        self: *SocketBuffer,
        stream_writer: net.Stream.Writer,
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
        self.* = undefined;
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
