import logi
import time

a = logi.logiRead(0x0200, 6)
available = a[2]+(a[3] << 8) +(a[4] << 16 )+(a[5] << 24)
print available

a=logi.logiRead(0x1001, 2)
flushed = a[0]+(a[1]<<8)
print "flushed : "+str(flushed)

a=logi.logiRead(0x1000, 2)
refreshed = a[0]+(a[1]<<8)
print "refreshed : "+str(refreshed)

a=logi.logiRead(0x1002, 2)
refreshed = a[0]+(a[1]<<8)
print "refresh address : "+str(refreshed)


no_error = True 
old_val = -1
dist_between_errors = 0
last_error = 0
count = 0
#time.sleep(2)
while no_error and available > 0 :
	data = logi.logiRead(0x0000, 1024)
	for j in range(512):
		val = data[j*2]+(data[(j*2)+1] << 8)
		#print val
		count = count + 1
		if old_val >= 0 and (val - old_val) > 1:
			a=logi.logiRead(0x1000, 2)
                	refreshed = a[0]+(a[1]<<8)
                	print "refreshed : "+str(refreshed)
                	a=logi.logiRead(0x1002, 2)
                	refreshed = a[0]+(a[1]<<8)
                	print "refresh address : "+str(refreshed)
			print "error, val="+str(val)+", old_val="+str(old_val)
			print "fifo is offseted by "+str(val-old_val)
			dist_between_errors = val - last_error
			last_error = val
			print "distance between errors is : "+str(dist_between_errors)
			no_error = False
			break
		elif old_val == val:
			no_error = False
			break 
		old_val = val
		#time.sleep(0.001)
		#a = logi.logiRead(0x0200, 6)
		#available = a[2]+(a[3] << 8) +(a[4] << 16 )+(a[5] << 24)
	
		#if count == 128 or count == 256 or count == (128+256) or count == 512:	
		#	a=logi.logiRead(0x1000, 2)
		#	refreshed = a[0]+(a[1]<<8)
		#	print "refreshed : "+str(refreshed)
		#	a=logi.logiRead(0x1002, 2)
		#	refreshed = a[0]+(a[1]<<8)
		#	print "refresh address : "+str(refreshed)

	
		if count == 511 :
			count = 0
		#time.sleep(1)
