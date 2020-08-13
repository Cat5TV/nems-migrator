#!/usr/bin/env python

# Created 09/2016 by Kalle (mddka at web.de)

# This plugin is created for monitoring
# Juniper SRX240 FRU status / NETWORKs transfer speeds / SYSTEM Usage / SPU Usage / TEMPS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# Last modification 17.10.2016 -> Bugfix Network speed calculation

import optparse
import datetime
import sys
import re
import os
import time
import netsnmp
import subprocess
import shlex
import json
from math import log

RETURNSTRINGS = {0 : "OK", 1 : "WARNING", 2 : "CRITICAL", 3 : "UNKNOWN", -1 : "UNKNOWN"}

RETURNCODE = { 'OK': 0, 'WARNING' : 1, 'CRITICAL' : 2, 'UNKNOWN' : 3, 'UNKNOWN' : -1}

FRUTYPE = {1 : "other", 2 : "clockGEnerator", 3 : "flexiblePicConcentrator", 4 : "switchingAndForwardingModule", 5 : "controlBoard", 6 : "routingEngine", 7 : "powerEntryModule", 8 : "frontPanelModule",\
           9 : "switchInterfaceBoard", 10 : "processorMezzanineBoardForSIB", 11 : "portInterfaceCard", 12 : "craftInterfacePanel", 13 : "fan"}

FRUSTATE = {1 : "unknown", 2 : "empty", 3 : "present", 4 : "ready", 5 : "announceOnline", 6 : "online", 7 : "anounceOffline", 8 : "offline", 9 : "diagnostic", 10 : "standby"}

FRUOFFLINEREASON = {1: "unknown(1)",2:"none(2)",3:"error(3)",4:"noPower(4)",5:"configPowerOff(5)",6:"configHoldInReset(6)",7:"cliCommand(7)",8:"buttonPress(8)",9:"cliRestart(9)",10:"overtempShutdown(10)",\
                    11:"masterClockDown(11)", 12:"singleSfmModeChange(12)",13:"packetSchedulingModeChange(13)",14:"physicalRemoval(14)",15:"unresponsiveRestart(15)",16:"sonetClockAbsent(16)",17:"rddPowerOff",\
                    18:"majorErrors(18)",19:"minorErrors(19)",20:"lccHardRestart(20)",21:"lccVersionMismatch(21)",22:"powerCycle(22)",23:"reconnect(23)",24:"overvoltage(24)",25:"pfeVersionMismatch(25)",26:"febRddCfgChange(26)",\
                    27:"fpcMisconfig(27)",28:"fruReconnectFail(28)",29:"fruFwddReset(29)",30:"fruFebSwitch(30)",31:"fruFebOffline(31)",32:"fruInServSoftUpgradeError(32)",33:"fruChasdPowerRatingExceed(33)",\
                    34:"fruConfigOffline(34)",35:"fruServiceRestartRequest(35)",36:"spuResetRequest(36)",37:"spuFlowdDown(37)",38:"spuSpi4Down(38)",39:"spuWatchdogTimeout(39)", 40:"spuCoreDump(40)",\
                    41:"fpgaSpi4LinkDown(41)",42:"i3Spi4LinkDown(42)",43:"cppDisconnect(43)",44:"cpuNotBoot(44)",45:"spuCoreDumpComplete(45)", 46:"rstOnSpcSpuFailure(46)",47:"softRstOnSpcSpuFailure(47)",\
                    48:"hwAuthenticationFailure(48)",49:"reconnectFpcFail(49)", 50:"fpcAppFailed(50)", 51:"fpcKernelCrash(51)",52:"spuFlowdDownNoCore(52)",53:"spuFlowdCoreDumpIncomplete(53)", \
                    54:"spuFlowdCoreDumpComplete(54)", 55:"spuIdpdDownNoCore(55)",56:"spuIdpdCoreDumpIncomplete(56)",57:"spuIdpdCoreDumpComplete(57)",58:"spuCoreDumpIncomplete(58)",59:"spuIdpdDown(59)", \
                    60:"fruPfeReset(60)",61:"fruReconnectNotReady(61)",62:"fruSfLinkDown(62)"}

unit_list = zip(['bits/s', 'kb/s', 'Mb/s', 'Gb/s', 'Tb/s', 'Pb/s'], [0, 0, 1, 2, 2, 2])

