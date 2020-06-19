#!/usr/bin/python
from datetime import datetime
dateTimeObj = datetime.now()

with open("/var/log/nems/argonone.log","a") as text_file:
  text_file.write("{0} Test was run.\r\n".format(dateTimeObj))
