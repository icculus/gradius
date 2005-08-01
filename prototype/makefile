EXE := gradius
SRCS := gradius.bas
OBJS := $(SRCS:.bas=.o)
BASFLAGS := -exx -g -m gradius -r


all: $(EXE)

.PHONY: clean all

clean:
	rm -f $(OBJS) $(EXE)

%.o : %.bas
	fbc $(BASFLAGS) -c -o $@ $<

$(EXE) : $(OBJS)
	fbc $(BASFLAGS) -o $@ $(OBJS) -l SDL

# end of makefile ...

