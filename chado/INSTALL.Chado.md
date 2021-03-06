# Chado Installation

If you experience problems, please email them to the [gmod-schema mailing list](gmod-schema@lists.sourceforge.net).

This release will work with the most recent release of the Generic
Genome Browser (GBrowse) version 1.68 or better. If you experience difficulties
with GBrowse and Chado, you might want to look at getting a svn
checkout of the gbrowse-stable branch.  The installation instructions
for GBrowse are included in that package.  Additionally, for working
with GBrowse, you will need the Bio::DB::Das::Chado modules that you
can get from CPAN.

## Prerequisites

- PostgreSQL
- BioPerl
- go-perl
- ant
- Perl modules

There is some setup required for various prerequisites which is documented
below:

### PostgreSQL Setup

Currently GMOD developers are using 8.1 or better (PostgreSQL 9 has not
been tested).

Items to do with Postgres to make it ready to go:

- Make it accept TCP/IP connections by adding this line to postgresql.conf
(must be done either as user root or postgres; database must be restarted in
order for this change to take affect):
    ```
    tcpip_socket = true
    ```
    (This option is not available and not needed in PostgreSQL 8.1 or better.)

- Create a database user with permission to drop and add databases; the
  database user name should be the same as your Unix user name to allow the
  software build to progress smoothly (must be done as user postgres;
  createuser is a commandline program that comes with the PostgreSQL package):

    ```
    $ sudo su - postgres
    $ createuser --createdb <your username>
    $ exit                     # to exit out of the postgres user's shell
    ```

- Tell postgres that it can use the plpgsql language (as user postgres;
  createlang is a commandline program that comes with the PostgreSQL package):

    ```
    $ sudo su - postgres
    $ createlang plpgsql template1
    $ exit                     # to exit out of the postgres user's shell
    ```

- Edit the pg_hba.conf (either as the user 'root' or 'postgres') to give the
  user created above permission to access the database.  Read the comments in
  pg_hba.conf regarding permissions.  An example pg_hba.conf looks like this
  (which is very loose permissions):

  ```
  # TYPE  DATABASE    USER        CIDR-ADDRESS          METHOD

  local   all         all                               trust
  # IPv4 local connections:
  host    all         all         127.0.0.1/32          trust
  # IPv6 local connections:
  host    all         all         ::1/128               trust
  ```

  NOTE: If you are setting up a production Chado instance, now is a
  good time to decide how you want to define users and do client
  authenication for your database.  Postgresql supports several methods
  for defining users, including using operating system users, LDAP,
  Kerberos and many others.  See the Postgesql manual for more:
  http://www.postgresql.org/docs/8.4/interactive/client-authentication.html
  http://www.postgresql.org/docs/8.4/interactive/user-manag.html

- For Pg 8.1+, if you want to allow remote connections, the listen_addresses
  option may need to be modified; it does allow a wildcard '*', which
  corresponds to all available IP interfaces (it does *not* specify the IP
  addresses that are allowed to connect).  Set this in postresql.conf file,
  which is in the same directory as pg_hba.conf.

For information on tuning postgres for performance, see

    http://gmod.org/wiki/PostgreSQL_Performance_Tips

and

    http://www.varlena.com/varlena/GeneralBits/Tidbits/perf.html

The two most critical parameters to tune are shared_buffers and
effective_cache size.  Adjusting these parameters may require
modification of memory settings in /etc/sysctl.conf, see the sysctl
manpage for details.  Also critical for continued performance of
postgres is the regular execution of the VACUUM FULL ANALYZE command.
This command clears out old, deleted data and analyzes the structure
of the database so that the execution planner can predict the
fastest way to execute a given query.

While the above link describes tuning in general, the examples given
for tuning kernel parameters are Linux specific.  For setting
shmmax on Mac OS X boxes, edit

Version | Path
--- | ---
OS X 10.2 | /System/Library/StartupItems/SystemTuning/SystemTuning
OS X 10.3 | /etc/rc
OS X 10.5 | /etc/sysctl.conf

to increase the values of shmmax and shmall, like this:

```console
sysctl -w kern.sysv.shmmax=52428800 # bytes: 50 megs
sysctl -w kern.sysv.shmmin=1
sysctl -w kern.sysv.shmmni=32
sysctl -w kern.sysv.shmseg=8
sysctl -w kern.sysv.shmall=25600 # 4k pages: 100 megs
```

(these are the values used on a Mac that has 1.2 G RAM) and reboot.

For a Linux box with 512M RAM, use these values in /etc/sysctl.conf:


