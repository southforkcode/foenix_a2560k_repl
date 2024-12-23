# Example Implementation of a Simple REPL

This is a 68040 assembly program that demonstrates a simple console application that could become a REPL for something in the future.

It demonstrates console input/output using system calls to the Foenix/MCP kernel.

## Compiling

You need vasm compiled for the 68040 using Motorola syntax.

http://sun.hasenbraten.de/vasm/

`vasmm68k_mot -Fbin -o repl.pgx ~/Projects/foenix_2560_test/repl.s`

## Running

After copying over to a SD card and inserting that into the A2560K, you can run the executable with

`/sd/repl.pgx`

## Commands

Entering an empty line will quit.

### quit

Quits the application

### block

Prints the address in hex of the command_impls table.

### hello

Prints the address in hex of the input buffer.

## Functional notes

### puts

Prints a null-terminated string to the console using the `$14` system call which writes out a single byte.

### gets

Small wrapper for the `$12` system call which reads a full line (until return or end of buffer). This function will null terminate the end of input so that it can be treated like a null-terminated string.

### puthexb, puthexw, puthexl

Writes a single byte, word, or long word as a hexadecimal value to the console. Useful for debugging!

### match_cmd

Iterates through a table of commands and returns the index of a matching command. If there is no match, then it will return -1.
