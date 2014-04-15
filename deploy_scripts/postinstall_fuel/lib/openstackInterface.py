#!/usr/bin/env python

import logging
from novaclient.v1_1 import client
from lib.flavorManagerWithKeys import FlavorManagerWithKeys

class OpenstackInterface:
  def __init__(self, user="admin", password="admin",
               tenant="admin", authUrl="http://10.20.0.4:5000/v2.0/"):
    self._novaClient = client.Client(user, password, tenant, 
                                     authUrl, service_type="compute")
    self._flavorMgrWithKeys = FlavorManagerWithKeys(self._novaClient)
  
  def createHostAggregate(self, aggregateName, availabilityZone):
    logging.info("Creating host aggreate: %s in availability zone: %s" \
                 % (aggregateName, availabilityZone))
    return self._novaClient.aggregates.create(aggregateName, availabilityZone)
  
  def deleteHostAggregate(self, aggregateObj):
    logging.info("Deleting host aggregate: %s" % aggregateObj)
    return self._novaClient.aggregates.delete(aggregateObj)
  
  def getAggregateByNameAndAvailabilityZone(self, aggregateName, availabilityZone):
    logging.info("Getting aggregate by name: %s and availability zone: %s" \
                 % (aggregateName, availabilityZone))
    for aggregate in self.listHostAggregates():
      if aggregate.name == aggregateName and \
         aggregate.availability_zone == availabilityZone:
        return aggregate
    return None
  
  def listHostAggregates(self):
    logging.info("Listing host aggregates")
    return self._novaClient.aggregates.list()
  
  def aggregateAddHost(self, aggregateObj, host):
    logging.info("Adding host: %s to aggregate name: %s" % (host, aggregateObj))
    return self._novaClient.aggregates.add_host(aggregateObj, host)
  
  def aggregateSetMetadata(self, aggregateObj, key, value):
    logging.info("Setting metadata: %s to aggregateName: %s" % ({key:value}, aggregateObj))
    return self._novaClient.aggregates.set_metadata(aggregateObj, {key:value})
  
  def flavorCreate(self, name, ramMB, hddGB, vcpus, flavorId=None):
    if not flavorId:
      import uuid
      flavorId = uuid.uuid1()
    logging.info("Creating flavor with name: %s, ramMB: %s, hddGB: %s, vcpus: %s, flavorId: %s" % (
                 name, ramMB, hddGB, vcpus, flavorId))
    return self._novaClient.flavors.create(name, ramMB, vcpus, hddGB, flavorid=flavorId)
  
  def flavorSetKey(self, flavor, key, value):
    logging.info("Setting metadata: %s on flavor: %s" % ({key:value}, flavor))
    return self._flavorMgrWithKeys.set_keys(flavor, {key:value})
  
  def getFlavorByName(self, flavorName):
    logging.info("Getting flavor by name: %s" % flavorName)
    for flavor in self._novaClient.flavors.list():
      if flavor.name == flavorName:
        return flavor
    return None
  
  def deleteFlavor(self, flavor):
    logging.info("Deleting flavor: %s" % flavor)
    return self._novaClient.flavors.delete(flavor)
    
if __name__ == "__main__":
  import os
  fileName = os.path.basename(__file__)
  logging.basicConfig(filename="%s.log" % fileName, level=logging.INFO)
  print "Testing %s" % fileName

  from lib.fuelInterface import FuelInterface
  fuelInterface = FuelInterface()
  firstEnv = fuelInterface.getEnvIdByName('AllInOne')
  controllerNode = fuelInterface.getControllerNodeIPAddress(firstEnv)
  
  authUrl = "http://%s:5000/v2.0/" % (controllerNode)
  openstackInterface = OpenstackInterface(authUrl=authUrl)
  
  # Delete existing test aggregate
  aggregate = openstackInterface.getAggregateByNameAndAvailabilityZone("testdriver", "nova")
  if aggregate:
    aggregate.delete()

  # Create host aggregate
  testAggregate = openstackInterface.createHostAggregate("testdriver", "nova")
  print "createHostAggregate(): %s" % testAggregate
  
  # Set metadata on new aggregate
  print "Setting metadata(): %s" % openstackInterface.aggregateSetMetadata(testAggregate, "ssd", "true")
  
  # Add host to new aggregate (NOTE: This cannot be tested unless there are active hosts)
  #print "Adding host to aggregate(): %s" % openstackInterface.aggregateAddHost(testAggregate, "testhost1")
  
  # Delete old flavor
  oldFlavor = openstackInterface.getFlavorByName("testflavor")
  print "oldFlavor: %s" % oldFlavor
  if oldFlavor:
    openstackInterface.deleteFlavor(oldFlavor)
  
  # Create a flavor for this new aggregate to associate with
  newFlavor = openstackInterface.flavorCreate("testflavor", 1024, 10, 1)
  print "Creating flavor: %s" % newFlavor

  # Set metadata key on flavor
  print "Setting metadata key on flavor: %s" % openstackInterface.flavorSetKey(newFlavor, "ssd", "true")