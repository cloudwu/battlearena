all : lsocket/lsocket.so time.so

OS = $(shell uname -s)

ifeq ($(OS),Darwin)
	LIBFLAG=-bundle -undefined dynamic_lookup -all_load
else
	LIBFLAG=-shared
endif

time.so: time.c
	gcc -O2 -Wall -fPIC $(LIBFLAG) -o $@ $^ -I/usr/local/include

lsocket/lsocket.so :
	cd lsocket && $(MAKE)
