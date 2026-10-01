# make: builds the GPU renderer into the paclet (macOS, Apple silicon)
WOLFRAM ?= /Applications/Wolfram 15.0.app/Contents
INC = $(WOLFRAM)/SystemFiles/IncludeFiles/C
OUT = ../WAnim/LibraryResources/MacOSX-ARM64/libwanimgpu.dylib
SRC = wxf.c scene.c text.c link.c metal.m

$(OUT): $(SRC) wanimgpu.h
	mkdir -p $(dir $(OUT))
	clang -O2 -Wall -Wno-misleading-indentation -fobjc-arc -dynamiclib -I"$(INC)" $(SRC) \
	  -framework Metal -framework Foundation -framework CoreText -framework CoreGraphics -o $(OUT)
