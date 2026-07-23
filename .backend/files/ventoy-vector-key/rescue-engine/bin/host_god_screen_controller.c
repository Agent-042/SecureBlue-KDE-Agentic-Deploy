/*
 * Host OS "God Mode" Screen & Input Controller in C
 * Uses Linux /dev/uinput kernel API to synthesize mouse move/click and keyboard input events on Wayland / SecureBlue host.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <linux/uinput.h>

void emit(int fd, int type, int code, int val) {
    struct input_event ie;
    memset(&ie, 0, sizeof(ie));
    ie.type = type;
    ie.code = code;
    ie.value = val;
    write(fd, &ie, sizeof(ie));
}

int setup_uinput_device() {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        perror("[!] Failed to open /dev/uinput");
        return -1;
    }

    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_REL);
    ioctl(fd, UI_SET_RELBIT, REL_X);
    ioctl(fd, UI_SET_RELBIT, REL_Y);
    ioctl(fd, UI_SET_KEYBIT, BTN_LEFT);
    ioctl(fd, UI_SET_KEYBIT, BTN_RIGHT);

    for (int key = KEY_RESERVED; key <= KEY_MIN_INTERESTING; key++) {
        ioctl(fd, UI_SET_KEYBIT, key);
    }
    for (int key = KEY_ESC; key <= KEY_MICMUTE; key++) {
        ioctl(fd, UI_SET_KEYBIT, key);
    }

    struct uinput_setup usetup;
    memset(&usetup, 0, sizeof(usetup));
    usetup.id.bustype = BUS_USB;
    usetup.id.vendor = 0x1234;
    usetup.id.product = 0x5678;
    strcpy(usetup.name, "SecureBlue God Mode Input Controller");

    if (ioctl(fd, UI_DEV_SETUP, &usetup) < 0) {
        perror("[!] UI_DEV_SETUP failed");
        close(fd);
        return -1;
    }

    if (ioctl(fd, UI_DEV_CREATE) < 0) {
        perror("[!] UI_DEV_CREATE failed");
        close(fd);
        return -1;
    }

    usleep(200000); // 200ms warm up
    return fd;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage:\n");
        printf("  %s --move <DX> <DY>\n", argv[0]);
        printf("  %s --click\n", argv[0]);
        printf("  %s --key <KEY_CODE>\n", argv[0]);
        return 1;
    }

    int fd = setup_uinput_device();
    if (fd < 0) return 1;

    if (strcmp(argv[1], "--move") == 0 && argc >= 4) {
        int dx = atoi(argv[2]);
        int dy = atoi(argv[3]);
        printf("[*] Moving mouse by (%d, %d)...\n", dx, dy);
        emit(fd, EV_REL, REL_X, dx);
        emit(fd, EV_REL, REL_Y, dy);
        emit(fd, EV_SYN, SYN_REPORT, 0);
        printf("[+] Mouse moved successfully.\n");
    } else if (strcmp(argv[1], "--click") == 0) {
        printf("[*] Sending left click...\n");
        emit(fd, EV_KEY, BTN_LEFT, 1);
        emit(fd, EV_SYN, SYN_REPORT, 0);
        usleep(50000);
        emit(fd, EV_KEY, BTN_LEFT, 0);
        emit(fd, EV_SYN, SYN_REPORT, 0);
        printf("[+] Left click sent successfully.\n");
    } else if (strcmp(argv[1], "--key") == 0 && argc >= 3) {
        int keycode = atoi(argv[2]);
        printf("[*] Sending keycode %d...\n", keycode);
        emit(fd, EV_KEY, keycode, 1);
        emit(fd, EV_SYN, SYN_REPORT, 0);
        usleep(50000);
        emit(fd, EV_KEY, keycode, 0);
        emit(fd, EV_SYN, SYN_REPORT, 0);
        printf("[+] Keycode %d sent successfully.\n", keycode);
    }

    ioctl(fd, UI_DEV_DESTROY);
    close(fd);
    return 0;
}
