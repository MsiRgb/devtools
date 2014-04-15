#!/usr/bin/env python

import yaml
import logging

class FuelConfig():
  def __init__(self, yamlConfigFile="/var/tmp/postinstall/fuelConfigurator.yml"):
    self._yamlConfigFile = yamlConfigFile
    self._currentConfig = None
  
  def loadYamlFile(self, yamlFile=None):
    logging.info("Loading yaml cfg file: %s" % (self._yamlConfigFile))
    if not yamlFile: yamlFile = self._yamlConfigFile
    with open(yamlFile) as f:
      self._currentConfig = yaml.load(f.read())
  
  def getEnvList(self):
    logging.info("Getting env list")
    if not self._currentConfig: self.loadYamlFile(self._yamlConfigFile)
    return self._currentConfig.get('environments', [])
  
  def getVmList(self):
    logging.info("Getting vm list")
    if not self._currentConfig: self.loadYamlFile(self._yamlConfigFile)
    return self._currentConfig.get('vms', [])

  def getFuelAdmin(self):
    logging.info("Getting fuel admin config")
    if not self._currentConfig: self.loadYamlFile(self._yamlConfigFile)
    return self._currentConfig.get('fuel-admin', None)
  
  def getFuelServerApiUrl(self):
    logging.info("Getting fuel server API url")
    if not self._currentConfig: self.loadYamlFile(self._yamlConfigFile)
    return self._currentConfig.get('fuel-server-api-url', None)
  
  def getHostAggregates(self):
    logging.info("Getting host aggregates from config file")
    if not self._currentConfig: self.loadYamlFile(self._yamlConfigFile)
    return self._currentConfig.get('host-aggregates', [])
  
if __name__ == "__main__":
  import os
  print "Testing %s" % os.path.basename(__file__)
  classInstance = FuelConfig(yamlConfigFile="../sampleConfig.yml")
  envList = classInstance.getEnvList()
  print "envList: %s" % envList
  print "fuelServerApiUrl: %s" % classInstance.getFuelServerApiUrl()
