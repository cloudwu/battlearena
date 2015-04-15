#!/bin/sh
export LUA_CPATH="skynet/luaclib/?.so;client/lsocket/?.so"
export LUA_PATH="client/?.lua;skynet/lualib/?.lua"
lua client/main.lua
