# Filez

Filez is a very simple tool for receiving and sending files written in the Zig 
programming language (version is 0.11.0) made to gain better understanding 
of low level languages and systems programming in general.

## Building

At the moment, there is no direct method to download a binary for your system. 
Therefore, if you wish to utilize this application, you will need to compile it 
from source. Here are the steps to do so.

Clone this repository onto your local machine using the Git Command Line 
Interface (CLI):

```
git clone https://github.com/mkashirin/filez
```

Compile a binary using the Zig compiler (the sole valid version of Zig 
is 0.11.0) by running the following command:

```
zig build
```

After completing the above steps, the binary will be located in the 
"zig-out/bin/" directory. That concludes the process.

## Usage

The information provided by the `filez -h` or `filez --help` options describes 
all the arguments in detail. However, the following is an example of how to use 
the tool on your local machine only (make sure to make Filez visible to your 
system first).

Open a terminal and execute the following command, specifying your own path to 
the directory where you want to store the received file:

```
filez --action=recieve --path=absolute/path/to/directory -H=127.0.0.1 -P=8080 -p=pass123
```

Then, open a second terminal instance and execute the following command, 
specifying the path to the file that you wish to process:

```
filez --action=dispatch --path=absolute/path/to/file.ext -H=127.0.0.1 -P=8080 -p=pass123
```

**Remember**, the file size must not exceed the maximum of 8 kilobytes.

## Note

Consider different `zig build` modes for embedded systems.
