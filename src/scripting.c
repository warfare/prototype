/**
 * This file is part of prototype.
 *
 * (c) 2013 Nicolas Hillegeer <nicolas@hillegeer.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with the source code.
 */

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "util.h"

static void wfScriptLoadLibraries(lua_State *lua);

void wfScriptInit(void) {
    lua_State *lua = luaL_newstate();

    ERROR_EXIT(lua == NULL, 0, "could not initialize the lua interpreter");

    wfScriptLoadLibraries(lua);

    trace("succesfully loaded lua\n");

    // char *script = loadfile("./game/hello.lua");
    // trace("loading script: %s\n", script);
    // zfree(script);

    int error = luaL_loadfile(lua, "./game/hello.lua") || lua_pcall(lua, 0, LUA_MULTRET, 0);
    ERROR_HANDLE(error != 0, error, "could not load lua script: %s", lua_tostring(lua, -1));

    return;
error:
    /* pop error message from the stack */
    lua_pop(lua, 1);

    /* always clean up after self */
    lua_close(lua);

    exit(1);
}

void wfScriptDestroy(void) {
    /* lua_close(lua); */
}

static void wfScriptLoadLibraries(lua_State *lua) {
    /* just open all libraries for now, over time we should */
    luaL_openlibs(lua);
}