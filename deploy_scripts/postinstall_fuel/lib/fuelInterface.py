#!/usr/bin/env python

from subprocess import call
from lib.restHelper import RestHelper
import logging

class FuelInterface():
  def __init__(self, fuelBaseUrl="http://10.20.0.2:8000/api/v1"):
    self._restHelper = RestHelper()
    self._fuelBaseUrl = fuelBaseUrl
  
  # mode is either ha_compact or multinode
  # netMode is either nova_network or neutron
  # netSegType is either gre or vlan
  def createEnvironment(self, envName, rel, mode, netMode, netSegType):
    logging.info("Creating environment: %s with rel: %s, mode %s, netMode %s and netSegType %s",
                  envName, rel, mode, netMode, netSegType)
    createEnvData = {
                      "nodes": [],
                      "tasks": [],
                      "name": envName,
                      "release": rel,
                      "net_provider": netMode,
                      "net_segment_type": netSegType,
                      "mode": mode
                    }
    createEnv = self._restHelper.postRequest("%s/%s" % (self._fuelBaseUrl, 
                                                        "clusters/"), 
                                                        createEnvData)
    return createEnv
  
  def listEnvs(self):
    logging.info("Getting list of environments")
    return self._restHelper.getRequest("%s/%s" % (self._fuelBaseUrl, "clusters/"))
  
  def getEnvIdByName(self, envName):
    logging.info("Getting env id by name: %s" % envName)
    for env in self.listEnvs():
      if env['name'] == envName:
        return env['id']
    return None
  
  def deleteEnv(self, envId):
    logging.info("Deleting environment: %s", envId)
    deleteUrl = "%s/%s/%s/" % (self._fuelBaseUrl, "clusters", envId)
    self._restHelper.deleteRequest(deleteUrl)
    
  def getNodesByEnvId(self, envId):
    logging.info("Getting list of nodes for envId: %s" % envId)
    nodeList = self._restHelper.getRequest("%s/nodes" % (self._fuelBaseUrl))
    retVal = []
    for node in nodeList:
      if node['cluster'] == envId:
        retVal.append(node)
    return retVal    
    
  def getUnallocatedNodes(self):
    logging.info("Getting list of unallocated nodes")
    nodeList = self._restHelper.getRequest("%s/nodes" % (self._fuelBaseUrl))
    retVal = []
    for node in nodeList:
      if node['status'] == 'discover' and \
         node['online'] == True and \
         node['pending_roles'] == []:
        retVal.append(node)
    return retVal
  
#   name       | conflicts 
#   -----------|-----------
#   cinder     | -         
#   controller | compute   
#   compute    | controller
#   ceph-osd   | -         

  def addNodeToEnvWithRole(self, nodeId, roles, envId):
    logging.info("Adding node id: %s to envId: %s with roles: %s", nodeId, envId, roles)
    data = [{"id": nodeId, "roles": roles.split(",")}]
    retVal = self._restHelper.postRequest("%s/clusters/%s/assignment/" % (self._fuelBaseUrl, envId), data)
    return retVal
    
  def deployEnv(self, envId):
    logging.info("Deploying envId: %s" % envId)
    retVal = self._restHelper.putRequest("%s/clusters/%s/changes" % (self._fuelBaseUrl, envId), {})
    if retVal['status'] == 'error':
      logging.info("Error deploying environment %s: %s" % (envId, retVal['message']))
    return retVal
    
if __name__ == "__main__":
  import os
  logging.basicConfig(filename="libvirtInterface_test.log", level=logging.INFO)
  print "Testing %s" % os.path.basename(__file__)
  classInstance = FuelInterface()
  print "Listing envs..."
  print classInstance.listEnvs()
  print "...done"
  print "Creating new env..."
  newEnv = classInstance.createEnvironment("fuelInterface test env 1", 2, "multinode", "nova_network", "gre")
  print newEnv
  print "...done"
  
  nodeList = classInstance.getUnallocatedNodes()
  print "Unallocated nodes: %s" % nodeList
  if len(nodeList) > 0: 
    nodeId = nodeList[0].get("id", None)
    envId = newEnv['id']
    role = "compute"
    print "Adding node: %s to env: %s with role: %s" % (nodeId, envId, role)
    classInstance.addNodeToEnvWithRole(nodeId, role, envId)
    print "...done"

  print "Deploying env..."
  classInstance.deployEnv(newEnv['id'])
  print "...done"

  print "Deleting env..."
  classInstance.deleteEnv(newEnv['id'])
  print "...done"