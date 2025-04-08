const std = @import("std");

pub const err_scode: u8 = 1;

pub const help_message =
    \\Netfilez is a minimalistic LAN file buffer. It allows you
    \\transceive your files over TCP until your machines have access to each
    \\other's ports.
    \\
    \\Usage: netfilez [arguments]
    \\
    \\Example:
    \\
    \\    netfilez \
    \\        --action="receive" \
    \\        --filepath="/absolute/path/to/directory/" \
    \\        --host="127.0.0.1" \
    \\        --port="8080" \
    \\
    \\You can only receive or dispatch a file at a time specifying 
    \\`--action="receive"` or `--action="dispatch"` correspondingly. Also if you
    \\are receiving the `fdpath` parameter should lead to the directory where 
    \\the file should be saved, but if you are dispatching `fdpath` should lead 
    \\to the file to be sent including the extension.
    \\
    \\Commands:
    \\
    \\    help                   Display this message and exit.
    \\
    \\Arguments:
    \\
    \\    --action <action>      Receive or dispatch file.
    \\    --filepath <string>      Absolute path to the file or directory.
    \\    --host <string>        Host to be listened on/connected to.
    \\    --port <u16>           Port to be listened on/connected to.
    \\
    \\Note that every argument **must** be connected to it's value by "=".
;

pub const incorr_input_res =
    \\The input you have provided is incorrect and can not be
    \\parsed. Please check the prompt and try again or use "help" to see the
    \\available options.
;

pub const args_names: [4][]const u8 = .{
    "action",
    "filepath",
    "host",
    "port",
};

pub const Prefix = enum { info, err };

pub fn log(
    comptime prefix: Prefix,
    comptime format: []const u8,
    args: anytype,
) void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();

    const app_name = "Netfilez";
    nosuspend stderr.print(
        app_name ++ " (" ++ @tagName(prefix) ++ "): " ++ format,
        args,
    ) catch return;
}
