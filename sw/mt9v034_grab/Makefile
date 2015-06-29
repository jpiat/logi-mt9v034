CC = gcc
C_FLAGS = -O3 
LD_FLAGS = -lc -ljpeg -llogi

all: grab

clean:
	rm -f *.a *.o grab

grab : mt9v034_grab.c jpeg_func.c
	$(CC) $(C_FLAGS) -o $@ mt9v034_grab.c jpeg_func.c $(LD_FLAGS)

