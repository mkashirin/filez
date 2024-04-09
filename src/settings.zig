const clap = @import("clap");

const Action = @import("buffer.zig").ActionConfig.Action;

pub const help_message =
    \\Filez is a minimalistic LAN file buffer. It allows you transceive your 
    \\files over TCP until your machines have access to each other's ports.
    \\
    \\You can only receive or dispatch a file at a time specifying 
    \\`--action=receive` or `--action=dispatch` correspondingly. Also if you
    \\are receiving the `path` parameter should lead to the directory where 
    \\the file should be saved, but if you are dispatching `path` should lead 
    \\to the file to be sent including the extension.
    \\
    \\Here are the parameters you must provide:
;

pub const params = clap.parseParamsComptime(
    \\-h, --help             Display this message and exit.
    \\    --action <ACTN>    Receive or dispatch file.
    \\    --path <PATH>      Absolute path to the file or directory.
    \\-H, --host <HOST>      Host to be listened on/connected to.
    \\-P, --port <PORT>      Port to be listened on/connected to.
    \\-p, --password <PASS>  Password to be matched.
    \\
);

pub const parsers = .{
    .ACTN = clap.parsers.enumeration(Action),
    .PATH = clap.parsers.string,
    .HOST = clap.parsers.string,
    .PORT = clap.parsers.int(u16, 10),
    .PASS = clap.parsers.string,
};

pub const help_options = clap.HelpOptions{
    .spacing_between_parameters = 0,
    .indent = 2,
    .description_on_new_line = false,
};
