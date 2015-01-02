# -*- Makefile -*-
NAME	= make-macosx-iso
BINDIR	= /usr/local/bin
VERSION	= $(shell git describe --tags 2>/dev/null || echo unknown)

install:
	rm -f $(BINDIR)/$(NAME)
	sed -e 's/%%VERSION%%/$(VERSION)/g' < $(NAME).sh > $(BINDIR)/$(NAME)
	chmod a+rx $(BINDIR)/$(NAME)