class fruElement(object):
    def __init__(self, name, mytypecode, statecode, temp):
        self.__description = name.replace(' ', '_')
        self.__type = mytypecode
        self.__state = statecode
        self.__temp = temp
        self.__rCode = 0
        self.__rString = 'UNKNOWN'
	self.__cpuUsage = 0
	self.__memUsage = 0
	self.__offlineReason = 0
    def getTemperature(self):
        if self.__temp != '0':
            return self.__temp
        else:
            return None
    def getState(self):
        return FRUSTATE[int(self.__state)]
    def getStateCode(self):
        return self.__stateCode
    def getType(self):
        return FRUTYPE[int(self.__type)]
    def getTypeCode(self):
        return self.__type
    def getName(self):
        return self.__description
    def setReturnCode(self, k):
        self.__rString = k
        self.__rCode = RETURNCODE[k]
    def getReturnCode(self):
        return self.__rCode
    def getReturnString(self):
        return self.__rString
    def setCpuUsage(self, usage):
	self.__cpuUsage = usage
    def getCpuUsage(self):
	return self.__cpuUsage
    def setMemUse(self, mem):
	self.__memUsage = mem
    def getMemUse(self):
	return self.__memUsage
    def setOfflineReason(self, reason):
	self.__offlineReason = FRUOFFLINEREASON[int(reason)]
    def getOfflineReason(self):
	return self.__offlineReason

class myNet(object):
        def __init__(self, name, octetsIn, octetsOut, timeStamp):
                self.__description = name.replace(' ', '_')
                self.__ocIn = octetsIn
                self.__ocOut = octetsOut
                self.__timestamp = timeStamp
                
        def getName(self):
                return self.__description
        def getOctIn(self):
                return int(self.__ocIn)
        def getOctOut(self):
                return int(self.__ocOut)
        def getTimeStamp(self):
            return self.__timestamp

def SNMPGET(oid):
	VBoid = netsnmp.Varbind(oid)
        result = netsnmp.snmpget(oid, Version = 2 if options.version == "2c" else int(options.version), DestHost=options.host, Community=options.community, Timeout=800000, Retries=0)[0]
        if options.verbose:
                print "SNMPGET: %40s -> %s" %  (oid, result)
        return result

def getInterfacesOctets():
        args = {
                "Version": 2 if options.version == "2c" else int(options.version),
                "DestHost": options.host,
                "Community": options.community
                }
        n = 0
        netList = []
        result = netsnmp.snmpwalk(netsnmp.Varbind(OIDs["ifIndex"]),**args)
        if not len(result):
		back2nagios(RETURNCODE['UNKNOWN'], 'SNMP UNKNOWN: Timeout or no answer from %s.' % options.host)
                sys.exit(-1)
        for idx in result:
                descr, oper, cin, cout = netsnmp.snmpget(
                netsnmp.Varbind(OIDs["ifAlias"], idx),
                netsnmp.Varbind(OIDs["ifOperStatus"], idx),
                netsnmp.Varbind(OIDs["ifHCInOctets"], idx),
                netsnmp.Varbind(OIDs["ifHCOutOctets"], idx),
                **args)
                if descr == "lo":
                        continue
                if "None" in str(descr):
                        continue
                if oper == "3":
                        continue
                if options.verbose:
                        print("Description: {}  In-Octets: {}  Out-Octets: {}".format(descr,cin, cout))
                thisNet= myNet(descr, cin, cout, timeNow())
                netList.append(thisNet)
        return netList

def getFruStats():
        args = {
                "Version": 2 if options.version == "2c" else int(options.version),
                "DestHost": options.host,
                "Community": options.community,
                "Timeout": 800000
                }
        lastIndex = 0
        n = 1
	cpu = 0
	mem = 0
	offreason = 0
        result = netsnmp.snmpwalk(netsnmp.Varbind(OIDs["jnxFruContentsIndex"]),**args)
        if not len(result):
                back2nagios(RETURNCODE['UNKNOWN'], 'SNMP UNKNOWN: Timeout or no answer from %s' % options.host)
                sys.exit(-1)
        fruList = []
        for idx in result:   
                if lastIndex == idx:
                        n+=1       
                else:      
                        n=1
                        if str(idx) == str(9):
                                n=0             
                lastIndex = idx
                if str(idx) == str(9):
                        name, typ, state, temp, cpu, mem, offReason = netsnmp.snmpwalk(
                        netsnmp.Varbind(OIDs["jnxFruName"], idx+'.1.'+str(n)),
                        netsnmp.Varbind(OIDs["jnxFruType"], idx+'.1.'+str(n)),
                        netsnmp.Varbind(OIDs["jnxFruState"], idx+'.1.'+str(n)),
                        netsnmp.Varbind(OIDs["jnxFruTemp"], idx+'.1.'+str(n)),
			netsnmp.Varbind(OIDs["jnxOperatingCPU"], idx+'.1.'+str(n)),
                        netsnmp.Varbind(OIDs["jnxOperatingBuffer"], idx+'.1.'+str(n)),
			netsnmp.Varbind(OIDs["jnxFruOfflineReason"], idx+'.1.'+str(n)),
                        **args)                             
                else:                
                        name, typ, state, temp, offReason = netsnmp.snmpwalk(
                        netsnmp.Varbind(OIDs["jnxFruName"], idx+'.'+str(n)),
                        netsnmp.Varbind(OIDs["jnxFruType"], idx+'.'+str(n)),
                        netsnmp.Varbind(OIDs["jnxFruState"], idx+'.'+str(n)),
                        netsnmp.Varbind(OIDs["jnxFruTemp"], idx+'.'+str(n)),
			netsnmp.Varbind(OIDs["jnxFruOfflineReason"], idx+'.'+str(n)),
                        **args)
                thisFRU = fruElement(name,typ,state,temp)
		if cpu:
			if 'USB' not in name:
				thisFRU.setCpuUsage(cpu)
		if mem:
			if 'USB' not in name:
                                thisFRU.setMemUse(mem)
		if offReason:
			thisFRU.setOfflineReason(offReason)
                fruList.append(thisFRU)
                if options.verbose:
                        print("Name: {}  Type: {}  State: {} Temp: {}".format(name,typ,state,temp))
        return fruList

       
        
