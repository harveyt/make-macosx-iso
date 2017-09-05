# -*- Makefile -*-
NAME		= make-macosx-iso
BINDIR		= /usr/local/bin
NAME_SRC	= $(NAME).sh
NAME_DEST	= $(BINDIR)/$(NAME)

VERSION	= $(shell git describe --tags 2>/dev/null || echo unknown)

install: $(NAME_DEST)

$(NAME_DEST): $(NAME_SRC) Makefile
	@echo "Installing $(NAME) as $(NAME_DEST) ..."
	@rm -f $(NAME_DEST)
	@awk '/%%README%%/ {								\
		while ((getline line < "README.md") > 0 && line !~ /^Copyright/)	\
			printf("# %s\n", line);						\
		next;									\
	}										\
	/%%LICENSE%%/ {									\
		while ((getline line < "LICENSE") > 0)					\
			 printf("# %s\n", line);					\
		next;									\
	}										\
	{ sub(/%%VERSION%%/, "$(VERSION)", $$0); print $$0; }' \
		$(NAME_SRC) > $(NAME_DEST)
	@chmod a+rx $(NAME_DEST)
	@echo "Done"

clean:
	rm -f *~

clobber:
	rm -f $(NAME_DEST)
