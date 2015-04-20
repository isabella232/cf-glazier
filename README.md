# Glazier

### Summary

A collection of scripts used for building Windows images for Helion Open Stack. The output image can be configured based on a **glazier-profile**.
Documentation can be found [here](https://github.com/mihaibuzgau/cf-glazier/blob/master/doc/glazier.md).

### Arguments

Syntax: create-glazier <options>

```
Available options:
--windows-iso /path/to/windows_iso_kit		
	- specifies the location of the Windows iso image
    
--sql-server-iso /path/to/sqlserver_iso_kit	
	- specifies the location of the SQLServer iso image
    	
--virtio-iso /path/to/virtio_iso_kit		
	- specifies the path to the virtio iso image
    	
--profile PATH					            
	- path to a glazier profile directory.Can be used multiple times. At leaset one profile is mandatory.
    	
--vm-path PATH					            
	- (optional) path to a directory where VBox files will be saved. The default is ~/.glazier
    
--with-sql-server {none|2012|2014}		
	- if this is set, you also have to set --sql-server-iso
    	
--product-key KEY				
	- Windows product key
    
--dry-run					
	- run but don't make any changes
    
--verbosity verbosity_level			
	- verbosity level is an interger between 1-3, with 1 being the least verbose and 3 being the most verbose
    
--use-colors {yes|no}				
	- should the script display colors or not

--os-network-id
	- network id used for building the OpenStack image

--os-key-name
	- name of the key used for building the OpenStack image

--os-security-group
	- security group used for building the OpenStack image

--os-flavor
	- name flavor used for buildig the OpenStack image

--help						
	- shows this message

```

### Prerequisites

##### OSX
* [Virtual box 4.3.26](http://download.virtualbox.org/virtualbox/4.3.26/VirtualBox-4.3.26-98988-OSX.dmg)
* Windows 2012 R2 image
* [Windows VirtIO Image 0.1-81](http://alt.fedoraproject.org/pub/alt/virtio-win/stable/virtio-win-0.1-81.iso)

##### Ubuntu
* Virtual box x
* Windows 2012 R2 image
* [Windows VirtIO Image 0.1-81](http://alt.fedoraproject.org/pub/alt/virtio-win/stable/virtio-win-0.1-81.iso)

### Usage

To use the script you need to have the OpenStack environment variables set up:
  
  * OS_TENANT_NAME
  * OS_USERNAME
  * OS_PASSWORD 
  * OS_REGION_NAME 
  * OS_TENANT_ID
  * OS_REGION_NAME
  * OS_AUTH_URL

Clone the repository:

    git clone git@github.com:hpcloud/cf-glazier.git
    
Run dry-run to check your parameters:

```
cd cf-glazier
./create-glazier --windows-iso /PATH/TO/ISO --virtio-iso /PATH/TO/VIRTIOISO --product-key WINDOWS-PRODUCT-KEY --os-network-id OSNETID --os-key-name OSKETNAME --os-security-group OSSECGROUP --os-flavor OSFLAVOR --profile /PATH/TO/PROFILE --dry-run
```

Create the image.
```
./create-glazier --windows-iso /PATH/TO/ISO --virtio-iso /PATH/TO/VIRTIOISO --product-key WINDOWS-PRODUCT-KEY --os-network-id OSNETID --os-key-name OSKEYNAME --os-security-group OSSECGROUP --os-flavor OSFLAVOR --profile /PATH/TO/PROFILE
```