def back2nagios(retcode,retstr):
        print '%s : %s - %s' % (options.what, RETURNSTRINGS[retcode],retstr)
        sys.exit(retcode)

def timeNow():
        t = datetime.datetime.now()
        return int(t.strftime("%s"))

def savePerfData(dataIn):
	try:
	        with open('/tmp/juniper_lastdata.txt', 'w') as fp:
        	     json.dump(dataIn, fp)
	except Exception, Ex:
                print str(Ex)
                sys.exit(127)

def loadPerfData():
	try:
            with open('/tmp/juniper_lastdata.txt') as fp:
               dataOut = json.load(fp)
            return dataOut
	except Exception, Ex:
                print str(Ex)
                return None

def calcNetSpeed(oldTime, oldOctets, newTime, newOctets):
	if  oldOctets > newOctets:
        	newOctets += 18446744073709551615
   	netspeed = ((newOctets-float(oldOctets))*float(8))/(float(newTime)-oldTime)      #to get bps
    	return int(round(netspeed))    



def humanReadableSpeed(num):
    	"""Human friendly transfer Speed """
    	if num > 1:
        	exponent = min(int(log(num, 1024)), len(unit_list) - 1)
        	quotient = float(num) / 1024**exponent
        	unit, num_decimals = unit_list[exponent]
        	format_string = '{:.%sf} {}' % (num_decimals)
        	return format_string.format(quotient, unit)
    	if num == 0:
        	return '0 bps'
    	if num == 1:
        	return '1 bps'

def whatStateIsIt(value):
	if int(value) >= int(options.crit):
        	return 2
	elif int(value) >= int(options.warn):
		return 1
	else:
		return 0

############################### Setup #######

parser = optparse.OptionParser()
parser.add_option("-H", "",
                  dest="host",
                  help="Hostname/IP to check                    (- Required -)",
                  metavar="HOST")
parser.add_option("-v", "",
                  dest="version",
                  help="SNMP Version to use                     (Default : 2c)",
                  metavar="1/2c")
parser.add_option("-W", "",
                  dest="what",
                  help="What should be checked                  (Default : TEMP)",
                  metavar="NETWORKS / TEMP / SYSTEM / SPU")
parser.add_option("-C", "",
                  dest="community",
                  help="set non default community string        (Default : public)")
parser.add_option("-i", "",
                  dest="id",
                  help="Identifier (Port ID etc)                (- Optional -)")
parser.add_option("-L", "",
                  dest="label",
                  help="Label for Return Message                (- Optional -)")
parser.add_option("-V", "",
                  dest="verbose",
                  help="MORE ;)")
parser.add_option("-w", "",
                  dest="warn",
                  help="WARNING Thresold")
parser.add_option("-c", "",
                  dest="crit",
                  help="CRITICAL Thresold")

parser.set_defaults(version='1')
parser.set_defaults(community='public')
parser.set_defaults(what='temp')
parser.set_defaults(label='check_juniper.py :')

(options, args) = parser.parse_args()

