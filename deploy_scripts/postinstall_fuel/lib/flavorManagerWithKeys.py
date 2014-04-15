#!/usr/bin/env python

from novaclient.v1_1.flavors import FlavorManager

class FlavorManagerWithKeys(FlavorManager):
  ''' Created to add functionality that comes
      in a later version of python-novaclient.
      Adding key/value metadata is included
      with python-novaclient in Ubuntu 13+ '''
  
  def set_keys(self, flavor, metadata):
        """
        Set extra specs on a flavor.

        :param flavor: The :class:`Flavor` to set extra spec on
        :param metadata: A dict of key/value pairs to be set
        """
        body = {'extra_specs': metadata}
        return self._create("/flavors/%s/os-extra_specs" % flavor.id,
                            body,
                            "extra_specs",
                            return_raw=True)
