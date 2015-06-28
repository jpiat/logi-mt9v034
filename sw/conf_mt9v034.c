#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>
#include <linux/types.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>
#include <string.h> 
#include <math.h>

//I2C
#define CAM_ADDR	0x48


int i2c_fd ;

int init_i2c(int nb);

static inline void i2c_set_register(unsigned char reg_addr, unsigned short reg_value)
{
	unsigned char i2c_buffer[3];

	if (ioctl(i2c_fd, I2C_SLAVE, CAM_ADDR) < 0) {
		printf("cannot reach slave \n");
		return ; 
	}

	i2c_buffer[0] = reg_addr;
	i2c_buffer[1] = (reg_value >> 8) & 0xFF ;
	i2c_buffer[2] = (reg_value & 0xFF );
	write(i2c_fd, i2c_buffer, 3);
}



int init_i2c(int nb){
  char filename[20];   
  int file ;   
  snprintf(filename, 19, "/dev/i2c-%d", nb);
  i2c_fd = open(filename, O_RDWR);
  if (i2c_fd < 0) {
   	return -1 ;
  /* ERROR HANDLING; you can check errno to see what went wrong */
  }
}


int main(int argc, char ** argv){
	char c ;
	init_i2c(1);
	printf("start of register programming \n");
	i2c_set_register(0x0C, 0x0001); //soft reset
	i2c_set_register(0x0C, 0x0000); //soft reset
	i2c_set_register(0xB1, 0x0000);
	i2c_set_register(0xB2, 0x0000);
	i2c_set_register(0xB5, 0x0000); //generate sync pattern with 0 and start stop 	
	i2c_set_register(0xB6, 0x0000);
	i2c_set_register(0x04, 640); //window width
	i2c_set_register(0x03, 480); //window height
	i2c_set_register(0x01, 1); // col start
	i2c_set_register(0x02, 4); //row start
	i2c_set_register(0x07, ((1 << 3)|(1 << 8)|(1 << 9)));//chip control, disable parallel output, other are default
	i2c_set_register(0x72, 0x0000); //sync ctrl
	//i2c_set_register(0x7F, ((1 << 13) | (1 << 10) | (1 << 5))); //test pattern
	i2c_set_register(0x7F, 0x00);
	printf("end of register programming \n");
	close(i2c_fd);
	return 1;
}