OIDs ={
        'ifIndex':                      '.1.3.6.1.2.1.2.2.1.1',
        'ifAlias':                      '.1.3.6.1.2.1.31.1.1.1.18',
        'ifOperStatus':                 '.1.3.6.1.2.1.2.2.1.7',
        'ifHCInOctets':                 '.1.3.6.1.2.1.31.1.1.1.6',
        'ifHCOutOctets':                '.1.3.6.1.2.1.31.1.1.1.10',
        'jnxFruContentsIndex':          '.1.3.6.1.4.1.2636.3.1.15.1.1',
        'jnxFruName':                   '.1.3.6.1.4.1.2636.3.1.15.1.5',
        'jnxFruType':                   '.1.3.6.1.4.1.2636.3.1.15.1.6',
        'jnxFruState':                  '.1.3.6.1.4.1.2636.3.1.15.1.8',
        'jnxFruTemp':                   '.1.3.6.1.4.1.2636.3.1.15.1.9',
        'jnxFruOfflineReason':          '.1.3.6.1.4.1.2636.3.1.15.1.10',        
	'jnxOperatingCPU':		'.1.3.6.1.4.1.2636.3.1.13.1.8',
	'jnxOperatingBuffer':		'.1.3.6.1.4.1.2636.3.1.13.1.11',
	'jnxJsSPUMonitoringCPUUsage':	'.1.3.6.1.4.1.2636.3.39.1.12.1.1.1.4.0',
	'jnxJsSPUMonitoringMemoryUsage':'.1.3.6.1.4.1.2636.3.39.1.12.1.1.1.5.0'
    }

################################                PRECHECK                 ################################


if options.verbose:
        print "Checking if Host is set..."
if options.host == None:                                                                ### host defined ? 
        print "Hey! Please come back with a hostname or IP (-H) !"
        sys.exit(-1)
if options.verbose:
        print "...Done"

if options.verbose:
        print "checking host aviability"
