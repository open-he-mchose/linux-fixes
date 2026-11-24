# SPDX-License-Identifier: MIT
# Build the MCHOSE NKRO descriptor fix (HID-BPF). Needs: clang, bpftool, libbpf headers, a C compiler,
# and a kernel with BTF (/sys/kernel/btf/vmlinux).
CLANG   ?= clang
BPFTOOL ?= bpftool
CC      ?= cc
ARCH    := $(shell uname -m | sed -e 's/x86_64/x86/' -e 's/aarch64/arm64/' -e 's/riscv64/riscv/')

all: mchose-nkro-fix-loader

vmlinux.h:
	$(BPFTOOL) btf dump file /sys/kernel/btf/vmlinux format c > $@

mchose_nkro_fix.bpf.o: mchose_nkro_fix.bpf.c vmlinux.h
	$(CLANG) -O2 -g -target bpf -D__TARGET_ARCH_$(ARCH) -I. -c $< -o $@

mchose_nkro_fix.skel.h: mchose_nkro_fix.bpf.o
	$(BPFTOOL) gen skeleton $< name mchose_nkro_fix_bpf > $@

mchose-nkro-fix-loader: loader.c mchose_nkro_fix.skel.h
	$(CC) -O2 -Wall -I. $< -lbpf -o $@

clean:
	rm -f vmlinux.h mchose_nkro_fix.bpf.o mchose_nkro_fix.skel.h mchose-nkro-fix-loader

.PHONY: all clean
