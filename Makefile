all: dos image

binary: dino86.asm
	nasm -f bin dino86.asm -o dino86.bin -l dino86_boot.lst -O2 -Wall -DBOOTSECTOR

dos: dino86.asm
	nasm -f bin dino86.asm -o dino86.com -l dino86_dos.lst -O2 -Wall

image: binary
	dd if=/dev/zero of=./dino86.img bs=512 count=320
	dd if=./dino86.bin of=./dino86.img conv=notrunc

clean:
	rm -rf *.bin *.lst

run: image
	qemu-system-i386 -fda dino86.img
