EXTRA_DIR:=extra
COQDOCFLAGS:= \
  --external 'http://ssr2.msr-inria.inria.fr/doc/ssreflect-1.5/' Ssreflect \
  --external 'http://ssr2.msr-inria.inria.fr/doc/mathcomp-1.5/' MathComp \
  --toc --toc-depth 2 --html --interpolate \
  --index indexpage --no-lib-name --parse-comments \
  --with-header $(EXTRA_DIR)/header.html --with-footer $(EXTRA_DIR)/footer.html
export COQDOCFLAGS

.PHONY: all coq clean html phony
all: coq

fundamental: Makefile.coq
	$(MAKE) -f Makefile.coq pretty-timed only TGTS="theories/fundamental.vo"

coq: Makefile.coq
	$(MAKE) -f Makefile.coq pretty-timed

html: Makefile.coq
	rm -rf html
	$(MAKE) -f Makefile.coq html
	cp $(EXTRA_DIR)/resources/* html

Makefile.coq:
	coq_makefile -f _CoqProject -o Makefile.coq

clean: Makefile.coq
	$(MAKE) -f Makefile.coq clean
	rm -f Makefile.coq
	rm -rf html

# Install build-dependencies
build-dep/opam: opam Makefile
	@echo "# Creating build-dep package."
	@mkdir -p build-dep
	@sed <opam -E 's/^(build|install|remove):.*/\1: []/; s/^name: *"(.*)" */name: "\1-builddep"/' >build-dep/opam
	@fgrep builddep build-dep/opam >/dev/null || (echo "sed failed to fix the package name" && exit 1) # sanity check

build-dep: build-dep/opam phony
	@# We want opam to not just instal the build-deps now, but to also keep satisfying these
	@# constraints.  Otherwise, `opam upgrade` may well update some packages to versions
	@# that are incompatible with our build requirements.
	@# To achieve this, we create a fake opam package that has our build-dependencies as
	@# dependencies, but does not actually install anything itself.
	@echo "# Pinning build-dep package." && \
	  if opam --version | grep "^1\." -q; then \
	    BUILD_DEP_PACKAGE="$$(egrep "^name:" build-dep/opam | sed 's/^name: *"\(.*\)" */\1/')" && \
	    opam pin add -k path $(OPAMFLAGS) "$$BUILD_DEP_PACKAGE".dev build-dep && \
	    opam reinstall --verbose $(OPAMFLAGS) "$$BUILD_DEP_PACKAGE"; \
	  else \
	    opam install --verbose $(OPAMFLAGS) build-dep/; \
	  fi

Makefile: ;
_CoqProject: ;
opam: ;
