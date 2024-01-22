# Installation and configuration guide for iDRAC-based BMS

- [Testing results](#testing-results)
- [Network requirements](#network-requirements)
- [Initial state of your server](#initial-state-of-your-server)
- [Security and locking](#security-and-locking)
- [VNC Server configuration](#vnc-server-configuration)
- [User management](#user-management)
- [Server configuration profiles](#server-configuration-profiles)
- [Default project assignments](#default-project-assignments)
  - [Project-management segment](#project-management-segment)
  - [Guacamole entries](#guacamole-entries)
- [Testing and verification](#testing-and-verification)
- [Automating the setup](#automating-the-setup)

The instructions presented in this guide are written specifically for the [Dell's PowerEdge](https://www.dell.com/en-us/dt/servers/index.htm#scroll=off) series of servers. In order to meet the necessary workflow requirements, the servers are expected to feature fully licensed [iDRAC](https://www.dell.com/en-us/dt/solutions/openmanage/idrac.htm#scroll=off) cards.

## Testing results

So far, we were able to successfully test and deploy the following models of servers:

- R520
- R720
- R530
- R430

The instructions, scripts and workflows delivered with this framework are also expected to work against other models and even newer generations of the servers. In case of a discrepancy of any kind, please report back to us so we can make the necessary updates and adjust the documentation accordingly.

## Network requirements

The frameworks's basic networking requirements are laid out in the top-level `README.md` file. Once these are met, the operator can proceed with the following specific points:  

- The iDRAC interface needs to be attached to your control plane. The initial IP setup can be configured with the help of iDRAC Setting Utility (F2 during POST) or by using the server's front-panel LCD. 

- One network port (typically the lowest-numbered one on the LOM) needs to be attached to the BMS connectivity plane. The corresponding switch interface should be configured as an access port in the VLAN which has been exclusively assigned to this server. 

- The use of remaining data-plane ports is optional and can vary from instance to instance.     

- Guacamole should present the MAC addresses and textual descriptions of all utilized ports. Detailed information and examples on how to achieve this will follow in a later section.

## Initial state of your server

The next two actions are practically mandatory on each server:

- The iDRAC interface should get its IP configuration.
- The default password for the iDRAC's `root` account needs to be changed.

Otherwise, we are assuming the firmware on your BMS node is up to date and that all other firmware settings are in their factory default state. The operator is free to make some custom changes, as long as they do not interfere with the workflow of the framework, and do not conflict with any of the configuration steps presented in this manual.

## Security and locking 

Next, we need to address some security and locking mechanisms which are specific to the [Dell's PowerEdge](https://www.dell.com/en-us/dt/servers/index.htm#scroll=off) series of servers. The goal is to prevent our end-users from accessing and modifying any critical firmware settings. By critical, we mean any settings which could potentially lead to a loss of control over the server. For instance, an unauthorized alteration of iDRAC's IP configuration could lead to server inaccessibility, in a way which impacts not only end-users but also operators and the overall framework. 

The locking actions should cover the following:

- **BIOS password locking.** iDRAC and its Lifecycle controller do not support BIOS password recovery. If a user locks the BIOS, the framework will have no way of reclaiming it. Since there are no fine-grain permissions on the different BIOS and device settings, the only way to prevent this from happening is by changing the jumper on the system board so that we completely disable the BIOS password feature. Please refer to the "Owner's Manual" for your specific model on how to achieve this. 

  `Note:` Typically, this is done by moving the `PWRD_EN` jumper from pins 4-6 to pins 2-4.
  
  Once the jumpers are properly set, the two password fields under `System BIOS Settings` → `System Security` will become inaccessible. 

- **IDRAC settings through BIOS.** The following command disables one of two possible ways to access iDRAC locally (the other being "Local RACADM" and is described in the next bullet):

  - **racadm set iDRAC.LocalSecurity.PrebootConfig 1**  
  [Key=iDRAC.Embedded.1#LocalSecurity.1]
  Object value modified successfully
 

  `Note:` Unlike their output, iDRAC commands in this manual are written in **bold** and prefixed with a bullet.

  To see the effects of this command press F2 (Enter System Setup) on the console during the early boot phase of the server. All iDRAC settings (radio buttons, text fields and similar) should be grayed-out, inidicating the read-only mode.

- **iDRAC settings through CLI.** "Local RACADM" is a software package which enables unauthenticated and unrestricted execution of RACADM (iDRAC CLI) commands from the managed server’s operating system. It is available from the Dell OpenManage Systems Management Tools and Documentation DVD or at [Dell's Support web site](http://www.dell.com/support). In order to prevent end-users from gaining unrestricted access to the iDRAC's CLI in this way, the following command is needed:

  - **racadm set iDRAC.LocalSecurity.LocalConfig 1**  
  [Key=iDRAC.Embedded.1#LocalSecurity.1]
  Object value modified successfully

- **OS to iDRAC Pass-through.** Although not strictly necessary, we also recommend that you disable this feature:

  - **racadm set iDRAC.OS-BMC.AdminState 0**  
  [Key=iDRAC.Embedded.1#OS-BMC.1]  
  Object value modified successfully  

## VNC Server configuration

The following CLI sequence will prepare the VNC server on your node:

- **racadm set iDRAC.VNCServer.Enable 1**  
  [Key=iDRAC.Embedded.1#VNCServer.1]  
  Object value modified successfully  

- **racadm set iDRAC.VNCServer.Password `*****`**  
  [Key=iDRAC.Embedded.1#VNCServer.1]  
  Object value modified successfully  

- **racadm set iDRAC.VNCServer.Timeout 300**  
  [Key=iDRAC.Embedded.1#VNCServer.1]  
  Object value modified successfully  

- **racadm set iDRAC.VNCServer.Port 5901**  
  [Key=iDRAC.Embedded.1#VNCServer.1]  
  Object value modified successfully  

- **racadm set iDRAC.VNCServer.SSLEncryptionBitLength 0**  
  [Key=iDRAC.Embedded.1#VNCServer.1]  
  Object value modified successfully  

The password marked as `*****` needs to be specified when creating the corresponding VNC connection in the Guacamole portal. 

## User management

In addition to the pre-existing `root` user, the operators are advised to create a separate iDRAC account which `Core` drivers can then use to manage the server. Unlike `root`, this account doesn't need any IPMI permissions and its iDRAC privileges can be lowered from the `Administartor` to the `Operator` level. The `Operator` level does not allow any user manipulation nor tampering with the iDRAC logs and thus significantly reduces the attack surface. In other words, a potential exploiter would not be able to compromise the `root` account, nor to cover his tracks by deleting any relevant log entries.  

`Note:` However, be aware that some drivers may still require the `Administrator` level. To check whether this applies, consult the documentation notes for the specific driver. Such drivers are usually not intended for ordinary end-users.

In addition to the operational accounts discussed above, you might decide to have a dedicated user for monitoring through systems such as Zabbix or Nagios. The following three notes suggest how to prepare this type of account:

- `IPMI over LAN` should be enabled and restrained to the `Operator`'s role, in both global and local user settings.
- Set the iDRAC privileges to `Read-Only`. 
- SNMPv3 is also supported and can be enabled if needed.

This monitoring account may also find use in some drivers due to its secure read-only nature.

The follwoing CLI sequence illustrates one possible way of configuring the desired accounts:

```
racadm set iDRAC.Users.3.Enable 1
racadm set iDRAC.Users.3.UserName bms-operator 
racadm set iDRAC.Users.3.Password *****
racadm set iDRAC.Users.3.Privilege 0x1f3
racadm set iDRAC.Users.3.IpmiLanPrivilege 15
racadm set iDRAC.Users.3.IpmiSerialPrivilege 15
racadm set iDRAC.Users.3.SolEnable 0
racadm set iDRAC.Users.3.SNMPv3Enable 0
racadm set iDRAC.Users.3.SNMPv3AuthenticationType 2
racadm set iDRAC.Users.3.SNMPv3PrivacyType 2

racadm set iDRAC.Users.4.Enable 1
racadm set iDRAC.Users.4.UserName bms-admin 
racadm set iDRAC.Users.4.Password *****
racadm set iDRAC.Users.4.Privilege 0x1ff
racadm set iDRAC.Users.4.IpmiLanPrivilege 15
racadm set iDRAC.Users.4.IpmiSerialPrivilege 15
racadm set iDRAC.Users.4.SolEnable 0
racadm set iDRAC.Users.4.SNMPv3Enable 0
racadm set iDRAC.Users.4.SNMPv3AuthenticationType 2
racadm set iDRAC.Users.4.SNMPv3PrivacyType 2

racadm set iDRAC.Users.5.Enable 1
racadm set iDRAC.Users.5.UserName bms-monitor
racadm set iDRAC.Users.5.Password *****
racadm set iDRAC.Users.5.Privilege 0x001
racadm set iDRAC.Users.5.IpmiLanPrivilege 3
racadm set iDRAC.Users.5.IpmiSerialPrivilege 15
racadm set iDRAC.Users.5.SolEnable 0
racadm set iDRAC.Users.5.SNMPv3Enable 0
racadm set iDRAC.Users.5.SNMPv3AuthenticationType 2
racadm set iDRAC.Users.5.SNMPv3PrivacyType 2

```

`Note:` Make sure to replace the `*****` placeholders with the actual passwords.

You can specify usernames other than `bms-operator`, `bms-admin`, and `bms-monitor` as long as you remian consistent in the rest of the configuration. The same applies for the slot (index) numbers.  The key difference between these three accounts is in the type and level of permissions they have. For more details refer to the [RACADM CLI Guide](https://dl.dell.com/topicspdf/idrac8-lifecycle-controller-v2818181_cli-guide_en-us.pdf). 

`Note:` The `bms-admin` is intended for the drivers which require full `Administrator` privileges. It's not strictly needed as `root` account is already available. However, it's probably safer and slighltly more cleaner to have these two separated. 

The last two commands in the sequence will globally enable and prevent any further configuration changes through the server's IPMI:

```
racadm set iDRAC.IPMILan.Enable 1
racadm set iDRAC.IPMILan.PrivLimit 3
```

## Server configuration profiles

The Lifecycle Controller (LCC) is an extension of iDRAC, enhancing it with the capability to export current BIOS, iDRAC, and other device settings to an XML file. Importing this XML file allows for the restoration of recorded settings, effectively undoing any changes made in the meantime.

This feature's most prevalent use-case arises when a project expires or its owner determines that one or more BMS instances are no longer required. As part of the cleanup process, the operator removes these servers from the project and initiates an XML import on each of them. This restoration, whether manual or triggered indirectly through the _factory-defaults_ `dashboard` driver, reverts the firmware settings, making the BMS node available for its next acquisition.
   
When it comes to the LCC imports and exports, the framework has the following rules and expectations:

- Each iDRAC-based BMS is expected to have its own XML configuration profile. 
- These XML profiles are stored on a dedicated CIFS path within the `samba` container.
- The CIFS path starts with the control plane address specified as `PRIVATE_IP` in the top-level `.env` file.
- All XML files need to be named as `idrac-XX:XX:XX:XX:XX:XX.xml`, where `XX:XX:XX:XX:XX:XX` corresponds to the uppercase version of iDRAC's MAC address.

All of the points above are best illustrated with the following iDRAC command, which initiates one such LCC export: 

- **racadm get -t xml -f `idrac-18-66-DA-AF-D5-5D.xml` -l `//10.20.30.40/idrac//xml` -u `idrac` -p `*****`**  
  RAC976: Export configuration XML file operation initiated.  
  Use the **"racadm jobqueue view -i JID_552080244178"** command to view the status  
  of the operation.  

The command takes some time to complete, and as the output above suggests, it is possible to follow its progress:

- **racadm jobqueue view -i JID_552080244178**  
  \---------------------------- JOB -------------------------  
  [Job ID=JID_552080244178]  
  Job Name=Export: System configuration XML file  
  Status=Running  
  Start Time=[Not Applicable]  
  Expiration Time=[Not Applicable]  
  Message=[SYS057: Exporting system configuration XML file.]  
  Percent Complete=[10]  
  \---------------------------------------------------------- 
- **racadm jobqueue view -i JID_552080244178**  
  \---------------------------- JOB -------------------------  
  [Job ID=JID_552080244178]  
  Job Name=Export: System configuration XML file  
  Status=Completed  
  Start Time=[Not Applicable]  
  Expiration Time=[Not Applicable]  
  Message=[SYS043: Successfully exported system configuration XML file.]  
  Percent Complete=[100]  
  \----------------------------------------------------------  

`Note:` The XML export may fail if the server's LCC is disabled, although this is not typically the case with the factory-default settings that we assume here. If needed, you can re-enable it by invoking the `racadm set LifecycleController.LCAttributes.LifecycleControllerState 1` command. 

Different server models, firmware versions and peripheral devices typically render different and mutually incompatible versions of the XML files. **In the event of a change, such as a firmware or a relevant hardware upgrade, the operator must replace the old XML profile with a newly generated one.**   

Once the export is complete, the operator should access the `samba` container and manually edit the XML. The first change needed is the deletion of the user section:

```xml
<Attribute Name="IPMILan.1#AlertEnable">Disabled</Attribute>
  <!-- Users used to be here -->
<Attribute Name="Update.1#FwUpdateTFTPEnable">Enabled</Attribute>
```
The purpose of this change is to prevent XML imports from overriding the current state of iDRAC accounts.

The next change ensures that your RAID setup is cleared on each import:

```xml
<Component FQDD="RAID.Integrated.1-1">
  <Attribute Name="RAIDresetConfig">True</Attribute>
</Component>
```

`Note:` This needs to be applied for every RAID controller present on the server.

To prevent end-users from tampering with the server while XML import is in progress, make sure to have the VNC server disabled:

```xml
<Attribute Name="VNCServer.1#Enable">Disabled</Attribute>
```

The XML import operation should be tested with the `idrac-ssh-factory-defaults.sh` script from within the `core` the conatiner. This script needs to be invoked at this point in order to re-adjust some other settings on the server itself (including the disablement of the Lifecycle controller). 

The following commands are examples of scripted XML editing using the `xmlstarlet` command:
```sh
# Note: XML editing with tools like "sed" and "awk" is hihgly unreliable!
# The LCC XML schema is described in: 
# https://downloads.dell.com/solutions/general-solution-resources/White%20Papers/LC%20XML%20Schema%20Guide_02_26_2015.pdf

IDRAC_XML='idrac-18-66-DA-AF-D5-5D.xml'

# Delete the relevant user elements 
xmlstarlet ed -L -d '//Component[@FQDD="iDRAC.Embedded.1"]/Attribute[starts-with(@Name,"Users.")]' ${IDRAC_XML}

# Delete the relevant user comments except the first one
xmlstarlet ed -L -d '//Component[@FQDD="iDRAC.Embedded.1"]/comment()[contains(.,"Users.")][position()>=2]' ${IDRAC_XML}

# Replace the text of the remaining comment with the placeholder
old_comment=`xmlstarlet sel  -t -c '//Component[@FQDD="iDRAC.Embedded.1"]/comment()[contains(.,"Users.")]' ${IDRAC_XML}`
set +H
perl -pi -e "s|\Q$old_comment\E|<!-- Users used to be here -->|" ${IDRAC_XML} 

# Clear and reset all RAID controllers
xmlstarlet ed -L -d '//Component[starts-with(@FQDD, "RAID.")]/Attribute[@Name="RAIDresetConfig"]/following-sibling::*' ${IDRAC_XML}
xmlstarlet ed -L -d '//Component[starts-with(@FQDD, "RAID.")]/Attribute[@Name="RAIDresetConfig"]/preceding-sibling::*' ${IDRAC_XML}
xmlstarlet ed -L -d '//Component[starts-with(@FQDD, "RAID.")]/comment()' ${IDRAC_XML}
xmlstarlet ed -L -u '//Component[starts-with(@FQDD, "RAID.")]/Attribute[@Name="RAIDresetConfig"]' -v 'True' ${IDRAC_XML}

# Disable VNC server
xmlstarlet ed -L -u '//Attribute[@Name="VNCServer.1#Enable"]' -v 'Disabled' ${IDRAC_XML}
``` 
`Note:` The LCC exports XMLs as [ISO-8859 text instead of default UTF-8](https://sourceforge.net/p/xmlstar/discussion/226076/thread/493856c2/) which may confuse `xmlstarlet` or any other `libxml2` tool. To avoid this issue, insert `<?xml version="1.0" encoding="ISO-8859-1"?>` line as the first line in the targeted XML.

## Default project assignments

Next, the BMS instance should become part of the default project. This is mainly needed for testing and verification purposes. The following two subsections cover both network and console aspects of this assignment.

### Project-management segment

In order for a BMS to become a part of the desired project-management segment, we need to place an additional network interface on the corresponding PAGW instance. This binding interface should be configured with the explicit VLAN tagging and, as explained earlier, the VLAN ID should be the one uniquely assigned to that particular BMS instance. 

`Note:` A BMS should never be attached to more than one PAGW. This error is most likely to occur when moving an instance from one project to another. 

### Guacamole entries  

The operator should log in to the Guacamole portal as `guacadmin` or any other user with adequate administrative privileges

From the User's menu in the top-right corner, select `Settings` → `Connections` and expand on the connection group that represents your default project. Click on the `New Group` and create an `Organizational` group that will act as a container for the newly configured BMS instance. The name of the connection group should be descriptive enough and also include the relevant MAC addresses and their descriptions.

For example, the name of the group could be `[paris-bms2, Mgmt 18:66:DA:AF:D2:3F, 10 Gbps A0:36:9F:F0:F4:96]` where `paris-bms2` is a symbolic name of the server, `Mgmt 18:66:DA:AF:D2:3F` inidicates the network port used for BMS connectivity to the project-management plane and `10 Gbps A0:36:9F:F0:F4:96` indicates some sort of data plane port. Different convention are also allowed.

Next, expand the connection group representing the server and create the following connections under it:

- `VGA output`
- `Dashboard`
- `Firmware reset`
- `Factory defaults`

The `VGA output` represents the proxy for the iDRAC's VNC server. The relevant connection settings are structured as follows:

- Edit connection
  - Name: **VGA output**
  - Location: **(already selected)**
  - Protocol: **VNC**
- Guacamole Proxy Parameters (guacd)
  - Hostname: **guacd** 
  - Port: **4822**
- Parameters
  - Network
    - Hostname: **(iDRAC IP address)**
    - Port: **5901**
  - Authentication
    - Password: **(the one specified with the VNC server settings)**  

The `Dashboard` is used to expose drivers to both operators and users:

- Edit connection
  - Name: **Dashboard**
  - Location: **(already selected)**
  - Protocol: **SSH** 
- Guacamole Proxy Parameters (guacd)
  - Hostname: **guacd** 
  - Port: **4822** 
- Parameters
  - Network
    - Hostname: **core**
    - Port: **22**
  - Authentication
    - Username: **(CORE_USER specified in the top-level `.env` file)**
    - Password: **(CORE_PASSWORD specified in the top-level `.env` file)**
  - Session / Environment
    - Execute command: **idrac-ssh.sh -h `10.20.30.88:22` -u `bms-operator` -p `*******`**  
      (replace the `placeholders` with the actual arguments that match your iDRAC's SSH credentials)

The `Firmware reset` and `Factory defaults` connections target the `idrac-ssh-firmware-reset.sh` and `idrac-ssh-factory-defaults.sh` scripts, respectively. They are configured in a similar manner as `Dashboard` with the difference that `Factory defaults` requires an account with full administrative permissions in iDRAC (e.g., `bms-admin`, as explained earlier). 

When needed, each of these connections can be moved to another project and exposed to a different set of users.

## Testing and verification 

Now that the server is part of the default project we can perform some basic testing and verification. The following is just one possible workflow; feel free to re-adjust the steps below according to the specific needs of your setup:

1. Login to Guacamole.
2. Expand the connection group containg your server.
3. Open `VGA output` and `Dashboard` in two separate browser tabs.
4. Start with `Dashboard` by checking the current ISO status and attaching a live operating system image of your choice.
5. Use power action submenu within `Dashboard` to power-cycle or reboot your server. 
6. Switch to `VGA output` tab and make sure to boot from the ISO you've attached.
7. The network port connected to the project-management plane can be identified based on its MAC address, as noted in the server's connection group.
8. Check whether the DHCP assignemnt on the port was successfull. The MAC-to-IP address assignemnt can also be verified through `ARP-Scan` feature.
9. Check the Internet connectivity. Ping some external hosts, such as 8.8.8.8 and `www.google.com`.
10. VPN to the project. Verify the connectivity to the server from your VPN client machine.
11. Disconnect from the VPN. Shut down the server and remove the live ISO image from the virtual optical drive.
12. Close the `Dashboard` tab and open a new one for the `Factory defaults` connection. Invoke the XML import from there.
13. Make sure that LCC is disabled at the end of this testing session.

`Note:` Simultaneous use of `Dashboard` and `Factory defaults` connections is not allowed due to script-level locking. 

## Automating the setup

The script `idrac-ssh-enrolment.sh` which automates the configuration steps described above is available from the `core` container. By default, it prompts for the set of required server parameters:

```
Introduction
                                
This script will perform the initial setup of your iDRAC-based BMS server. 

It assumes the server is semi-ready for the inclusion:

- Networking is fully set up, including the iDRAC's IP configuration.  
- Firmware has been upgraded to the desired version.
- Root password has been changed.
- The relevant firmware settings are in their factory-default state.

Please refer to the infrastructure/ documentation for more details. 
                
To abort the script, press any key in the following 20 seconds.

Enter OOB IP address: 10.20.30.77

Enter BMS root password: *******

Enter Guacamole name for this server, e.g. [paris-bms3, Mgmt: A0:12:36:11:22:FE]: [paris-bms1, Mgmt: 18:66:DA:AF:D2:3F, 10 Gbps: A0:36:9F:F0:F4:96]

Enter VNC server password: *******

Confirm VNC server password: *******

Enter VLAN id assigned to this server: 3183

```

`Note:` The default PAGW instance is expected to be ready prior to the script execution.

Interactive input can be skipped by the means of environment variables:

```sh
export INTERACTIVE_TIMEOUT=5
export iDRAC_OOB_IP='10.20.30.77'
export iDRAC_ROOT_PASSWORD='*******'
export iDRAC_FULL_NAME='[paris-bms1, Mgmt: 18:66:DA:AF:D2:3F, 10 Gbps: A0:36:9F:F0:F4:96]'
export iDRAC_VNC_PASSWORD='*******'
export BMS_IC_VLAN=2001

idrac-ssh-enrolment.sh
```

Although possible, scripting of unattended or bulk installations using environment variables should never be used in practice.

`Developer's note:` The enrolment needs to be performed sequentially (i.e., server by serevr) as some PAGW-host drivers (most notably `Proxmox VE`) do not support concurrent hot-plugging of virtual NICs. Also, many platforms have a hard-coded limit on the number virtual NICs a VM can have; in the case of `Proxmox VE`, this limit is 30, which leaves us with the maximum of 28 bare-metal servers per project (the first two virtual NICs on each PAGW instance are preallocated for the public and project-management connectivity). The restricted number of BMS nodes per-project can also come from the number of preconfigured ports on the PAGW's internal OVS instance. 

The script also accepts a few environment variables which do not have an intercative equivalent. In case of atypical server configuration, the default values listed below can be overridden:

```sh
export iDRAC_OPERATOR_NAME='bms-operator'
export iDRAC_OPERATOR_NAME='bms-admin'
export iDRAC_OPERATOR_NAME='bms-monitor'

export iDRAC_OPERATOR_INDEX=3
export iDRAC_ADMIN_INDEX=4
export iDRAC_MONITOR_INDEX=5

export iDRAC_OPERATOR_PASSWORD=`tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''`
export iDRAC_ADMIN_PASSWORD=`tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''`
export iDRAC_MONITOR_PASSWORD=`tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''`
```

