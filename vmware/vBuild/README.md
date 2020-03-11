# vBuild.ps1

### General
Creates a powershell gui with wpf and let's you clone windows virtual machines from windows templates with vCenter customization specs.<br>
Tested with: PowerShell 5.0, PowerCLI 10.1, vSphere 6.5

### Features
1. function Import-Inventory
- Create folder for "vBuild-Inventory" in the script directory if not exist, to store vCenter inventory 

(Files: \<vCenter-fqdn>_ClustersHosts.xml, \<vCenter-fqdn>_Customizations.xml, \<vCenter-fqdn>_Folders.xml, \<vCenter-fqdn>_Policies.xml, \<vCenter-fqdn>_TagCategories.xml, \<vCenter-fqdn>_Templates.xml)
- Check if inventory exist and import
- Collect vCenter inventory (Clusters and single Hosts, Customization Specs, Folders, Storage Policies, Tags and Categories, Templates and ovf's)

2. function Add-TagElement
- Builds dynamically the tab "Tags" with all found tag categories and tags

3. function Add-PostConfigElements
- Builds dynamically the tab "PostConfig" with elements in vBuild_config.xml "<PostConfig>"
- Check the examples added in vBuild_config.xml, should be self explanatory
- You can use 2 variable "VMNAME" and "HOSTNAME", these will be replaced the the vmname and hostname entered in the gui

4. function Add-SoftwareElements
- Builds dynamically the tab "Software" with elements in vBuild_config.xml "<Software>"
- Check the examples added in vBuild_config.xml, should be self explanatory
- You can use 2 variable "VMNAME" and "HOSTNAME", these will be replaced the the vmname and hostname entered in the gui

5. function Add-WpfEvents
- Actions & Events for buttons, textbox, checkbox
- if you set "IsChecked" in vBuild_config.xml to "True" then the checkbox in the gui will be checked

6. function Set-WpfControls
- Fills the gui with the data from "function Import-Inventory" and mail addresses from vBuild_config.xml 

7. function Get-ClusterData
- Check if cluster was selected or single host and collects data like: hosts, resourcepools, portgroups and datastores
- Updates the gui (comboboxes) with this information

8. function Add-NewVM
- Check if inputs are missing that are needed to build the vm
- Check if the target ip is reachable (abort if true) and if gateway is reachable (abort if false)
- Create the vm from template or content library item
- Customize vm hardware & set vm options
- Apply os customization spec and start vm
- Wait till sysprep is finished
- Moves the vm to the selected resourcepools
- Moves the vm to the selected folder
- Send mail with vm parameters

9. function Set-Tags
- If a tag is selected then assign it to the vm
- Set Custom Attribute

10. function Invoke-PostConfig
- Loop through each command that are definied in vBuild_config.xml and checked in the gui
- Validate commands (if validate is set to true)

11. function Install-Software
- Loop through each software that are definied in vBuild_config.xml and checked in the gui
- Loop through each software that are definied in vBuild_config.xml and checked in the gui and validate is set to true
- Copy setup file to vm, uses Invoke-VMScript to start installation, removes setup files after installation
- Validate software (if validate is set to true)

12. function Get-VMDisk
- Get all windows disk from a vm and map to vmware disk
- Type in vm name or dns hostname when they are not the same
- Select the drive letter that you would like to extend and type in the new disk size

13. function Set-VMDisk
- Extends the virtual disk from the vm and after that extend the disk in windows

14. function Stop-Gui
- Stops the powershell process where the script runs when you hit "x"

15. function Add-WpfElements
- Create automatic wpf/xaml code for groupbox, listbox, checkbox, textblock from config.xml

16. function Invoke-NSXConfig
- Creates nsx-v security groups and security tags if needed

### Requirements  
- Module slr.psm1 from my github site https://github.com/eschek87/scripts/blob/master/slr.psm1 (contains some used functions)
- Module PoshWPF from https://www.powershellgallery.com/packages/PoshWPF/
- Active Directory user account with privilege to add computers to a domain (defined in vmware customization spec)
- Active Directory user account with privilege to copy files via copy-item to the new virtual machine 
- Active Directory user account with privilege to install software in the new virtual machine
- Active Directory user account with privilege to create virtual machines in vmware
- Two dns server in vBuild_config.xml for customization spec if static ip is checked

### Configuration
1. The whole configuration is done in vBuild_config.xml and needs to be customized for your needs. There are some examples pre-filled. But the most important for the "Build" process are:
- Line 5/6: Your vCenter(s)  
- Line 9/10: Primary and secondary dns server ip's for vm customization spec (if static ip's are used)
- Line 13: Software that should be installed with invoke-vmscript (default: true -> is checked in gui; false -> is unchecked in gui)
- Line 34: Commands	that should run with Invoke-Expression
- Line 80: Commands	that should run with Invoke-VMScript
- Line 123: Mail data for notification after build	  
      
2. At the second step you need a customization spec in your vCenter with the following data:
- Name and Organization
- Product Key if you did not have a kms server
- Time zone
- Domain
- User and Password for domain join
- Generate new security ID

(The script clones later this customization spec and creates a temporary spec and delete it after the deployment)

### Use
1. Steps to create a new vm:
- Right click on the vBuild.ps1 and select "Run with powershell"
- Select your vCenter (is loaded from vBuild_config.xml)
- Hit "Enter" to start the collection and wait until it is finished 
- Select a cluster or single esxi host and wait until it is finished (the script collects the rest of the data like portgroups, hosts, resource pools and datastores)  
- Select at minimum host, datastore, portgroup, template and customization spec and enter data for new virtual machine (hostname, ip/network settings etc.)
- Hit "Build" button to create the vm and wait until it is finished 
- Hit "Set Tags" to attach the selected tags and creates the custom attributes to the vm and wait until it is finished
- Hit "Post Config" to fire up some commands and wait until it is finished 
- Hit "Install Software" to install the selected software from "Software" tab and wait until it is finished (which need to be configured before in vBuild_config.xml) 

2. Steps to extend a disk:
- Type in vm name or dns hostname when they are not the same
- Hit "Get VM Disk"
- Select drive letter to extend
- Enter new disk size
- Hit "Set VM Disk" to extend disk

<img src="https://github.com/eschek87/scripts/blob/master/vmware/vBuild/screenshots/vBuild_vCenter.jpg" height="50%" width="50%"/>
<img src="https://github.com/eschek87/scripts/blob/master/vmware/vBuild/screenshots/vBuild_general.jpg" height="50%" width="50%"/>
<img src="https://github.com/eschek87/scripts/blob/master/vmware/vBuild/screenshots/vBuild_tags.jpg" height="50%" width="50%"/>
<img src="https://github.com/eschek87/scripts/blob/master/vmware/vBuild/screenshots/vBuild_folder.jpg" height="50%" width="50%"/>
<img src="https://github.com/eschek87/scripts/blob/master/vmware/vBuild/screenshots/vBuild_options.jpg" height="50%" width="50%"/>
<img src="https://github.com/eschek87/scripts/blob/master/vmware/vBuild/screenshots/vBuild_post.jpg" height="50%" width="50%"/>
<img src="https://github.com/eschek87/scripts/blob/master/vmware/vBuild/screenshots/vBuild_software.jpg" height="50%" width="50%"/>
<img src="https://github.com/eschek87/scripts/blob/master/vmware/vBuild/screenshots/vBuild_vDisk.jpg" height="50%" width="50%"/>