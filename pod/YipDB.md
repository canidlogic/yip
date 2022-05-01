# NAME

Yip::DB - Manage the connection to the Yip CMS SQLite database.

# SYNOPSIS

    use Yip::DB;
    use YipConfig;
    
    my $dbconn = Yip::DB->connect($config_dbpath, 0);
    
    # Simple operation
    #
    my $dbh = $dbconn->beginWork('rw');
    ...
    $dbconn->finishWork;
    
    # Catching exceptions
    #
    eval {
      my $dbh = $dbconn->beginWork('rw');
      ...
      $dbconn->finishWork;
    };
    if ($@) {
      $dbconn->cancelWork;
      ...
    }

# DESCRIPTION

Module that opens and manages a connection to the Yip CMS database,
which is a SQLite database.

This module also supports a transaction system on the database
connection.  The supported transaction model assumes that everything
done by the client script will be wrapped in a single database
transaction that should either completely succeed or completely fail.

To get the CMS database handle, you use the `beginWork` method and
specify whether this is a read-only transaction or a read-write
transaction.  If no transaction is currently active, this will start the
appropriate kind of database transaction.  If a transaction is currently
active, this will just use the existing transaction but increment an
internal nesting counter.  It is a fatal error, however, to start a
read-write transaction when a read-only transaction is currently active,
though starting a read-only transaction while a read-write transaction
is active is acceptable.

The database handle is configured to generate fatal errors if there are
any kind of database errors (RaiseError behavior is enabled).
Furthermore, the destructor of this class is configured to perform a
rollback if a transaction is still active when the script exits
(including in the event of stopping due to a fatal error).

Each call to `beginWork` should have a matching `finishWork` call
(except in the event of a fatal error).  If the internal nesting counter
indicates that this is not the outermost work block, then the internal
nesting counter is merely decremented.  If the internal nesting counter
indicates that this is the outermost work block, then `finishWork` will
commit the transaction.  (If a fatal error occurs during commit, the
result is a rollback.)

In the simplified style of operation shown in the synopsis, all you have
to do is start with `beginWork` to get the database handle and call
`finishWork` once you are done with the handle.  If any sort of fatal
error occurs, rollback will automatically happen.  Also, due to the
nesting support of work blocks, you can begin and end work blocks within
procedure and library calls.

If you want to catch fatal errors with an `eval` block, you should
manually rollback the active transaction at the start of the catch
handler by calling `cancelWork`, as shown in the synopsis.

## Bootstrap configuration

Once you have a handle to the CMS database, you can read any additional
configuration information from data stored within the database.
However, there needs to be a "bootstrap" configuration method to open
this CMS database first before the rest of the configuration can be read
from the database.

There are two components to this bootstrap configuration.  The first
component is a configuration Perl module that should have the following
contents:

    package YipConfig;
    use parent qw(Exporter);
    
    our @EXPORT = qw($config_dbpath);
    
    $config_dbpath = '/example/path/to/cms/db.sqlite';
    
    1;

Replace the example path in the file contents shown above with the
absolute path on the server's file system to the SQLite database file.
The only purpose of this module is to define a `config_dbpath` Perl
variable that holds the path to the SQLite database.  You must name this
module `YipConfig.pm` and place it in some directory that is in the
Perl module include path of the Yip scripts you will be running.

The second component of the bootstrap configuration is this `Yip::DB`
module.  This module creates an object that holds the DBI connection
handle to the SQLite database for the Yip CMS.  The destructor for this
object will disconnect from the database automatically.

In order to get the CMS database connection, then, all Yip scripts need
to do is import the `Yip::DB` and `YipConfig` modules, and then pass
the `config_dbpath` variable defined by `YipConfig` to `Yip::DB` to
construct the connection object, as is shown in the synopsis for this
module.  Any additional configuration is then be read from the Yip CMS
database.

# CONSTRUCTOR

- **connect(db\_path, new\_db)**

    Construct a new CMS database connection object.  `db_path` is the path
    in the local file system to the SQLite database file.  Normally, you get
    this from the `YipConfig` module, as explained earlier in "Bootstrap
    configuration."

    The `new_db` parameter should normally be set to false (0).  In this
    normal mode of operation, the constructor will check that the given path
    exists as a regular file before connecting to it.  Otherwise, if you set
    it to true (1), then the constructor will check that the given path does
    _not_ currently exist before connecting to it.  Setting it to true
    should only be done for the `createdb.pl` script that creates a
    brand-new Yip CMS database.

    Note that there is a race condition with the file existence check, such
    that the existence or non-existence of the database file may change
    between the time that the check is made and the time that the connection
    is opened.  However, the existence or non-existence of the database file
    should never change while Yip is online, so this shouldn't be an issue.

    The work block nesting count starts out at zero in the constructed
    object.

# DESTRUCTOR

The destructor for the connection object performs a rollback if the work
block nesting counter is greater than zero.  Then, it closes the
database handle.

# INSTANCE METHODS

- **begin\_work(mode)**

    Begin a work block and return a DBI database handle for working with the
    database.

    The `mode` argument must be either the string value `r` or the string
    value `rw`.  If it is `r` then only read operations are needed.  If it
    is `rw` then both read and write operations are needed.

    If the nesting counter of this object is in its initial state of zero,
    then a new transaction will be declared on the database, with deferred
    transactions used for read-only and immediate transactions used for
    read-write.  In both cases, the nesting counter will then be incremented
    to one.

    If the nesting counter of this object is already greater than zero when
    this function is called, then the nesting counter will just be
    incremented and the currently active database transaction will continue
    to be used.  A fatal error occurs if `begin_work` is called in
    read-write mode but there is an active transaction that is read-only.

    The returned DBI handle will be to the database that was opened by the
    constructor.  This handle will always be to a SQLite database, though
    nothing is guaranteed about the structure of this database by this
    module.  The handle will be set up with `RaiseError` enabled.  The
    SQLite driver will be configured to use binary string encoding.
    Undefined behavior occurs if you change fundamental configuration
    settings of the returned handle, issue transaction control SQL commands,
    call disconnect on the handle, or do anything else that would disrupt
    the way this module is managing the database handle.

    **Important:** Since the string mode is set to binary, you must manually
    encode Unicode strings to UTF-8 binary strings before using them in SQL,
    and you must manually decode UTF-8 binary strings to Unicode after
    receiving them from SQL.

    Note that in order for changes to the database to actually take effect,
    you have to match each `begin_work` call with a later call to
    `finish_work`.

- **finish\_work(mode)**

    Finish a work block.

    This function decrements the nesting counter of the object.  The nesting
    counter must not already be zero or a fatal error will occur.

    If this decrement causes the nesting counter to fall to zero, then the
    active database transaction will be comitted to the database.

    Each call to `begin_work` should have a matching call to `finish_work`
    and once you call `finish_work` you should forget about the database
    handle that was returned by the `begin_work` call.

- **cancel\_work()**

    Cancel a work block.

    If the nesting counter of this object is zero, then this function has
    no effect.  Otherwise, it issues a rollback of the active transaction
    (ignoring any errors) and resets the nesting counter to zero.

    You should only need this if you are catching fatal errors with an
    `eval` block.  In that case, call this function in the catch block to
    cancel any active transaction.  Otherwise, the destructor of the
    connection object will automatically handle rolling back any active
    transaction.

# AUTHOR

Noah Johnson, `noah.johnson@loupmail.com`

# COPYRIGHT AND LICENSE

Copyright (C) 2022 Multimedia Data Technology Inc.

MIT License:

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
