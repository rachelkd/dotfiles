#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <time.h>

#include "../sketchybar.h"

void callback(CFRunLoopTimerRef timer, void* info) {
    time_t current_time;
    time(&current_time);
    const char* format = "%a %b %-d %-I:%M:%S %p";
    char buffer[64];
    strftime(buffer, sizeof(buffer), format, localtime(&current_time));

    uint32_t message_size = sizeof(buffer) + 64;
    char message[message_size];
    snprintf(message, message_size, "--set time label=\"%s\" icon=􀧞", buffer);

    sketchybar(message);
}

int main() {
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault, (int64_t)CFAbsoluteTimeGetCurrent() + 1.0, 1.0, 0, 0, callback, NULL);
    CFRunLoopAddTimer(CFRunLoopGetMain(), timer, kCFRunLoopDefaultMode);
    sketchybar("--add item time right");

    const char* background = getenv("BACKGROUND");
    if (background == NULL) {
        background = "";
    }
    char command[128];
    snprintf(command, sizeof(command), "--set time background.color=%s label.padding_right=6", background);
    sketchybar(command);

    CFRunLoopRun();
    return 0;
}