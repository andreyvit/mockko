Prerequisites
-------------

* GNU make
* Python >= 2.5
* ruby-haml
* less.js
* coffeescript [>= 0.9]
* nodejs [>= 0.2.2]
* GAE Python SDK (for 'make run' and 'make deploy')
* ruby-fssm (for 'make watch')
* JRE (for 'make optimize')
* openssl(1) (for 'make optimize')
* Perl (for 'make optimize')
* PIL or Pillow (for 'make upload-stock')


New Server
----------

Prerequisites:

* node.js (`brew install node`)
* npm package manager (`brew install npm`)
* MongoDB (`brew install mongodb`)
* Redis (`brew install redis`)
* express (`npm install express`)
* step (`npm install step`)
* fugue (`npm install fugue`)
* mongodb (`npm install mongodb`)
* supervisor (`npm install supervisor`)
* FSSM (`sudo gem install fssm`)
* grunt (`npm install grunt`)
* grunt-less (`npm install grunt-less`)
* grunt-coffee (`npm install grunt-coffee`)
* grunt-jade (`npm install grunt-jade`)

Note: seems that ideally most npm prerequisites should be bundled as submodules.

Run (development):

    rake watch &
    supervisor -w app.js -p app.js


Build
-----

Run 'make help' for help.

Bug Tracker
-----------

https://www.pivotaltracker.com/projects/74356

(Use the [12345] in commit message to close bug 12345)

Component JSON Formats
----------------------

A component is represented as a JavaScript/JSON object in one of three possible formats:

1. External format. Uses well-known field names like 'type', 'size', 'action' etc. All coordinates are relative to the parent. Most fields may be omitted.

2. Internal format. Uses post-minification field names like 'qQ' and 'Qq'. All coordinates are absolute (i.e. relative to the top-left corner of the mocked up screen). Most fields are expected to be present, especially things like style (to make comp.style.foo references safe).

3. External palette format. Is similar to the external format, but uses post-minification names.


