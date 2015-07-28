CC = gcc
C_FLAGS = -O3 
LD_FLAGS = -lc -ljpeg -llogi

all: conf_mt9v034

clean:
	rm -f *.a *.o conf_mt9v034

conf_mt9v034 : conf_mt9v034_logi_i2c.c
	$(CC) $(C_FLAGS) -o $@ conf_mt9v034_logi_i2c.c $(LD_FLAGS)

