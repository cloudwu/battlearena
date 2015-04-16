#include <stdio.h>
#include <stdint.h>
#include <sys/time.h>
#include <lua.h>
#include <lauxlib.h>
#include <unistd.h>

static uint64_t start_time = 0;

static uint64_t
gettime() {
	uint64_t t;
	struct timeval tv;
	gettimeofday(&tv, NULL);
	t = (uint64_t)tv.tv_sec * 100;
	t += tv.tv_usec / 10000;
	return t;
}

static int
ltime(lua_State *L) {
	uint64_t t = gettime();
	lua_pushinteger(L, t - start_time);
	return 1;
}

static int
lsleep(lua_State *L) {
	int t = luaL_checkinteger(L,1);
	usleep(t * 10000);
	return 0;
}

int
luaopen_time(lua_State *L) {
	if (start_time == 0) {
		start_time = gettime();
	}
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "time", ltime },
		{ "sleep", lsleep },
		{ NULL, NULL },
	};

	luaL_newlib(L,l);

	return 1;
}
