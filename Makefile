.PHONY: all clean

all:
	$(MAKE) -C fhe-programs/src all

clean:
	$(MAKE) -C fhe-programs/src clean

# Default target: pass all to the sub-makefile
%:
	$(MAKE) -C fhe-programs/src $*
