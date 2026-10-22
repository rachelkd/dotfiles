CC=clang
CFLAGS=-Wall -fobjc-arc
FRAMEWORKS=-framework AppKit -framework CoreMedia -framework CoreVideo -framework QuartzCore -framework ScreenCaptureKit
TARGET=bar_blend

all: $(TARGET)

$(TARGET): bar_blend.m ../sketchybar.h
	$(CC) $(CFLAGS) bar_blend.m $(FRAMEWORKS) -o $(TARGET)

clean:
	rm -f $(TARGET)
