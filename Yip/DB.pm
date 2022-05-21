package Yip::DB;
use strict;

# Non-core dependencies
use Crypt::Random qw(makerandom);

# Database imports
#
# Get DBD::SQLite to install all you need
#
use DBI qw(:sql_types);
use DBD::SQLite::Constants ':dbd_sqlite_string_mode';

=head1 NAME

Yip::DB - Manage the connection to the Yip CMS SQLite database.

=head1 SYNOPSIS

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

=head1 DESCRIPTION

Module that opens and manages a connection to the Yip CMS database,
which is a SQLite database.

This module also supports a transaction system on the database
connection.  The supported transaction model assumes that everything
done by the client script will be wrapped in a single database
transaction that should either completely succeed or completely fail.

To get the CMS database handle, you use the C<beginWork> method and
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

Each call to C<beginWork> should have a matching C<finishWork> call
(except in the event of a fatal error).  If the internal nesting counter
indicates that this is not the outermost work block, then the internal
nesting counter is merely decremented.  If the internal nesting counter
indicates that this is the outermost work block, then C<finishWork> will
commit the transaction.  (If a fatal error occurs during commit, the
result is a rollback.)

Before a commit takes place on read-write transactions, the C<lastmod>
configuration variable will be updated in the C<cvars> table according
to the procedure given in "General rules" in the documentation for the
C<createdb.pl> script.  If you do not want this behavior, there is a
special C<w> mode you should use with the C<beginWork> call.

In the simplified style of operation shown in the synopsis, all you have
to do is start with C<beginWork> to get the database handle and call
C<finishWork> once you are done with the handle.  If any sort of fatal
error occurs, rollback will automatically happen.  Also, due to the
nesting support of work blocks, you can begin and end work blocks within
procedure and library calls.

If you want to catch fatal errors with an C<eval> block, you should
manually rollback the active transaction at the start of the catch
handler by calling C<cancelWork>, as shown in the synopsis.

=head2 Bootstrap configuration

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
  our @EXPORT_OK = qw(config_preprocessor);
  
  $config_dbpath = '/example/path/to/cms/db.sqlite';
  sub config_preprocessor { return; }
  
  1;

Replace the example path in the file contents shown above with the
absolute path on the server's file system to the SQLite database file.
The purpose of this module is to define a C<config_dbpath> Perl variable
that holds the path to the SQLite database.  You must name this module
C<YipConfig.pm> and place it in some directory that is in the Perl
module include path of the Yip scripts you will be running.

The C<config_preprocessor> shown in the above configuration module
module defines a preprocessor that does nothing.  See the following
subsection for more about the preprocessor.

The second component of the bootstrap configuration is this C<Yip::DB>
module.  This module creates an object that holds the DBI connection
handle to the SQLite database for the Yip CMS.  The destructor for this
object will disconnect from the database automatically.

In order to get the CMS database connection, then, all Yip scripts need
to do is import the C<Yip::DB> and C<YipConfig> modules, and then pass
the C<config_dbpath> variable defined by C<YipConfig> to C<Yip::DB> to
construct the connection object, as is shown in the synopsis for this
module.  Any additional configuration is then be read from the Yip CMS
database.

=head2 Preprocessor plug-in

The example configuration file given in the previous subsection defines
a preprocessor that does nothing.  It is also possible to plug in a
template preprocessor, which allows Yip rendering to be adapted.

The preprocessor subroutine takes two parameters.  The first parameter
is a string parameter that is either C<catalog> C<archive> or C<post>.
The second parameter is a hash reference.  The hash reference stores
all the template variables that are about to be used to render a
catalog, archive, or post page, in the format expected by the module
C<HTML::Template>.  The preprocessor may make any needed adjustments to
this hash reference.  Note that the adjustments made by the preprocessor
will not be checked for validity when the preprocessor returns.  This
means that preprocessors can do nearly anything, but it also means they
must be careful not to make the hash structure invalid.

One way to use this flexibly is to have post templates stored in the
post table render JSON.  The preprocessor then reads the rendered JSON
and uses that to define additional template variables.  The templates in
the template table can then use those custom-defined template variables,
allowing for much more potential structuring than is available in plain
Yip.

