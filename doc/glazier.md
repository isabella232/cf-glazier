Glazier
===

##Glossary

- `glazier vm` - the virtual machine that runs Windows, booted inside Virtual Box
- `builder.iso` - the iso image that contains all the resources required by the glazier vm to specialize a Windows image
- `temp image` - a glance image that is booted in order to setup windows and specialize the image
- `temp instance` - a nova instance of the `temp image`; it runs the windows setup in unattended mode
- `prepped image` - after `temp image` reaches a shutoff state, it's snapshot in glance is the `prepped image`
- `final image` - the `final image` is a glance snapshot of the `prepped image`, with any additional resources copied over

##Flow

![Glazier Flow](./glazier-flow.png)

##Glazier profiles

A profile contains all the necessary resource needed to specialize a windows installation. Glazier profiles are made available to the glazier vm through the builder iso.

Directory structure of a glazier profile:

```
.
├── features.csv
├── resources.csv
└── specialize
    ├── specialize.ps1
    └── tools.csv
```

- `features.csv` is a CSV file that contains the desired status of each available windows feature
> Example
```csv
Feature,Core,Standard,Desired
NetFx4ServerFeatures,Enabled,Enabled,Enabled
NetFx4,Enabled,Enabled,Enabled
NetFx4Extended-ASPNET45,Disabled,Disabled,Enabled
MicrosoftWindowsPowerShellRoot,Enabled,Enabled,Enabled
MicrosoftWindowsPowerShell,Enabled,Enabled,Enabled
ServerCore-FullServer,Removed,Enabled,Removed
IIS-LegacySnapIn,Removed,Disabled,Removed
IIS-ManagementScriptingTools,Disabled,Disabled,Removed
IIS-ManagementService,Disabled,Disabled,Removed
IIS-IIS6ManagementCompatibility,Disabled,Disabled,Removed
IIS-Metabase,Disabled,Disabled,Removed
IIS-WMICompatibility,Disabled,Disabled,Removed
IIS-LegacyScripts,Disabled,Disabled,Removed
IIS-FTPServer,Disabled,Disabled,Removed
```

- `resources.csv` is a CSV file that contains a list of resources that will be placed on the final image; each resource is saved to the to `%HOMEDRIVE%`; the directory path is created if it doesn't exist
> Example
```csv
\installers\product.zip,http://download.domain.com/product.zip
```

- `tools.csv` is a CSV file containing all required tools so that for your specialize script;
> Example
```csv
tool.zip,http://download.domain.com/tool.zip
```

- `specialize.ps1` is a PowerShell script that will run as one of the last steps on the `temp instance`
> Example
```powershell
# Open firewall port 80
New-NetFirewallRule -DisplayName 'Allow HTTP' -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow
```

##create-glazier

###arguments

- `--windows-iso` - required - path to Windows ISO; image file name is validated to be of the right version and localization (we only support EN-US)
- `--with-sql-server` - optional - can be `none`, `2012` or `2014`; by default, it's `none`
- `--sql-server-iso` - if `--with-sql-server` is specified, this argument is required; it needs to point to a SQL Server ISO that is the correct version
- `--virtio-iso` - required - path to a virtio iso file
- `--profile` - optional - path to a `glazier profile`; the directory needs to have the correct structure; this parameter can be specified multiple times; all the specified profiles will be part of the `builder.iso` and made available to `new-image` in the `glazier vm`

##new-image

##initialize-image

##push-resources
