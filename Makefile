AS=vasmm68k_mot
AS_OPTS=-Fbin

SRCS=$(wildcard src/*.s)
INC=$(wildcard src/*.h)
PGM=repl.pgx

all: repl

repl: includes repl_pgx

includes: $(INC)

repl_pgx: $(SRCS)
	$(AS) $(AS_OPTS) -o $(PGM) $(SRCS)

clean:
	rm -rf $(PGM)

.PHONY: repl clean

