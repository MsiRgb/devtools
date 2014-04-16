#!/usr/bin/env python

import urllib
#import urllib2
import json
import requests
from exceptions import Exception
import logging

class RestHelper():
  def __init__(self):
    pass
  
  def toJson(self, obj):
    return json.loads(obj)

  def putRequest(self, url, data):
    encodedData = json.dumps(data)
    retVal = requests.put(url, data=encodedData)
    if retVal.status_code == 400:
      raise Exception("Error: Invalid data supplied! %s" % (data))
    elif retVal.status_code < 200 or retVal.status_code > 300:
      raise Exception("Unknown error creating environment: %s" % (data['name']))
    try:
      return self.toJson(retVal.content)
    except:
      return None      
  
  def postRequest(self, url, data):
    logging.info("Making post request to url: %s with data: %s" % (url,data))
    encodedData = json.dumps(data)
    retVal = requests.post(url, data=encodedData)
    if retVal.status_code == 400:
      logging.error("Received status_code 400 back!")
      raise Exception("Error: Invalid data supplied! %s" % (data))
    elif retVal.status_code == 409:
      logging.error("Received status_code 409 back!")
      raise Exception("Error: Environment %s already exists!" % (data['name']))
    elif retVal.status_code < 200 or retVal.status_code > 300:
      raise Exception("Unknown error creating environment: %s" % (data['name']))
    else:
      logging.info("Received status_code %s back" % (retVal.status_code))

    try:
      return self.toJson(retVal.content)
    except:
      return None          
  
  def deleteRequest(self, url, data={}):
    encodedData = json.dumps(data)
    retVal = requests.delete(url, data=encodedData)
    if retVal.status_code == 400:
      raise Exception("Error: Failed to execute cluster deletion process")
    elif retVal.status_code == 404:
      raise Exception("Error: Cluster not found in db")
    elif retVal.status_code < 200 or retVal.status_code > 300:
      raise Exception("Unknown error deleting environment: %s" % (data['name']))
    return self.toJson(retVal.content)

  
  def getRequest(self, url, data={}):
    rc = requests.get(url)
    try:
      return self.toJson(rc.content)
    except:
      return None
  
if __name__ == "__main__":
  import os
  print "Testing %s" % os.path.basename(__file__)
  classInstance = RestHelper()
  
  # Test connection to fuel server
  fuelUrl = "http://10.20.0.2:8000/api/v1"
  
  # Get list of environments
  # curl -i -H "Accept: application/json" -X GET http://10.20.0.2:8000/api/v1/clusters
  print "Looking for Fuel environments..."
  for env in classInstance.getRequest("%s/%s" % (fuelUrl, "clusters/")):
    print "Found environment: %s" % env 
  
  # Create a new environment
  print "Creating a new Fuel environment..."
  createEnvData = {
                    "nodes": [],
                    "tasks": [],
                    "name": "restHelper test env",
                    "release": 2
                  }
  createEnv = classInstance.postRequest("%s/%s" % (fuelUrl, "clusters/"), createEnvData)
  print "createEnv Response: %s" % (createEnv)
  
  # Delete the new environment
  print "Deleting newly created test env..."
  envToDeleteId = createEnv['id']
  deleteUrl = "%s/%s/%s/" % (fuelUrl, "clusters", envToDeleteId)
  print "Deleted environment: %s" % classInstance.deleteRequest(deleteUrl)
  
  
