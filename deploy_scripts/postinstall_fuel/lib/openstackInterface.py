#!/usr/bin/env python

import logging
from lib.restHelper import RestHelper

class OpenstackInterface:
  def __init__(self):
    self._restHelper = RestHelper()
  
  def authenticate(self, remoteHost="10.20.0.3", remotePort=5000, 
                   user="admin", password="admin"):
    ''' Returns an openstack authentication token and the full response '''
    remoteEndpoint = "http://%s:%s/v2.0/tokens" % (remoteHost, remotePort)
    data = {"auth": {"tenantName": "admin", "passwordCredentials": {"username": "admin", "password": "admin"}}}
    response = self._restHelper.postRequest(remoteEndpoint, data)
    return (response['access']['token']['tenant']['id'], response)
  
if __name__ == "__main__":
  import os
  fileName = os.path.basename(__file__)
  logging.basicConfig(filename="%s.log" % fileName, level=logging.INFO)
  print "Testing %s" % fileName

  from lib.fuelInterface import FuelInterface
  fuelInterface = FuelInterface()
  firstEnv = fuelInterface.listEnvs()[0]
  controllerNode = fuelInterface.getControllerNodeIPAddress(firstEnv)
  
  openstackInterface = OpenstackInterface()
  
  print "Authenticating to get a token"
  (token, response) = openstackInterface.authenticate(remoteHost=controllerNode)
  print "token: %s" % token
  print "...done"
  