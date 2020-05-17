
duh:
	@echo "What'll it be?  rocket lint_rocket ufo lint_ufo all"

all:    rocket lint_rocket ufo lint_ufo

rocket: FORCE
	mkdir -p rocket
	rm -f rocket/*.lsl
	./lslconf.pl rocket.lslc source rocket
	rm rocket/ufo.lsl

lint_rocket:
	find rocket -name \*.lsl -exec echo {} \; -exec lslint {} \;

ufo:    FORCE
	mkdir -p ufo
	rm -f ufo/*.lsl
	./lslconf.pl ufo.lslc source ufo

lint_ufo:
	find ufo -name \*.lsl -exec echo {} \; -exec lslint {} \;


FORCE:
