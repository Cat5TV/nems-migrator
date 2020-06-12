#!/usr/bin/python
import sys
import smbus
import RPi.GPIO as GPIO
rev = GPIO.RPI_REVISION
if rev == 2 or rev == 3:
	bus = smbus.SMBus(1)
else:
	bus = smbus.SMBus(0)
if len(sys.argv)>1:
	bus.write_byte(0x1a,0)
	if sys.argv[1] == "poweroff" or sys.argv[1] == "halt":
		try:
			bus.write_byte(0x1a,0xFF)
		except:
			rev=0
