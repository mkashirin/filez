<h1 align="center">Netfilez</h1>

<p align="center">
Netfilez is a very simple file buffer files written in the Zig programming language. Is was built
to gain better understanding of low level languages and systems programming in general.
</p>

## Building

Clone this repository onto your local machine using the Git Command Line Interface (CLI):
```shell
git clone https://github.com/mkashirin/netfilez
```

Compile a binary using the Zig compiler (the sole valid version is 0.14.1) by running the following
command:
```shell
zig build -Doptimize=ReleaseSafe
```

After completing the steps above, the binary will be located in the zig-out/bin/.

## Usage

The information provided by the `netfilez help` options describes all the arguments in detail.
However, the following is an example of how to use the tool on your local machine only (make sure
to make Netfilez visible to your system first).

Open a terminal and execute the following command, specifying the path to the file that you wish to
process:
```shell
netfilez \
    --action="dispatch" \
    --filepath="/absolute/path/to/file.ext" \
    --host="127.0.0.1" \
    --port="8080" \
```

Then, open a second terminal instance and execute the following command, specifying your own path
to the directory where you want to store the received file:
```shell
netfilez \
    --action="receive" \
    --filepath="/absolute/path/to/directory/" \
    --host="127.0.0.1" \
    --port="8080" \
```

**Remember**, the file size must not exceed the maximum of 8 kilobytes.

## Note

Devises to be communicating with files must have ability to ping each other.
