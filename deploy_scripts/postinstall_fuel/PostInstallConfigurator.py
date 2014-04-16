#!/usr/bin/env python

from lib.fuelConfig import FuelConfig
import argparse
import logging
from lib.fuelInterface import FuelInterface
from lib.openstackInterface import OpenstackInterface
from lib.libvirtInterface import LibvirtInterface
from time import sleep
import os
from urlparse import urlparse

class PostInstallConfigurator():
  def __init__(self):
    self._args = None
    self.loadArgs()
    self._fuelConfig = FuelConfig(self._args["config"])
    self._fuelInterface = FuelInterface(self._fuelConfig.getFuelServerApiUrl())
    self._libvirtInterface = LibvirtInterface(vmCreateTmplFile="%s/lib/templates/create_vm.xml" % os.path.dirname(os.path.realpath(__file__)))
    logging.debug("PostInstallConfigurator starting...")
    # Place to store created VM parms
    self._vmParms = {}

  def loadArgs(self):
    parser = argparse.ArgumentParser(description='Post Install Configurator for Fuel')
    parser.add_argument('-c','--config', 
                        help='YAML config file', 
                        default="/var/tmp/postinstall/fuelConfigurator.yml")
    parser.add_argument('-l','--log-file', 
                        help='Log file', 
                        default="/var/log/postinstall.log")
    parser.add_argument('-d','--debug-level',
                        help='Log level (DEBUG,INFO,WARNING,ERROR,CRITICAL)', 
                        default=logging.INFO)
    parser.add_argument('-x','--delete-existing-envs',
                        help='Deletes existing environments to create new (DESTRUCTIVE)',
                        action='store_true',
                        default=False)
    parser.add_argument('-e','--deploy-environment',
                        help='Deploys the newly created environment',
                        action='store_true',
                        default=False)
    parser.add_argument('-a','--build-fuel-admin-server',
                        help='Build the Fuel admin server',
                        action='store_true',
                        default=False)
    self._args = vars(parser.parse_args())
    # Configure logging
    numeric_level = getattr(logging, self._args["debug_level"].upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError('Invalid log level: %s' % self._args["debug_level"])
    logging.basicConfig(level=self._args["debug_level"], 
                        filename=self._args["log_file"],
                        format="%(asctime)s %(process)s %(name)s %(levelname)s: %(message)s")
  
  def getCfgVmByHostName(self, cfgVmHostName):
    for vm in self._fuelConfig.getVmList():
      if vm['name'] == cfgVmHostName:
        return vm
  
  def getUnallocatedNodeIdByVmName(self, vmName):
    ''' Returns a fuel node id based on a libvirt created vm name
        or a cfg-file specified mac address '''
    cfgVm = self.getCfgVmByHostName(vmName)
    macList = []
    if cfgVm.get("mac", None):
      macList.append(cfgVm.get("mac"))      
    else:
      # Check libvirt
      vmParm = self._vmParms.get(vmName, None)
      if vmParm:
        for nic in vmParm['nics']:
          macList.append(nic['mac'])
    # Get a list of fuel nodes to search out this mac
    for fuelNode in self._fuelInterface.getUnallocatedNodes():
      if fuelNode['mac'] in macList:
        return fuelNode['id']
    return None

  def waitForHttpResponse(self, remoteEndpoint):
    # Pull out just prefix
    o = urlparse(remoteEndpoint)
    remoteEndpoint = "%s://%s" % (o.scheme, o.netloc)
    import requests
    done = False
    while not done:
      try:
        logging.info("Checking to see if %s responding to http..." % (remoteEndpoint))
        rc = requests.get(remoteEndpoint)
        if rc.status_code >= 200 and rc.status_code < 300: done = True
        sleep(60)
      except Exception:
        logging.warning("%s is not alive yet, sleeping 60 seconds..." % remoteEndpoint)
        sleep(60)

  def run(self):
    # Load the config file
    envList = self._fuelConfig.getEnvList()
    vmList = self._fuelConfig.getVmList()

    if self._args['build_fuel_admin_server']:
      logging.info("Building fuel server...")
      fuelAdminCfg = self._fuelConfig.getFuelAdmin()
      logging.info("fuelAdminCfg = %s" % fuelAdminCfg)
      self._libvirtInterface.createVm(fuelAdminCfg["name"],
                                      type=fuelAdminCfg["type"], 
                                      nics=fuelAdminCfg["nics"],
                                      hdd_size=fuelAdminCfg['hdd-size'],
                                      cpu=fuelAdminCfg['cpus'],
                                      memory=fuelAdminCfg['memory'],
                                      cdromIso=fuelAdminCfg['cdrom-iso'],
                                      vmCreateTmplFile=fuelAdminCfg['xml-template']) 
      logging.info("Waiting for fuel server to respond to HTTP...")
      self.waitForHttpResponse(self._fuelConfig.getFuelServerApiUrl())
      sleep(60)
      logging.info("Fuel server is alive!")
     
    # For each enviornment, add the env in Fuel
    for env in envList:
      if self._args['delete_existing_envs']:
        currEnvList = self._fuelInterface.listEnvs()
        for currEnv in currEnvList:
          if currEnv['name'] == env['name']:
            self._fuelInterface.deleteEnv(currEnv['id'])
            # There is some kind of deletion race 
            # condition in the Fuel server
            sleep(5)
      self._fuelInterface.createEnvironment(env['name'],
                                            env['release'], 
                                            env['mode'],
                                            env['net-provider'], 
                                            env['net-segment-type'])
     
    # For each VM, create the VM (note: this is only for AIO)
    # Note: If the VM is pre-configured as a node, add it to the env
    for vm in self._fuelConfig.getVmList():
      if not vm.get('mac', None):
        self._vmParms[vm['name']] = self._libvirtInterface.createVm(vm['name'], 
                                                                    type=vm['type'], 
                                                                    nics=vm['nics'],
                                                                    hdd_size=vm['hdd-size'],
                                                                    cpu=vm['cpus'],
                                                                    memory=vm['memory'])
      
    # Wait for all nodes to check in
    allNodesCheckedIn = False
    while not allNodesCheckedIn:
      sleep(5)
      checkedInNodes = 0
      for vm in vmList:
        if self.getUnallocatedNodeIdByVmName(vm['name']):
          checkedInNodes += 1
      logging.info("Waiting for nodes to check in (%s/%s)" % (checkedInNodes, len(vmList)))
      allNodesCheckedIn = checkedInNodes >= len(vmList)
    
    # For each VM, add primary MAC address as a new node to env
    for env in envList:
      for node in env['nodes']:
        nodeId = pic.getUnallocatedNodeIdByVmName(node['name'])
        roles = node['roles']
        envId = self._fuelInterface.getEnvIdByName(env['name'])
        self._fuelInterface.addNodeToEnvWithRole(nodeId, roles, envId)
        
    # Deploy environment if we are configured to
    if self._args['deploy_environment']:
      self._fuelInterface.deployEnv(
        self._fuelInterface.getEnvIdByName(env['name']))
         
    # Wait until environment finishes deploying
    done = False
    while not done:
      try:
        done = self._fuelInterface.envDoneDeploying(
               self._fuelInterface.getEnvIdByName(env['name']))
      except:
        done = False
      logging.info("Waiting 60s for environment to finish deploying...")
      sleep(60)
     
    # Load any host aggregates configured in the YAML file
    if len(self._fuelConfig.getHostAggregates()) > 0:
      controllerNode = self._fuelInterface.getControllerNodeIPAddress(
                        self._fuelInterface.getEnvIdByName(env['name']))      
      authUrl = "http://%s:5000/v2.0/" % (controllerNode)
      openstackInterface = OpenstackInterface(authUrl=authUrl)
      for hostAggregate in self._fuelConfig.getHostAggregates():
        aggObj = openstackInterface.createHostAggregate(hostAggregate['name'], 
                                                        hostAggregate['availability-zone'])
        openstackInterface.aggregateSetMetadata(aggObj, hostAggregate['meta-key'], 
                                                hostAggregate['meta-value'])
        flavorObj = openstackInterface.flavorCreate(hostAggregate['flavor']['name'], 
                                                    hostAggregate['flavor']['ram-mb'], 
                                                    hostAggregate['flavor']['disk-gb'], 
                                                    hostAggregate['flavor']['vcpus'])
        openstackInterface.flavorSetKey(flavorObj,
                                        hostAggregate['meta-key'], 
                                        hostAggregate['meta-value'])
        # Attempt to bind hosts
        for host in hostAggregate['hosts']:
          try:
            openstackInterface.aggregateAddHost(aggObj, host["hostname"])
          except:
            pass

if __name__ == "__main__":
  pic = PostInstallConfigurator()
  pic.run()
  