The module holding the actual preprocessor should also be in the include
path that is used for all CGI scripts.  Then, the configuration module
should call into it for the preprocessor routine.  Here is an example:

  package YipConfig;
  use parent qw(Exporter);
  use Example::Preprocessor;
  
  our @EXPORT = qw($config_dbpath);
  our @EXPORT_OK = qw(config_preprocessor);
  
  $config_dbpath = '/example/path/to/cms/db.sqlite';
  
  sub config_preprocessor { 
    ($#_ == 1) or die "Wrong number of parameters, stopped";
    my $tmpl = shift;
    my $vars = shift;
    Example::Preprocessor->go($tmpl, $vars);
  }
  
  1;

=head1 CONSTRUCTOR

=over 4

=item B<connect(db_path, new_db)>

Construct a new CMS database connection object.  C<db_path> is the path
in the local file system to the SQLite database file.  Normally, you get
this from the C<YipConfig> module, as explained earlier in "Bootstrap
configuration."

The C<new_db> parameter should normally be set to false (0).  In this
normal mode of operation, the constructor will check that the given path
exists as a regular file before connecting to it.  Otherwise, if you set
it to true (1), then the constructor will check that the given path does
I<not> currently exist before connecting to it.  Setting it to true
should only be done for the C<createdb.pl> script that creates a
brand-new Yip CMS database.

Note that there is a race condition with the file existence check, such
that the existence or non-existence of the database file may change
between the time that the check is made and the time that the connection
is opened.  However, the existence or non-existence of the database file
should never change while Yip is online, so this shouldn't be an issue.

The work block nesting count starts out at zero in the constructed
object.

=cut

sub connect {
  
  # Check parameter count
  ($#_ == 2) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameters
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $db_path = shift;
  my $new_db  = shift;
  
  ((not ref($db_path)) and (not ref($new_db))) or
    die "Wrong parameter types, stopped";
  
  $db_path = "$db_path";
  if ($new_db) {
    $new_db = 1;
  } else {
    $new_db = 0;
  }
  
  # Perform the appropriate existence check
  if ($new_db) {
    (not (-e $db_path)) or die "Database path already exists, stopped";
  } else {
    (-f $db_path) or die "Database path does not exist, stopped";
  }
  
  # Connect to the SQLite database; the database will be created if it
  # does not exist; also, turn autocommit mode off so we can use
  # transactions, turn RaiseError on so database problems cause fatal
  # errors, and turn off PrintError since it is redundant with
  # RaiseError
  my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path", "", "", {
                          AutoCommit => 0,
                          RaiseError => 1,
                          PrintError => 0
                        }) or die "Can't connect to database, stopped";
  
  # Turn on binary strings mode
  $dbh->{sqlite_string_mode} = DBD_SQLITE_STRING_MODE_BYTES;
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_dbh' property will store the database handle
  $self->{'_dbh'} = $dbh;
  
  # The '_nest' property will store the nest counter, which starts at
  # zero
  $self->{'_nest'} = 0;
  
  # The '_ro' property will be set to one if nest counter is greater
  # than zero and the transaction is read-only, or zero in all other
  # cases
  $self->{'_ro'} = 0;
  
  # The '_lm' property will be set to one if lastmod should be updated
  # at the end of the transaction
  $self->{'_lm'} = 0;
  
  # Return the new object
  return $self;
}

=back

=head1 DESTRUCTOR

The destructor for the connection object performs a rollback if the work
block nesting counter is greater than zero.  Then, it closes the
database handle.

=cut

sub DESTROY {
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # If nest property is non-zero, perform a rollback, ignoring any
  # errors
  if ($self->{'_nest'} > 0) {
    eval { $self->{'_dbh'}->rollback; };
  }
  
  # Disconnect from database
  eval { $self->{'_dbh'}->disconnect; };
}

=head1 INSTANCE METHODS

=over 4

=item B<beginWork(mode)>

Begin a work block and return a DBI database handle for working with the
database.

The C<mode> argument must be either the string value C<r> or the string
value C<rw> or the string value C<w>.  If it is C<r> then only read
operations are needed.  If it is C<rw> then both read and write
operations are needed, and the C<lastmod> variable should be updated
before the transaction commits.  If it is C<w> then both read and write
operations are needed, but the C<lastmod> variable does not need to be
updated before the transaction commits.

If the nesting counter of this object is in its initial state of zero,
then a new transaction will be declared on the database, with deferred
transactions used for read-only and immediate transactions used for both
read-write modes.  In all cases, the nesting counter will then be
incremented to one.

If the nesting counter of this object is already greater than zero when
this function is called, then the nesting counter will just be
incremented and the currently active database transaction will continue
to be used.  A fatal error occurs if C<beginWork> is called for one of
the read-write modes but there is an active transaction that is
read-only.

If you have a C<rw> transaction active, you are allowed to open a C<w>
transaction.  Also, if you have a C<w> transaction open, you are allowed
to open a C<rw> transaction.  At the end of the transaction, if at any
point there was a C<rw> transaction, C<lastmod> will be updated.

The returned DBI handle will be to the database that was opened by the
constructor.  This handle will always be to a SQLite database, though
nothing is guaranteed about the structure of this database by this
module.  The handle will be set up with C<RaiseError> enabled.  The
SQLite driver will be configured to use binary string encoding.
Undefined behavior occurs if you change fundamental configuration
settings of the returned handle, issue transaction control SQL commands,
call disconnect on the handle, or do anything else that would disrupt
the way this module is managing the database handle.

B<Important:> Since the string mode is set to binary, you must manually
encode Unicode strings to UTF-8 binary strings before using them in SQL,
and you must manually decode UTF-8 binary strings to Unicode after
receiving them from SQL.

Note that in order for changes to the database to actually take effect,
you have to match each C<beginWork> call with a later call to 
C<finishWork>.

=cut

