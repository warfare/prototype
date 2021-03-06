# This file is part of prototype.
#
# (c) 2013 Nicolas Hillegeer <nicolas@hillegeer.com>
#
# For the full copyright and license information, please view the LICENSE
# file that was distributed with the source code.
#
# $@ The name of the target file (the one before the colon)
# $< The name of the first (or only) prerequisite file (the first one after the colon)
# $^ The names of all the prerequisite files (space separated)
# $* The stem (the bit which matches the % wildcard in the rule definition.
#
# if ever in need of a cross-platform solution for making directories:
# http://stackoverflow.com/questions/99132/how-to-check-if-a-directory-exists-in-a-makefile

ENABLE_LUA ?= 1

# CC := /usr/local/bin/gcc-4.8
# CC := /usr/local/bin/gcc-4.9
CC := /usr/local/bin/clang
# CC := /usr/local/bin/clang-3.4

STD := -std=c11 -pedantic -fstrict-aliasing
SECURITY := -D_THREAD_SAFE -D_FORTIFY_SOURCE=2
WARN := -Wextra -Wcast-align -Wcast-qual \
	-Wpointer-arith -Waggregate-return -Wunreachable-code \
	-Wfloat-equal -Wformat=2 -Wredundant-decls \
	-Wundef -Wdisabled-optimization -Wshadow \
	-Wmissing-braces -Wstrict-aliasing=2 -Wstrict-overflow=5 \
	-Wconversion
UNWARN := -Wno-unused-parameter -Wno-missing-field-initializers -Wno-missing-braces \
	-Wno-strict-aliasing
DEBUG := -g3 -DDEBUG
OPT := -O2 -march=native -mtune=native -ftree-vectorize

CFLAGS ?= $(STD) $(SECURITY) $(WARN) $(UNWARN)

# END OF CONFIGURABLE PART

DEPS_PATH := ./deps
SDL_PATH := $(DEPS_PATH)/sdl2
LUA_PATH := $(DEPS_PATH)/lua

CC_VERSION := $(shell $(CC) --version | head -1 | cut -f1 -d' ')

ifeq ($(OS),Windows_NT)
	CFLAGS += -DWIN32
	ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
		CFLAGS += -DAMD64
	endif
	ifeq ($(PROCESSOR_ARCHITECTURE),x86)
		CFLAGS += -DIA32
	endif
else
	UNAME_S := $(shell uname -s)

	ifeq ($(UNAME_S),Linux)
		CFLAGS += -DLINUX
	endif
	ifeq ($(UNAME_S),Darwin)
		CFLAGS += -DOSX
	endif

	ifneq (,$(findstring clang,$(CC_VERSION)))
		CFLAGS += -DCLANG

		# -pthread is not necessary when using Clang on Darwin
		ifneq ($(UNAME_S),Darwin)
			CFLAGS += -pthread
		endif
	else
		CFLAGS += -DGCC
		CFLAGS += -pthread

		# at least on OS X 10.7.5, the apple linker does not understand AVX, and gcc uses it natively
		# fixed: http://mac-os-forge.2317878.n4.nabble.com/gcc-as-AVX-binutils-and-MacOS-X-10-7-td144472.html
		ifeq ($(UNAME_S),Darwin)
			# CFLAGS += -mno-avx
		endif

		# required for the math libraries (threedee and sse_mathfun.h)
		CFLAGS += -mfpmath=sse
	endif

	UNAME_P := $(shell uname -m)

	ifeq ($(UNAME_P),x86_64)
		CFLAGS += -DAMD64
	endif
	ifneq ($(filter %86,$(UNAME_P)),)
		CFLAGS += -DIA32
	endif
	ifneq ($(filter arm%,$(UNAME_P)),)
		CFLAGS += -DARM
	endif
endif

# clang doesn't perform link-time optimization without the gold linker, which as of yet
# is not the default, so for now I'm not bothering to make a wrapper script to make it
# use the gold linker. So don't perform LTO with clang for now. The slp vectorizer is cool though
ifneq (,$(findstring clang,$(CC_VERSION)))
	OPT += -fslp-vectorize
else
	OPT += -flto
endif

INCS := -I$(SDL_PATH)/include \
	-I/usr/include/malloc \
	-I/usr/X11R6/include \
	-I./src \
	-I./src/gfx \
	-I./src/util

LIBS := $(SDL_PATH)/build/.libs/libSDL2.a $(SDL_PATH)/build/libSDL2main.a \
	-lm -liconv \
	-framework Cocoa -framework Carbon -framework OpenGL \
	-framework CoreAudio -framework AudioToolbox -framework AudioUnit \
	-framework ForceFeedback -framework IOKit

EXECUTABLE := prototype
SOURCE := src/main.c \
	src/util.c \
	src/zmalloc.c \
	src/version.c \
	src/stb_image.c \
	src/texture.c \
	src/gfx/shader.c \
	src/gfx/model.c \
	src/gfx/renderer.c \
	src/gfx/drawlist.c \
	src/gfx/perf.c \
	src/scratch.c

DEPENDENCY_TARGETS := sdl2

ifeq ($(ENABLE_LUA), 1)
	INCS += -I$(LUA_PATH)/src
	LIBS += $(LUA_PATH)/src/libluajit.a
	DEPENDENCY_TARGETS += lua
	CFLAGS += -DHAVE_LUA
	SOURCE += src/scripting.c
endif

OBJECTS=$(patsubst src%.c,build%.o, $(SOURCE))

all: debug

debug: CFLAGS += -O $(DEBUG)
debug: $(EXECUTABLE)

release: CFLAGS += $(DEBUG) $(OPT)
release: $(EXECUTABLE)

# main executable(s)

$(EXECUTABLE): $(OBJECTS)
		-$(MAKE) -C $(DEPS_PATH) -j4 $(DEPENDENCY_TARGETS) CC=$(CC)
		install -d build
		$(CC) -o $@ $^ $(LIBS) $(CFLAGS) -pagezero_size 10000 -image_base 100000000

# tests

timer_query: CFLAGS += -O $(DEBUG)
timer_query: test/timer_query.c build/util.o build/zmalloc.o
	$(CC) -o $@ $^ $(LIBS) $(CFLAGS) $(INCS) -pagezero_size 10000 -image_base 100000000

# object files

# stb_image doesn't conform to C11, so it provokes a lot of warnings, turn off
# warnings for this one file
build/stb_image.o: src/stb_image.c
		$(CC) -c $< -o $@ $(filter-out $(WARN),$(CFLAGS)) -fno-strict-aliasing $(INCS)

# zmalloc.c needs -fno-strict-aliasing unfortunately, so we have a special rule for it
build/zmalloc.o: src/zmalloc.c
		$(CC) -c $< -o $@ $(CFLAGS) -fno-strict-aliasing $(INCS)

build/%.o: src/%.c
	@mkdir -p $(dir $@)
	$(CC) -c $< -o $@ $(CFLAGS) $(INCS)

clean:
	rm -rf build/* || true
	rm -f $(EXECUTABLE) || true

.PHONY: all debug release