```ini
kernel.shmall = 134217728
kernel.shmmax = 134217728
```

and make these changes to the postgresql.conf file:


```ini
tcpip_socket = true  # Replaced with listen_addresses in Postgres 8.0+
work_mem=2048        # This is "sort_mem" if using Postgres 7.x
max_connections = 32
```


### Bioperl Live Setup

bioperl-live or a version 1.6.1 or better.  See http://bioperl.org.


### go-perl

Can be obtained from CPAN using the cpan shell with the command


```
cpan install GO::Parser
```


### Ant

When installing from svn, ant is needed to move GMODTools files
from schema/GMODTools into schema/chado.  When installing from
a distribution, this is not necessary, as the files will have
already been moved as part of the build process.


### Perl Modules

The perl modules can be installed via the CPAN shell and by issuing
the command 'install Bundle::GMOD' which will install all of the
modules below except for SQL::Translator, which is optional.

Module               | Used In
----                 | ----
CGI                  | GBrowse
GD                   | GBrowse
DBI                  | GBrowse, Chado
DBD::Pg              | GBrowse, Chado
SQL::Translator      | Chado (only for a custom Chado schema)
Digest::MD5          | GBrowse
Text::Shellwords     | GBrowse
Graph                | Bio-Chaos
Data::Stag           | Chado
XML::Parser::PerlSAX | Chado
Module::Build        | Chado
Class::DBI           | GMODWeb, or with a custom Chado schema
Class::DBI::Pg       | GMODWeb, or with a custom Chado schema
Class::DBI::Pager    | GMODWeb, or with a custom Chado schema
DBIx::DBStag         | Chado
XML::Simple          | Chado
LWP                  | Chado
Template             | Chado
Bio::Chado::Schema   | Chado

## Installing the Chado Schema


### Environment Preparation

First, you must set some variables in your environment.
If you are using bash or a bash-like shell, this is done via a command
like this:


```console
$ export VARNAME=value
```

If you are using tcsh or another csh-like shell, it is done like this:

```console
$ setenv VARNAME value
```

To make life easier on yourself, you will probably also want to put those
commands in your .tcshrc or .bashrc file so that the envirnment variables
are always available when you log in.

Variable          | Usage
---               | ------
GMOD_ROOT         | The location of your Chado installation  (e.g., "/usr/local/gmod").  Will contain the source files that define  the schema, as well as configuration settings and temp space.
CHADO_DB_NAME     | The name of your Chado database
CHADO_DB_USERNAME | The username to connect to Chado
CHADO_DB_PASSWORD | The password for the database user [opt]
CHADO_DB_HOST     | The host on which the database runs (e.g. "localhost") [opt]
CHADO_DB_PORT     | The port on which the database is listening [opt]

As indicated, the host, port, and password are optional.


Note: a mechanism exists to pass these variables directly to the installer
during the "perl Makefile.PL" step.  By giving key=value pairs, it is possible
to avoid setting environmental variables.  The syntax is as:

```console
$ perl Makefile.PL GMOD_ROOT=/usr/local/gmod CHADO_DB_NAME=dev_chado_01
```

Backward compatibility may not be maintained for this method of configuring
the install process will work.


### Makefile

From the chado directory (the same directory INSTALL.Chado is in) run the
following command:

```console
$ perl Makefile.PL
```

You will be prompted for several configuration values
used by Chado and its associated tools:

```
*   Use the simple install (uses default database schema) [Y]

Answering yes eliminates the need to have SQL::Translator installed.
This is recomended, and that is all that is necessary in order to use
the full schema and run GBrowse and GMODWeb on top of it.

*   Use values in '/home/scott/gmod/build.conf'? [Y]

If `perl Makefile.PL` has been run before, answering yes to this
will cause Makefile.PL to use the configuration options from the
previous build.

*   What database server will you be using? [PostgreSQL]

Specify what database vendor to use.  Currently only PostgreSQL works.

*   What is the Chado database name? [dev_chado_allenday_05]

This will be the name of the created chado database.

*   What is the database username? [allenday]

Default user that the installed libraries should try to
connect to the database as.

*   What is the password for 'allenday'?

Password for the default user.

*   What is the database host? [localhost]

Host of the database daemon.

*   What is your database port? [5432]

Port of the database daemon.

*   Where shall downloaded ontologies go? [./tmp]

The directory where ontology files and there lock files will be stored

*   What is the default organism (common name, or "none")?

The organism name should be one what will be in the organism table.
When the database is created, several organisms will be there
by default; these include: human, fruitfly, mouse, mosquito,
rat, Arabidopsis thaliana, worm, zebrafish, rice, and yeast.  (The
insert statements that create these default organisms are
contained in load/etc/initialize.sql).

*   Do you want to make this the default chado instance? [y]

You can have more than one Chado instance on a server, each with a
different name.  You can supply one of those names when loading
GFF, for example "--dbprofile fly_staging".  If you don't supply the
--dbprofile option, it will just use the default database parameters.


If you answered 'No' to the simple install question, AutoDBI.pm
will now be created by SQL::Translator, see the CUSTOM DATABASE
SCHEMAS section below for more information.

```

