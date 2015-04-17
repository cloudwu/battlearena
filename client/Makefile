all : lsocket/lsocket.so timesync.so

OS = $(shell uname -s)

ifeq ($(OS),Darwin)
	LIBFLAG=-bundle -undefined dynamic_lookup -all_load
else
	LIBFLAG=-shared
endif

timesync.so: timesync.c
	gcc -O2 -Wall -fPIC $(LIBFLAG) -o $@ $^ -I/usr/local/include

lsocket/lsocket.so :
	cd lsocket && $(MAKE)