sub beginWork {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get self and parameters
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $tmode = shift;
  (not ref($tmode)) or die "Invalid parameter type, stopped";
  (($tmode eq 'rw') or ($tmode eq 'r') or ($tmode eq 'w')) or
    die "Invalid parameter value, stopped";
  
  # Check whether a transaction is active
  if ($self->{'_nest'} > 0) {
    # Transaction active, so check for error condition that active
    # transaction is read-only but work block request is read-write
    if ($self->{'_ro'} and (($tmode eq 'rw') or ($tmode eq 'w'))) {
      die "Can't write when active transaction is read-only, stopped";
    }
    
    # Increment nesting count, with a limit of 1000000
    ($self->{'_nest'} < 1000000) or die "Nesting overflow, stopped";
    $self->{'_nest'}++;
    
    # If this is a rw transaction, make sure lm flag is set
    if ($tmode eq 'rw') {
      $self->{'_lm'} = 1;
    }
    
  } else {
    # No transaction active, so begin a transaction of the appropriate
    # type and set internal ro and lm flags
    if ($tmode eq 'rw') {
      $self->{'_dbh'}->do('BEGIN IMMEDIATE TRANSACTION');
      $self->{'_ro'} = 0;
      $self->{'_lm'} = 1;
      
    } elsif ($tmode eq 'w') {
      $self->{'_dbh'}->do('BEGIN IMMEDIATE TRANSACTION');
      $self->{'_ro'} = 0;
      $self->{'_lm'} = 0;
      
    } elsif ($tmode eq 'r') {
      $self->{'_dbh'}->do('BEGIN DEFERRED TRANSACTION');
      $self->{'_ro'} = 1;
      $self->{'_lm'} = 0;
      
    } else {
      die "Unexpected";
    }
    
    # Set nesting count to one
    $self->{'_nest'} = 1;
  }
  
  # Return the database handle
  return $self->{'_dbh'};
}

=item B<finishWork(mode)>

Finish a work block.

This function decrements the nesting counter of the object.  The nesting
counter must not already be zero or a fatal error will occur.

If this decrement causes the nesting counter to fall to zero, then the
active database transaction will be committed to the database.  If there
was any rw transaction at any time, lastmod will be updated before
commit.

Each call to C<beginWork> should have a matching call to C<finishWork>
and once you call C<finishWork> you should forget about the database
handle that was returned by the C<beginWork> call.

=cut

sub finishWork {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check that nesting counter is not zero and decrement it
  ($self->{'_nest'} > 0) or
    die "No active work block to finish, stopped";
  $self->{'_nest'}--;
  
  # If nesting counter is now zero, ro flag is clear, and lm flag is
  # set, perform the lastmod update
  if (($self->{'_nest'} <= 0) and (not ($self->{'_ro'}))
        and $self->{'_lm'}) {
    # Get the current value of lastmod
    my $lma = $self->{'_dbh'}->selectrow_arrayref(
                'SELECT cvarsval FROM cvars WHERE cvarskey=?',
                undef,
                'lastmod');
    (ref($lma) eq 'ARRAY') or die "lastmod undefined, stopped";
    $lma = "$lma->[0]";
    
    ($lma =~ /\A[0-9A-Fa-f]{1,8}\z/) or die "lastmod invalid, stopped";
    $lma = hex($lma);
    
    # If adding 64 would go beyond 32-bit unsigned range, then we have
    # a lastmod overflow
    ($lma <= 0xffffffff - 64) or die "lastmod overflow, stopped";
    
    # Increment at least one and at most 64
    $lma = $lma + 1 + makerandom(
                        Size => 6, Strength => 0, Uniform => 1);
    
    # Convert to base-16 string
    $lma = sprintf("%x", $lma);
    
    # Update the lastmod value
    $self->{'_dbh'}->do(
      'UPDATE cvars SET cvarsval=? WHERE cvarskey=?',
      undef,
      $lma, 'lastmod');
  }
  
  # If nesting counter is now zero, clear the ro and lm flags and commit
  # the active transaction
  unless ($self->{'_nest'} > 0) {
    $self->{'_ro'} = 0;
    $self->{'_lm'} = 0;
    $self->{'_dbh'}->commit;
  }
}

=item B<cancelWork()>

Cancel a work block.

If the nesting counter of this object is zero, then this function has
no effect.  Otherwise, it issues a rollback of the active transaction
(ignoring any errors) and resets the nesting counter to zero.

You should only need this if you are catching fatal errors with an
C<eval> block.  In that case, call this function in the catch block to
cancel any active transaction.  Otherwise, the destructor of the
connection object will automatically handle rolling back any active
transaction.

=cut

sub cancelWork {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # If nesting counter is not zero, roll back and reset object state
  if ($self->{'_nest'} > 0) {
    $self->{'_ro'} = 0;
    $self->{'_lm'} = 0;
    $self->{'_nest'} = 0;
    eval { $self->{'_dbh'}->rollback; };
  }
}

=back

=head1 AUTHOR

Noah Johnson, C<noah.johnson@loupmail.com>

=head1 COPYRIGHT AND LICENSE

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

=cut

# End with something that evaluates to true
#
1;
