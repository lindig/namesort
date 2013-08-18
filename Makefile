#
# Makefile
#
# Namesort - a tool to sort people's names by last name.
# 
# The source code is written as a literate program using Lipsum as a tool.
# Lipsum is available from https://github.com/lindig/lipsum. Try
#
#   make lipsum
#
# to build it and edit the definition of LP below to use it.
#

LP		= ./lipsum/lipsum
LP 		= lipsum
OCB 		= ocamlbuild
PREFIX		= /usr/local

SRC 		= namesort.mll
SRC		+= 

DOC		= README.md namesort.pod namesort.1 test.txt

all: 		$(SRC) $(DOC)
		$(OCB) namesort.native
		mv namesort.native namesort

debug:		$(SRC)
		$(OCB) namesort.d.byte

profile:	$(SRC)
		$(OCB) namesort.p.native

test:		all test.txt
		./namesort -d test.txt
		./namesort    test.txt

clean: 		
		$(OCB) -clean
		rm -f $(SRC) $(DOC)
		rm -f gmon.out
		rm -f test.txt
		# rm -f lipsum

install:	all
		install namesort    $(PREFIX)/bin
		install namesort.1  $(PREFIX)/share/man/man1

%.ml:		namesort.lp
		$(LP) tangle -f cpp $@ $< > $@

%.mli:		namesort.lp
		$(LP) tangle -f cpp $@ $< > $@

%.mll:		namesort.lp
		$(LP) tangle -f cpp $@ $< > $@

README.md: 	namesort.lp
		$(LP) weave $< > $@

test.txt:	namesort.lp
		$(LP) tangle $@ $< > $@

%.pod:		namesort.lp	
		$(LP) tangle -f cpp $@ $< > $@

%.1:		%.pod
		pod2man --section=1 --name=$* $< > $@

lipsum:
		git clone https://github.com/lindig/lipsum
		$(MAKE) -C lipsum

