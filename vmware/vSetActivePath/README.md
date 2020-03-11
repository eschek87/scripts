# set_active_path_vplex_cross_connect.ps1
### General
Reason for this script:
We have some vmware metro cluster connected to emc vplex. We use pernixdata fvp to accelerate vm's with caching devices in our esxi hosts. <br>
So we cannot use emc powerpath as path selection policy and need to fallback to NMP or in our case to PRNX_PSP_FIXED. <br>
Best practices is to use only local vplex paths for I/O to reduce load on ISLs, to use the vplex cache optimal and to avoid higher latencies from the remote vplex.<br>
Every time a host reboots it automatically chooses a path from all available paths. Therefore I developed this script to check and set the paths on a schedule. <br>
The script loops through a definied list of esxi hosts from a cluster and changes the active path from distributed datastore in vmware metro cluster with emc vplex with two san fabrics.<br>
It uses the path selection policy PRNX_PSP_FIXED.<br><br>
Our vmware metro cluster design:
- All esx hosts have 4 paths to distributed datastores (2 to our DC A VPLEX and 2 to our DC B VPLEX)
- All esx hosts have 2 paths to non-distributed datastores at DC A (DC A esx hosts local to DC A VPLEX and DC B esx hosts via cross connect to DC A VPLEX)
- All esx hosts have 2 paths to non-distributed datastores at DC B(DC B esx hosts local to DC B VPLEX and DC A esx hosts via cross connect to DC B VPLEX)
- The script changes the paths for the distributed datastores:<br>
	- It ensures that the active paths (I/O) for DC A esx hosts point at DC A VPLEX.
    - It ensures that the active paths (I/O) for DC B esx Hosts point at DC B VPLEX.

### Requirements 
slr.psm1
	
### Configure
- Line 34: Your vCenter `$Vcs = "vcenter1"`
	  
- Line 45+46: Hostname from datacenter a and b `$DcAhosts="DcA-esx-*"`and `$DcBhosts="DcA-esx-*"`
	  
- Line 49: Cluster Names `$Clusters="Cluster1","Cluster2"`
	  
- Line 56-75: WWN from your vplex systems
	  
- Line 78: Path selection policiy `$psp="PRNX_PSP_FIXED"`