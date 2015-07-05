# grestful
A simple RESTful API client written in GTK 3.

#### Building
grestful is written in D and GTK 3 using the GtkD wrapper. Installing all the dependencies manually is not necessary as dub will handle building a local version of them for you. All you need is a D compiler with a standard library (DMD, GDC or LDC) and the dub build tool. To build, issue to following command:

```
dub build --build=release
```

This will automatically fetch the correct dependencies, build them and finally build the application itself. You can optionally append e.g. `--compiler=gdc` if you have multiple compilers installed and wish to select one manually.

##### Installation
There is no installation script available (and dub doesn't handle this). Installation is as simple as moving the executable to a binary folder such as /usr/bin and installing the contents of the `design` folder to `/usr/share/grestful/design/`. There is also a `.desktop` file present that you can put in `/usr/share/applications` if desired.

##### What shortcuts are available?
The following shortcuts may or may not be immediately clear:

  * `Delete` removes nodes from the requests tree view.
  * `F2` starts a rename for nodes in the requests tree view.

##### Why create a client like this?
I needed something to test API requests for RESTful API's and had been using the Chromium extension Postman for this up until now. This extension however is not available for Firefox nor do any of the alternatives seem to support saving requests under a specific name to recall them later.

##### Will you add new features?
New features from this point on are unlikely, seeing as I consider the application to be feature complete. Depending on what I need for my own purposes, new features may or may not be added. (I intend to keep the application simple and rudimentary.)
