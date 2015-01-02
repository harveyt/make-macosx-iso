make-macosx-iso
===============

Create Mac OS X ISO image from App Store installation app.

Supports
--------

* Mac OS X 10.9 "Mavericks"
* Mac OS X 10.10 "Yosemite"

NOTE: You *must* have already downloaded the OS installer in the App Store.

Installation
------------

```
$ make install
```

Example
-------

Show usage:

```
$ make-macosx-iso -?
```

Create a Mac OS X 10.9 "Mavericks" install image in the current directory called `Mavericks-Install.iso`:

```
$ make-macosx-iso -t Mavericks -o Mavericks-Install.iso
```

Thanks
------

Thanks to information from:

- http://forums.appleinsider.com/t/159955/howto-create-bootable-mavericks-iso
- http://sqar.blogspot.de/2014/10/installing-yosemite-in-virtualbox.html
- http://www.insanelymac.com/forum/topic/301988-how-to-create-a-bootable-yosemite-install-updated

License
=======

Copyright (c) 2015 Harvey John Thompson.

See [LICENSE](LICENSE) file for license rights and limitations (MIT).
