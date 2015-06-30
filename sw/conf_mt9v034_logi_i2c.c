#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>
#include <string.h> 
#include <math.h>

#include "logilib.h"

//I2C
#define CAM_ADDR	0x48


int i2c_fd ;

int init_i2c();



static inline void i2c_set_register(unsigned char reg_addr, unsigned short reg_value)
{
	short buffer ;
	buffer = 0x0001 ;
	while((buffer & 0x01) != 0x00 && (buffer & 0x02) != 0x02 ){
		logi_read(&buffer, 2, I2C_ADDR+1);
	}
	if((buffer & 0x02) == 0x02){
		printf("NACK error !\n");
		buffer = (CAM_ADDR << 8) | 0x01;
		logi_write(&buffer, 2, I2C_ADDR+1);
		buffer = (CAM_ADDR << 8) ;
		logi_write(&buffer, 2, I2C_ADDR+1);
		return  ;
	}

	buffer = (CAM_ADDR << 8);
        logi_write(&buffer, 2, I2C_ADDR+1); // disable master
		
	buffer =reg_addr ; // write to fifo
	logi_write(&buffer, 2, I2C_ADDR);
		
	buffer = (reg_value >> 8) & 0xFF;
        logi_write(&buffer, 2, I2C_ADDR);
	
	buffer = (reg_value & 0xFF);
        logi_write(&buffer, 2, I2C_ADDR);
		
	buffer =(CAM_ADDR << 8) | 0x02; 
	logi_write(&buffer, 2, I2C_ADDR+1); //enable master
}





int init_i2c(){
	unsigned int i=0 ;
	unsigned short buffer ;
	buffer = CAM_ADDR << 8 | 0x01
	logi_write(&buffer, 2, I2C_ADDR+1);
	buffer = CAM_ADDR << 8  ;
        logi_write(&buffer, 2, I2C_ADDR+1);
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
	i2c_set_register(0x0D, (1 << 4));
	i2c_set_register(0x07, ((1 << 3)|(1 << 8)|(1 << 9)));//chip control, disable parallel output, other are default
	i2c_set_register(0x72, 0x0000); //sync ctrl
	//i2c_set_register(0x7F, ((1 << 13) | (1 << 10) | (1 << 5))); //test pattern
	i2c_set_register(0x7F, 0x00);
	printf("end of register programming \n");
	return 1;
}
