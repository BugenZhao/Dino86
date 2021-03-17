var emulator = new V86Starter({
    screen_container: document.getElementById("screen_container"),
    bios: {
        url: "bios/seabios.bin",
    },
    vga_bios: {
        url: "bios/vgabios.bin",
    },
    fda: {
        url: "dino86.img",
    },
    autostart: true,
});
