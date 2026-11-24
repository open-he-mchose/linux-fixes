# SPDX-License-Identifier: MIT
#   make                         build the HID-BPF loader (as a normal user)
#   sudo make install            install the fix + udev rules, reload udev, attach to the connected keyboard
#   sudo make install-systemd    also install a boot-time systemd service (fallback for the udev rule)
#   sudo make uninstall          remove everything and restore the original descriptor
#   sudo make uninstall-legacy   remove files of the old jet75-hid-fix installation
PREFIX  ?= /usr/local
SBINDIR ?= $(PREFIX)/sbin
UDEVDIR ?= /etc/udev/rules.d
UNITDIR ?= /etc/systemd/system

all:
	$(MAKE) -C nkro-fix

install: all uninstall-legacy
	install -Dm755 nkro-fix/mchose-nkro-fix-loader $(DESTDIR)$(SBINDIR)/mchose-nkro-fix-loader
	install -Dm755 nkro-fix/mchose-nkro-fix $(DESTDIR)$(SBINDIR)/mchose-nkro-fix
	install -Dm644 udev/70-mchose-hidraw.rules $(DESTDIR)$(UDEVDIR)/70-mchose-hidraw.rules
	sed 's|@SBINDIR@|$(SBINDIR)|g' udev/71-mchose-nkro-fix.rules.in > 71-mchose-nkro-fix.rules
	install -Dm644 71-mchose-nkro-fix.rules $(DESTDIR)$(UDEVDIR)/71-mchose-nkro-fix.rules
	rm -f 71-mchose-nkro-fix.rules
ifeq ($(DESTDIR),)
	udevadm control --reload
	udevadm trigger --action=change --subsystem-match=hidraw --attr-match=idVendor=41e4 || true
	$(SBINDIR)/mchose-nkro-fix load
endif

install-systemd:
	sed 's|@SBINDIR@|$(SBINDIR)|g' systemd/mchose-nkro-fix.service.in > mchose-nkro-fix.service
	install -Dm644 mchose-nkro-fix.service $(DESTDIR)$(UNITDIR)/mchose-nkro-fix.service
	rm -f mchose-nkro-fix.service
ifeq ($(DESTDIR),)
	systemctl daemon-reload
	systemctl enable mchose-nkro-fix.service
endif

uninstall:
	-[ -x $(SBINDIR)/mchose-nkro-fix ] && $(SBINDIR)/mchose-nkro-fix unload
	-[ -e $(UNITDIR)/mchose-nkro-fix.service ] && systemctl disable mchose-nkro-fix.service
	rm -f $(DESTDIR)$(UNITDIR)/mchose-nkro-fix.service
	rm -f $(DESTDIR)$(SBINDIR)/mchose-nkro-fix $(DESTDIR)$(SBINDIR)/mchose-nkro-fix-loader
	rm -f $(DESTDIR)$(UDEVDIR)/71-mchose-nkro-fix.rules $(DESTDIR)$(UDEVDIR)/70-mchose-hidraw.rules
ifeq ($(DESTDIR),)
	udevadm control --reload
endif

# Files of the earlier Jet75-only version (jet75-hid-fix). An attached link stays active until the
# keyboard is unplugged; the new script recognises it.
uninstall-legacy:
	rm -f $(DESTDIR)/usr/local/sbin/jet75-hid-fix $(DESTDIR)/usr/local/sbin/jet75-hid-fix-loader
	rm -f $(DESTDIR)$(UDEVDIR)/71-jet75-hid-fix.rules $(DESTDIR)$(UDEVDIR)/70-jet75.rules

clean:
	$(MAKE) -C nkro-fix clean

.PHONY: all install install-systemd uninstall uninstall-legacy clean
