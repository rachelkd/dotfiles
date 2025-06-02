CC=clang
CFLAGS=-std=c99 -Wall
FRAMEWORKS=-framework CoreFoundation
INCLUDES=-I..
TARGET=clock

all: $(TARGET)

$(TARGET): clock.c ../sketchybar.h
	$(CC) $(CFLAGS) clock.c $(FRAMEWORKS) -o $(TARGET)

clean:
	rm -f $(TARGET)