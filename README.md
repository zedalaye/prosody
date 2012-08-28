Prosody Windows Service Loader
==============================

This is a simple Lua script loader that runs as a Windows Service. It is mainly 
designed to load, set-up and run [Prosody](http://prosody.im) in a background 
Windows Application Service.

Design
------

Prosody Loader is basically the port of the lua.c command line interpreter in Delphi
using the lua API Wrapper found in [Delphi on Rails](http://code.google.com/p/delphionrails).

The DoR framework also provides the basis of the Windows Service in Prosody Loader.

Dependencies
------------

 * Delphi 2010 and later because of Generics.Collections
 * Delphi on Rails
 * InnoSetup 5.4+ (optional)

How to build
------------

Open the prosody.dpr file, choose the "Release" configuration and run "Build". 
The Prosody.exe file is built into the {root}\bin directory.

Install
-------

To install prosody as a Windows Service, just open a command line console, go to the 
prosody\bin directory and type "Prosody.exe INSTALL". Start using the Windows Services 
Console (services.msc) or by typing "net start im.prosody.server".

Uninstall
---------

Open a command line console, go to the prosody\bin directory and type "Prosody UNINSTALL".

Debug
-----

The project file include a "Debug" configuration that setup a global {$DEFINE CONSOLEAPP}. 
Debug builds cannot be installed as Windows Services but can be run and debugged into the 
Delphi IDE. Beware that Windows Services runs as system user and may not see the same OS
settings than debug application that are run as a normal (or administrator) user.

Packing everything in a setup package
-------------------------------------

Open the prosody.iss file in InnoSetup and click Build.

This package will deploy Prosody and the Prosody Loader in {pf}\Prosody and the data
repository into {commonappdata}\Prosody (ie. C:\ProgramData\Prosody in Windows 7, 
C:\Documents and Settings\All Users\AppData\Prosody in Windows XP.) 
The config file (prosody.cfg.lua) will end here too. If the config file do not exists, 
the install package will create one based on what is in prosody.cfg.lua.template.
The string %LOG_PATH% will be replaced by {commonappdata}\Prosody\prosody.log. The log to
everything but the console is mandatory because Windows Services cannot interract with the
desktop and thus cannot write to a console.

Todo
----

* Provide some web pages to display the config file and the log
* Provide some web pages to interract with host/user configuration 
  using mod_admin_telnet unless admin tasks can be done using the lua API...

Credits
-------

Thanks to the Prosody guys who wrote Prosody (http://prosody.im) and thanks to Henri Gourvest 
(http://www.progdigy.com) who wrote so many useful Delphi things including Delphi on Rails.

Licensing
---------

This software is provided "AS IS" without guarantee of any kind. It shares the same license as Prosody.
See src/COPYING.
