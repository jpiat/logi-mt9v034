#include <stdlib.h>
#include <stdio.h>
#include "logilib.h"

#define BURST_SIZE 128

#define FIFO_BASE_ADDR 0x200


short buffer [128] ;


char * yuv_buffer ;
char * rgb_buffer ;


int min(int a, int b){
	return (a > b ? b : a) ;
}

void yuv_to_rgb(char * buffer, char * picture, int height, int width){
	int i ;	
	float y, u, v ;
	float r, g, b ;
	for(i = 0 ; i < width*height ; i ++){
		y = (float) buffer[(i*2)] ;
		if(i%2 == 0){
			u = (float) buffer[(i*2)+1];
			v = (float) buffer[(i*2)+3];
		}else{
			u = (float) buffer[(i*2)-1];
	        	v = (float) buffer[(i*2)+1];
		}
		r =  y + (1.4075 * (v - 128.0));
		g =  y - (0.3455 * (u - 128.0)) - (0.7169 * (v - 128.0));
		b =  y + (1.7790 * (u - 128.0)) ;
		picture[(i*3)] = (unsigned char) abs(min(r, 255)) ;
		picture[(i*3)+1] = (unsigned char) abs(min(g, 255)) ;
		picture[(i*3)+2] = (unsigned char) abs(min(b, 255)) ;
	}
}



int main(int argc, char ** argv){
	unsigned int available, total, avail_new, avail_old;
	unsigned short cmd_word, sync_value ;
	int count ;
	unsigned int available_before, cmd_long ;
	FILE * pic_fd, * jpeg_fd ;
	if(argc < 2){
		printf("Specify output path \n");
		return 0 ;
	}
	yuv_buffer = malloc(640*480*2+4);
	rgb_buffer = malloc(640*480*3);

	pic_fd  = fopen("image.rgb", "wb");
	jpeg_fd  = fopen(argv[1], "wb");
	logi_open();
	cmd_word = 0 ;
	logi_read((unsigned char *) &cmd_long,sizeof(int),0x1000);
	printf("sync errors : %x \n", cmd_long);
	cmd_word = 1 ;
	logi_write((unsigned char *) &cmd_word,sizeof(short),0x1000);//hold reset on Y2Fifo
	cmd_word = 0x00 ;
	logi_read((unsigned char *) &available, sizeof(int), FIFO_BASE_ADDR);
        printf("%u size \n", available);
	logi_write((unsigned char *) &cmd_word,sizeof(short),FIFO_BASE_ADDR+1);//reset fifo
	logi_write((unsigned char *) &cmd_word,sizeof(short),FIFO_BASE_ADDR+2);

	logi_read((unsigned char *) &available, sizeof(int), FIFO_BASE_ADDR+1);
	printf("%u available \n", available);
	cmd_word = 0 ;
        logi_write((unsigned char *) &cmd_word,sizeof(short),0x1000);//de-assert reset on Y2Fifo
	total = available ;
	printf("start capture \n");
	while(available < (640*480)+2){
		logi_read((unsigned char *) &available, sizeof(int), FIFO_BASE_ADDR+1);
		//printf("%u available \n", available);
	}
	cmd_word = 1 ;
        logi_write((unsigned char *) &cmd_word,sizeof(short),0x1000);//hold reset on Y2Fifo
	logi_read((unsigned char *) &available, sizeof(int), FIFO_BASE_ADDR+1);
	printf("%u available \n", available);
	available_before = available ;
	count = 0 ;
	while(count < (640*480*2)+4){
		if(available > BURST_SIZE){
			logi_read((unsigned char *) &avail_old, sizeof(int), FIFO_BASE_ADDR+1);
			logi_read(&yuv_buffer[count], BURST_SIZE*2, 0x0000);
			logi_read((unsigned char *) &avail_new, sizeof(int), FIFO_BASE_ADDR+1);
			//printf("read : %u\n", (avail_old - avail_new));
			if((avail_old - avail_new) != BURST_SIZE){
				printf("fifo read problem : %u\n", (avail_old - avail_new));
			}
			available -= BURST_SIZE ;
			count += BURST_SIZE*2 ;
		}else{
			logi_read((unsigned char *) &avail_old, sizeof(int), FIFO_BASE_ADDR+1);
			logi_read(&yuv_buffer[count], available*2, 0x0000);
			logi_read((unsigned char *) &avail_new, sizeof(int), FIFO_BASE_ADDR+1);
                        //printf("read remaining: %u \n", (avail_old - avail_new));
			if((avail_old - avail_new) != available){
                                printf("fifo read problem : %u\n", (avail_old - avail_new));
                        }
			count += available*2;
			available = 0 ;
		}
	}
	logi_read((unsigned char *) &available, sizeof(int), FIFO_BASE_ADDR+1);
	printf("read : %u, left : %u \n", (640*480)+2, available);
	if((available_before - (count/2)) != available){
		printf("Fifo access problem ! Data will be corrupted \n");
		printf("There was %d missed accesses \n", (available_before - (count/2)-available));
	}
	sync_value = 0x00 ;
	sync_value = *((short *) &yuv_buffer[0]);
	if(sync_value != 0x55AA){
		printf("sync error ! \n");
		printf("value is %x \n", sync_value);
		sync_value = *((short *) &yuv_buffer[1]);
		printf("value + 1 is %x \n", sync_value);
		fclose(pic_fd);
        	fclose(jpeg_fd);
		free(yuv_buffer);
		free(rgb_buffer);
		return -1 ;
	}
	//printf("sync value %x \n", sync_value);
	yuv_to_rgb(&yuv_buffer[2], rgb_buffer, 480, 640);
	//fwrite(rgb_buffer, 1, 640*480*3, pic_fd);
	write_jpegfile(rgb_buffer, 640, 480, 3, jpeg_fd, 100);
	free(yuv_buffer);
        free(rgb_buffer);
	fclose(pic_fd);
	fclose(jpeg_fd);
	logi_close();
}


