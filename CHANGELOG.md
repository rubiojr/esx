# 0.4.1 - 2012/03/26

* Minor fixes

# 0.4 - 2012/03/25 

* Do not include test data inside the gem.

* Define a Logger object

```
    ESX::Log.info "foobar"
```

* Added some debugging with Log.debug
* ESX::Host now has a *templates_dir* attribute and supports uploading and cloning templates:

```
    host = ESX::Host.connect 'my-esx-host', 
                             'root', 
                             'password'

    host.import_template "/path/to/template.vmdk"
```

This will copy the "template.vmdk" file to the default templates_dir in ESX. Default templates dir is "/vmfs/volumes/datastore1/esx-gem/templates".

The template is automatically converted to VMDK thin format.
  
Using the template:

```
    host.copy_from_template "template.vmdk", "/vmfs/volumes/datastore1/foo.vmdk"

````

Sorter version:

```
    host.import_disk "/path/to/local/template.vmdk",      # local file 
                     "/vmfs/volumes/datastore1/foo.vmdk", # remote path in ESX
                     { :use_template => true }
```

If the template "template.vmdk" is found, use that. Otherwise import the disk, save it as a template and clone the template to "/vmfs/volumes/datastore1/foo.vmdk"

* Added the following methods to ESX::Host

    * ESX::Host.has_template? 
    * ESX::Host.list_templates 
    * ESX::Host.delete_template

* Better test coverage
