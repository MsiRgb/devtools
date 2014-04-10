#!/usr/bin/env python

import libvirt
import libxml2
from libvirt import VIR_DOMAIN_RUNNING
import logging
from virtinst import util as virtutils
from jinja2 import Template
from subprocess import call

class LibvirtInterface():   
  def __init__(self, connStr="qemu:///system", vmCreateTmplFile="./templates/create_vm.xml"):
    self._connStr = connStr
    self._createVmXmlFile = "./templates/create_vm.xml"
    self._connection = self.makeConnection(self._connStr)
    self._nextSlot = 0x07
    self._vmCreateTmplFile = vmCreateTmplFile
    self._tmpLibVirtXmlFilePrefix = "/tmp/libvirt_xml_"
  
  def makeConnection(self, connStr):
    logging.info("Making libvirt connection to: %s" % (connStr))
    return libvirt.open(connStr) 
  
  def getVmListById(self):
    logging.info("Getting vm ID list")
    return self._connection.listDomainsID()
  
  def getVmIdByMacAddr(self, macAddr):
    logging.info("Getting vm id by MAC address %s" % macAddr)
    for vmId in self.getVmListById():
      ctx = libxml2.parseDoc(self._connection.lookupByID(vmId).XMLDesc(0)).xpathNewContext()
      devList = ctx.xpathEval("/domain/devices/interface[@type='network']/mac/@address")
      for dev in devList:
        if macAddr == dev.content:
          return vmId
    return None
  
  def getVmIdByIpAddr(self, ipAddr):
    logging.info("Getting vm id by ip addr: %s" % (ipAddr))
    for vmId in self.getVmListById():
      ctx = libxml2.parseDoc(self._connection.lookupByID(vmId).XMLDesc(0)).xpathNewContext()
      devList = ctx.xpathEval("/domain/devices/interface[@type='network']/ip/@address")
      for dev in devList:
        if ipAddr == dev.content:
          return vmId
    return None
  
  def getVmIdByName(self, name):
    logging.info("Getting vm id by name: %s" % (name))
    for vmId in self.getVmListById():
      ctx = libxml2.parseDoc(self._connection.lookupByID(vmId).XMLDesc(0)).xpathNewContext()
      nameList = ctx.xpathEval("/domain/name")
      for nameitem in nameList:
        if name == nameitem.content:
          return vmId
    return None
  
  def getVmNameById(self, idIn):
    logging.info("Getting vm name by id: %s" % idIn)
    for vmId in self.getVmListById():
      ctx = libxml2.parseDoc(self._connection.lookupByID(vmId).XMLDesc(0)).xpathNewContext()
      idList = ctx.xpathEval("/domain/name")
      if idIn == vmId:
        return idList[0].content
    return None
  
  def getRunningStatusByVmId(self, vmId):
    logging.info("Getting running status by vm id: %s" % vmId)
    state = self._connection.lookupByID(vmId).info()[0]
    return state # VIR_DOMAIN_RUNNING
  
  def getRunningStatusByVmName(self, vmName):
    logging.info("Getting running status by vm name: %s" % vmName)
    vmId = self.getVmIdByName(vmName)
    if not vmId:
      return None
    return self.getRunningStatusByVmId(vmId)
  
  def getNextSlot(self):
    self._nextSlot += 1
    return self._nextSlot
  
  def getVmNameList(self):
    logging.info("Getting vm name list")
    self.getVmListById()
    
  # name: unique name of VM
  # cpu: 
  # memory: memory size in MB
  # nics: list of nics
  #  [{'network':'br0'}]
  # 
  def createVm(self, name, cpu=1, memory=1048576, nics=[], hdd_format="qcow2", 
               hdd_size="10G", type="kvm", vmCreateTmplFile=None, cdromIso="/dev/null"):
    logging.info("Creating domain with name: %s, cpu: %s, mem: %s, nics: %s, hdd_format: %s, hdd_size: %s, cdrom_iso: %s, tmplFile: %s",
                 name, cpu, memory, nics, hdd_format, hdd_size, cdromIso, vmCreateTmplFile)
    if not vmCreateTmplFile: vmCreateTmplFile = self._vmCreateTmplFile
    params = {'name':name,
              'cpu':cpu,
              'memory':memory,
              'nics':[],
              'format':hdd_format,
              'type':type,
              'hdd_size':hdd_size,
              'cdrom_iso': cdromIso}
    # Add extra parms to nics list
    for i, nic in enumerate(nics):
      mac = virtutils.randomMAC("qemu")
      targetdev = "vnet%s" % i
      slot = '0x%02x' % self.getNextSlot()
      param = {'network': nic, 
               'mac': mac, 
               'slot': slot, 
               'targetdev': targetdev}
      params['nics'].append(param)
      
    # Load template file
    with open(vmCreateTmplFile) as f:
      tmpl = Template(f.read())
    
    libVirtTmpXmlFile = "%s_%s.xml" % (self._tmpLibVirtXmlFilePrefix, name)
    with open(libVirtTmpXmlFile, "w+") as f:
      f.write(tmpl.render(params))
    
    # Delete any existing domain defs
    try:
      domain = self._connection.lookupByName(name)
      if domain:
        try:
          if domain.info()[0] == VIR_DOMAIN_RUNNING:
            domain.destroy()
        except Exception:
          pass
        domain.undefine()
    except Exception:
      pass
    
    # Define machine
    domain = None
    with open(libVirtTmpXmlFile) as f:
      domain = self._connection.defineXML(f.read())
    
    # Create vhd
    call(['qemu-img', 'create', "/var/lib/libvirt/images/%s.%s" % (name, hdd_format), "-f", hdd_format, hdd_size])
    
    # Start machine
    if domain:
      domain.create()
      logging.info("Successfully created domain: %s" % name)
    else:
      logging.error("Unable to create domain: %s" % name)
      
    # Return information about machine (eg: mac addresses)
    return params
        
if __name__ == "__main__":
  import os
  logging.basicConfig(filename="libvirtInterface_test.log", level=logging.INFO)
  print "Testing %s" % os.path.basename(__file__)
  classInstance = LibvirtInterface()
  print "getVmIdByMacAddr(52:54:00:58:78:cd): %s" % classInstance.getVmIdByMacAddr("52:54:00:58:78:cd")
  print "getVmIdByIpAddr(192.168.199.1): %s" % classInstance.getVmIdByIpAddr("192.168.199.1")
  print "getVmIdByName(test1): %s" % classInstance.getVmIdByName("test1")
  print "getVmIdByName(test2): %s" % classInstance.getVmIdByName("test2")
  print "getVmNameById(2): %s" % classInstance.getVmNameById(2)
  print "getRunningStatusByVmName(test1): %s" % classInstance.getRunningStatusByVmName('test1')
  
  print "Creating vm..."
  rc = classInstance.createVm("libvirtifTest1", type="qemu", nics=['br0','br1','br2'])
  pass
  