command_line = "ping -c 1 " + options.host                                              ### host aviable ?
arguments = shlex.split(command_line)
try:
        subprocess.check_call(arguments,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        if options.verbose:
                print "host aviable"
except subprocess.CalledProcessError:
        print "No host aviable on address: %s, exiting..."%options.host
        sys.exit(-1)
if options.verbose:
        print "Checking SNMP-Version..."
if not options.version == "2c" and not options.version == "1":                          ### supported SNMP-Version ?
                print "Unknown or unsupported SNMP-Version : %s , exiting ..."% options.version
                sys.exit(-1)
if options.verbose:
        print "...Done"

###########################################################################################################
system 	= 	False
temp 	=	False
network	=	False
system	=	False
fru	= 	False
spu 	= 	False

perfData = {}

if options.verbose:
        print "Checking what to Monitor..."
if options.what.upper() == 'FRU':
        fru = True
elif options.what.upper() == 'TEMP':
        temp = True           
elif options.what.upper() == 'NETWORKS' or options.what.upper() == 'NETWORK' or options.what.upper() == 'NETWORKING' or options.what.upper() == 'NET':
        network = True
elif options.what.upper() == 'SYSTEM' or  options.what.upper() == 'SYS':
        system = True
elif options.what.upper() == 'SPU':
	spu = True
else:
        print "Unknown option :%s, try NETWORKS/SYSTEM/TEMP/FRU/SPU"%(options.what)
        sys.exit(-1)



#############################################################################################################
returnCode =0
returnMessage =''
returnPerfData = '|'


if fru or temp or system:
	if not fru:
		if not options.warn or not options.crit:
                    print "Please define Warn / Crit for Perfiormance Data, exiting ..."
                    sys.exit(-1)
               	if int(options.warn) > int(options.crit):
                    print "WARN-Threshold can not be greater than CRIT-threshold ..."
                    sys.exit(-1)
        snmpdata = getFruStats()
        problemFlag = False
        if not snmpdata:
                back2nagios(RETURNCODE['UNKNOWN'], 'SNMP UNKNOWN: Timeout or no answer from %s.' % options.host)
                sys.exit(-1)
        if fru:
                for idx in snmpdata:
                        if idx.getState() != "empty":
                                if options.verbose:
                                        print "%s type %s : state: %s "%(idx.getName(),idx.getType(),idx.getState())
                                if idx.getState() != "online":
                                        idx.setReturnCode('CRITICAL')
                                        if options.verbose:
                                               print "%s type %s : state: %s "%(idx.getName(),idx.getType(),idx.getState())
                                else:
                                        idx.setReturnCode('OK')
                        else:
                                idx.setReturnCode('OK')
                        if options.verbose:
                            print idx.getName(), idx.getState(), idx.getReturnCode(), idx.getReturnString()
                for idx in snmpdata:
                    if idx.getReturnCode():
                        returnMessage += idx.getName() + ' is '+ idx.getState()
			if idx.getState() == "offline":
				returnMessage += ' - Reason: ' + idx.getOfflineReason()
                        problemFlag = True
                        if idx.getReturnCode() > returnCode:
                            returnCode =idx.getReturnCode()
                if not problemFlag:
                    returnMessage = 'All fine'
                back2nagios(returnCode, returnMessage)

        elif temp:
                returnMessage = 'Temperatures: '
                for idx in snmpdata:
                    if idx.getTemperature():
                            if int(idx.getTemperature()) >= int(options.warn):
                                idx.setReturnCode('WARNING')
                                returnCode = 1
                            if int(idx.getTemperature()) >= int(options.crit):
                                idx.setReturnCode('CRITICAL')
                                returnCode = 2
                            returnMessage += idx.getName() + ' : ' + idx.getTemperature()+ 'C '
                            returnPerfData += ' '+ idx.getName() + '=' + idx.getTemperature()+';'+ options.warn+';'+options.crit
                back2nagios(returnCode, returnMessage + returnPerfData)
	elif system:
		returnMessage = 'System: '
		for idx in snmpdata:
			if idx.getCpuUsage():
				returnCode = whatStateIsIt(idx.getCpuUsage())
				idx.setReturnCode(RETURNSTRINGS[returnCode])
				returnMessage += 'CPU-Usage ' + idx.getName() + ' : ' + str(idx.getCpuUsage())+ '% '
				returnPerfData += ' '+ 'SYSTEM-CPU-Usage' + '=' + str(idx.getCpuUsage())+';'+ options.warn+';'+options.crit
			if idx.getMemUse():
				returnCode = whatStateIsIt(idx.getMemUse())
                                idx.setReturnCode(RETURNSTRINGS[returnCode])
                                returnMessage += 'Memory-Usage '+ idx.getName() + ' : ' + str(idx.getMemUse())+ '% '
                                returnPerfData += ' '+ 'SYSTEM-MEM-Usage' + '=' + str(idx.getMemUse())+';'+ options.warn+';'+options.crit
		back2nagios(returnCode, returnMessage + returnPerfData)
elif spu:
	returnMessage = 'SPU: '
	spuUsage = SNMPGET(OIDs['jnxJsSPUMonitoringCPUUsage'])
	if spuUsage:
		if not returnCode:
			returnCode = whatStateIsIt(spuUsage)
		returnMessage +='SPU-CPU-Usage: ' + str(spuUsage)+ '% '
		returnPerfData += ' SPU-CPU-Usage=' + str(spuUsage)+';'+ options.warn+';'+options.crit
	spuUsage = SNMPGET(OIDs['jnxJsSPUMonitoringMemoryUsage'])
        if spuUsage:
                if whatStateIsIt(spuUsage)> returnCode:
                        returnCode = whatStateIsIt(spuUsage)
                returnMessage +='SPU-MEM-Usage: ' + str(spuUsage)+ '% '
                returnPerfData += ' SPU-MEM-Usage=' + str(spuUsage)+';'+ options.warn+';'+options.crit
	back2nagios(returnCode, returnMessage+ returnPerfData)

elif network:
        snmpdata = getInterfacesOctets()
        returnMessage =''
        returnPerfData = '|'
        
        for idx in snmpdata:
            perfData[idx.getName()]= ((idx.getOctIn()),(idx.getOctOut()), (timeNow()))
        oldPerfdata = loadPerfData()
        savePerfData(perfData)
        if not oldPerfdata:
            print "no old Perfdata, cannot calculate average speed"
        else:
            if oldPerfdata.keys() == perfData.keys():
                for idx in snmpdata:
                    speedIn =  calcNetSpeed(oldPerfdata[idx.getName()][2],oldPerfdata[idx.getName()][0], perfData[idx.getName()][2], perfData[idx.getName()][0])
                    speedOut = calcNetSpeed(oldPerfdata[idx.getName()][2],oldPerfdata[idx.getName()][1], perfData[idx.getName()][2], perfData[idx.getName()][1])
                    if not speedIn or  not speedOut:
                        continue
                    returnMessage += idx.getName() + ' Average In: '+ str(humanReadableSpeed(speedIn)) + ' Out: '+str(humanReadableSpeed(speedOut))+ ', '
                    returnPerfData += ' '+ idx.getName()+'-IN' + '='+ str(speedIn)+';;'+ ' '+ idx.getName()+'-OUT' + '='+ str(speedOut)+';;'+ ' '
                back2nagios(0, returnMessage+returnPerfData)
            else:
                print "Networks since last check changed, or File Corrupt"
        
        