### Installation

```console
$ make # Make the schema
$ make install # Install the script and modules
$ sudo make install # For a global installation

```

Probably needs to be run as root.  Installs data loading scripts
in perl's path (typically /usr/local/bin or /usr/bin), perl modules,
as well as placing various files in $GMOD_ROOT, and creating the
infastructure for logging of errors by creating $GMOD_ROOT/logs and
creating the file /etc/log4perl.conf if it does not already exist.

```console
$ make load_schema # Install the schema to the database. Creates DB, wipes out any database with that name!!
$ make prepdb # Insert baseline data

```

Inserts a few useful items into fundamental Chado tables. It
uses load/etc/initialize.sql.  It contains information for several
common organisms and source databases (e.g. Genbank). This file
can be edited to add any organism or source database, using the
INSERT statements for the examples as a template.  Note also that
the prepdb target needs to be executed before the ontologies target,
but it can be executed again later, if more insert statements are
added (for instance to add a new organism or database).


```console
$ make ontologies # Load ontologies
```


Gets and installs various ontologies.  Requires a network
connection.  Absolutely required are the Relationship Ontology and
the Sequence Ontology (SO).  All others are optional, though the Feature
Property controlled vocabulary will typically be useful for loading GFF
Files, and the Gene Ontology is generally useful for a wide variety of
gene feature annotations.  Note retrieved ontology files are stored in
the directory specified when 'perl Makefile.PL' was run (the default
is ./tmp).  In order to do a repeat installation, the directory
containing the downloaded ontology must be removed.  In addition
to 'rm -rf ./tmp', you can also issue the `make clean` command,
which will clear out all of the files and directories created
up until this point in the installation.   Also note that loading
a large ontology like the Gene Ontology will take several minutes
(perhaps as long as an hour).

Note that since `make ontologies` downloads ontology files from their
online repositories, this step is prone to failure due to network
problems.

If you already have the desired ontology files locally, you
can execute a command for each file to load it.  Note again that
the Relationship Ontology is required before all others, and the
the Sequence Ontology (SO) is absolutely required for proper
functioning of the database.  The commands to load an ontology are:

```console
$  go2fmt.pl -p obo_text -w xml /path/to/obofile | \
    go-apply-xslt oboxml_to_chadoxml - > obo_text.xml
```

This creates a chadoxml file of the obo file - then execute:

```
$ stag-storenode.pl \
  -d 'dbi:Pg:dbname=$CHADO_DB_NAME;host=$CHADO_DB_HOST;port=$CHADO_DB_PORT' \
  --user $CHADO_DB_USERNAME --password $CHADO_DB_PASSWORD obo_text.xml
```

If you have other ontology format files, the commands are similar;
consult the documentation for go2fmt.pl and go-apply-xslt for your
file format.

It is a good idea at this point to make a back up of the database,
particularly if you loaded a large ontology like GO.  To make a complete
dump of the database, issue this command:

```
$ pg_dump db_name  >  db_dump.sql
```

and to restore the database, issue this command:

```
$ psql db_name <  db_dump.sql
```


## Loading Data

With that, the installation of the schema is complete. Please see the HOWTOs
at http://gmod.org/ for information on loading the Chado schema with data.


## Custom Database Schemas

If you answered 'No' to the question about doing a simple install
during `perl Makefile.PL`, you must provide the files default_schema.sql
and default_nofuncs.sql.  The best way to create these files is using
bin/chado-build-schema.pl, a perl script with a graphical user interface
for interactively building a Chado schema.  If you are providing table
definitions of your own, you will also have to edit the file
chado-module-metadata.xml to define how your tables relate to other
tables in the Chado schema.  While there is no documentation of the DTD
of this file, it is relatively straight forward.  See INSTALL.Custom
for more information on how chado-build-schema.pl relates to the build
process.  Once your default_schema.sql and default_nofuncs.sql files
are in place in the modules directory you can run `perl Makefile.PL`.
