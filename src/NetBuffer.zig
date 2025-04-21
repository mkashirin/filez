const std = @import("std");

const meta = std.meta;
const net = std.net;

const Allocator = std.mem.Allocator;

const actions = @import("actions.zig");

/// This structure is the core of the application. As both `receive()` and
/// `dispatch()` simply manipulate data coming from and going into the
/// socket, it would be appropriate to transfer all responsibility for this
/// functionality to a separate socket management structure. Therefore, the
/// `NetBuffer`, which serves as an interface for manipulating socket
/// data, is introduced.
const Self = @This();

filepath: []u8,
contents: []u8,

/// Initializes a new `NetBuffer` based on the `ActionOptions` data.
pub fn initFromOptions(
    arena: Allocator,
    options: *actions.ActionOptions,
) !Self {
    return .{
        .filepath = try arena.dupe(u8, options.filepath),
        .contents = try readFileContents(arena, options.filepath),
    };
}

/// Initializes a new `NetBuffer` based on the data coming from the
/// connection stream.
pub fn initFromStream(
    arena: Allocator,
    stream_reader: net.Stream.Reader,
) !Self {
    // This loop has to be inline to make use of a comptime known
    // `NetBuffer` field names. The presence of the loop itself aims to make
    // the struct more extensible. So, in case if one would want to add some
    // additional fields that do not require any specific logic, he could do it
    // more easily.
    var new: Self = undefined;
    const fields = meta.fields(@This());
    inline for (fields) |field| {
        // This `list` serves as a buffer, since the object with writer is
        // required to be passed as an argument to the
        // `net.Stream.Reader.streamUntilDelimiter()` function.
        var list = std.ArrayList(u8).init(arena);
        const list_writer = list.writer();

        if (!std.mem.eql(u8, field.name, "contents")) {
            try stream_reader.streamUntilDelimiter(
                list_writer,
                '\n',
                null,
            );
        } else {
            // Reading the file contents with maximum size of 8192 bytes.
            try stream_reader.readAllArrayList(&list, 8192);
        }
        // The data read from the stream must be duped since `list.items`
        // contains a slice. (Slice is essentially a pointer to memory
        // which can be corrupted due to the function return.)
        @field(new, field.name) = try arena.dupe(u8, list.items);
        // Temporary buffer must be deinitialized to be flused and for the
        // resources allocated to be freed.
        list.deinit();
    }
    return new;
}

/// Writes the conetents stored in the `self` into the file.
pub fn writeContentsIntoFile(
    self: *Self,
    dir_absolute_path: []const u8,
    contents: *[]u8,
) !void {
    var dir = try std.fs.openDirAbsolute(
        dir_absolute_path,
        .{ .no_follow = true },
    );

    var file_path_iterator = std.mem.splitBackwardsScalar(
        u8,
        @as([]const u8, self.filepath),
        '/',
    );
    // Acquire the name of the file received.
    const file_name = file_path_iterator.first();
    var file = try dir.createFile(file_name, .{ .read = true });
    // Write into file.
    try file.seekTo(0);
    try file.writeAll(contents.*);
    try file.seekTo(0);
}

/// Writes the data stored in `self` into the connection stream.
pub fn writeIntoStream(
    self: *Self,
    stream_writer: net.Stream.Writer,
) !usize {
    var bytes_written: usize = 0;
    const fields = meta.fields(@This());
    inline for (fields) |field| {
        const value = &@field(self, field.name);
        bytes_written += try stream_writer.write(value.*);
        try stream_writer.writeByte('\n');
        bytes_written += 1;
    }
    return bytes_written;
}

/// Deinitializes the existing `NetBuffer` discarding all the memory
/// that was allocated for it to prevent memory leaks.
pub fn deinit(self: *Self) void {
    self.* = undefined;
}

/// Utility function to read the contents of the file specified.
fn readFileContents(
    arena: Allocator,
    file_absolute_path: []const u8,
) ![]u8 {
    const file = try std.fs.openFileAbsolute(file_absolute_path, .{});
    try file.seekTo(0);
    const contents = try file.readToEndAlloc(arena, 8192);
    return contents;
}
