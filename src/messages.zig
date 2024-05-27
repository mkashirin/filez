pub const help_message =
    \\Filez is a minimalistic LAN file buffer. It allows you transceive your 
    \\files over TCP until your machines have access to each other's ports.
    \\
    \\Usage: filez [arguments]
    \\
    \\Example:
    \\
    \\    filez \
    \\        --action="receive" \
    \\        --fdpath="/absolute/path/to/directory/" \
    \\        --host="127.0.0.1" \
    \\        --port="8080" \
    \\        --password="pass1234"
    \\
    \\You can only receive or dispatch a file at a time specifying 
    \\`--action="receive"` or `--action="dispatch"` correspondingly. Also if you
    \\are receiving the `fdpath` parameter should lead to the directory where 
    \\the file should be saved, but if you are dispatching `path` should lead 
    \\to the file to be sent including the extension.
    \\
    \\Commands:
    \\
    \\    help                   Display this message and exit.
    \\
    \\Arguments:
    \\
    \\    --action <action>      Receive or dispatch file.
    \\    --fdpath <string>      Absolute path to the file or directory.
    \\    --host <string>        Host to be listened on/connected to.
    \\    --port <u16>           Port to be listened on/connected to.
    \\    --password <string>    Password to be matched.
    \\
    \\Note that every argument **must** be connected to it's value by "=".
    \\
;

pub const incorr_input_res =
    \\The input you have provided is incorrect and can not be parsed. Please
    \\check the prompt and try again or use "help" to see the available 
    \\options.
;
