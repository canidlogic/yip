#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);
use MIME::Base64;

# Non-core dependencies
use Crypt::Random qw(makerandom makerandom_octet);
use Date::Calc qw(check_date Add_Delta_Days Date_to_Days);
use JSON::Tiny qw(decode_json);

# Yip imports
use Yip::DB;
use YipConfig;

=head1 NAME

resetdb.pl - Configure the cvars table of the Yip CMS database.

=head1 SYNOPSIS

  ./resetdb.pl init 2022-05-01T13:25:00 < vars.json
  ./resetdb.pl peek epoch
  ./resetdb.pl touch 409f
  ./resetdb.pl config < vars.json
  ./resetdb.pl logout
  ./resetdb.pl forgot

=head1 DESCRIPTION

Utility script for working with the C<cvars> table of the Yip CMS
database.  All other tables of the database can be completely configured
using the CGI administration scripts.  However, the C<cvars> table can
only be configured using this C<resetdb.pl> script, because it contains
variables needed for the CGI administration scripts and other variables
that can not be freely changed without risking breaking the database.

Uses Yip::DB and YipConfig, so you must configure those two correctly
before using this script.  See the documentation in C<Yip::DB> for
further information.

You must use this script with the C<init> verb after a new database has
been created with C<createdb.pl> in order to get it properly configured
so that the administration CGI scripts can work.

This script has multiple invocations, shown in the synopsis.  Running
the script without any parameters will show a summary help screen.

All invocations have a I<verb> as the first parameter, which identifies
which kind of action is being requested.  Some invocations take one
additional I<object> parameter that specifies an additional piece of
information needed to perform the action.  Finally, two invocations also
read a JSON file from standard input to retrieve additional parameters.

The following subsections document each of the verbs and how to use
them.

=head2 init verb

The C<init> verb can only be used when the C<cvars> table in the
database is completely empty of records, or else a fatal error occurs.
You should use this verb after a brand-new database has been set up with
C<createdb.pl>.

The invocation takes an additional object parameter which must have the
following format:

  yyyy-mm-ddThh:mm:ss

The lowercase letters in this pattern must all be replaced by the
appropriate decimal digits.  The hyphen, colon, and uppercase C<T>
characters must be present in the positions shown.  You must use
zero-padding to make sure each numeric field has exactly the length
shown in the pattern above.

This object parameter specifies a specific date and time that will be
used for the epoch within the Yip CMS database.  The given year must be
in range [1970, 4999].  The year-month-day combination specified must be
valid according to the Gregorian calendar.  The time is given in 24-hour
time where the hour is in range [0, 23].  No leap seconds are allowed.

The time specified by this parameter is in a "floating" timezone that is
equivalent to whatever the local timezone is.  Leap seconds are ignored
and daylight saving time shifts are left ambiguous, so that each day has
exactly 24 hours and each minute has exactly 60 seconds.

Once set with this C<init> verb, the epoch in the database can never be
changed.  Post times and archive times are stored as the number of
seconds away from this defined epoch, with negative values allowed.  The
epoch should be close to the expected times that will be used in posts.
The purpose of having a defined epoch like this is to work around the
"year 2038" problem.  The defined epoch is stored as a base-16 string,
so it doesn't have range limitations.  All post times are figured
relative to this defined epoch, so even if post times are stored in
signed 32-bit integers we shouldn't be limited by the year 2038 limit
that would apply if we were just using the Unix epoch.

In addition to the object parameter, you must also provide a JSON file
on standard input.  This JSON file should encode a JSON object as the
top-level entity.  The property names of this JSON object correspond to
the names of variables in the C<cvars> table, and the property values
must be scalars that store the value that should be assigned to the
property.  You must define I<exactly> the following properties, no more
no less:

=over 4

=item *
C<authsuffix>

=item *
C<authlimit>

=item *
C<authcost>

=item *
C<pathlogin>

=item *
C<pathlogout>

=item *
C<pathreset>

=item *
C<pathadmin>

=item *
C<pathlist>

=item *
C<pathdrop>

=item *
C<pathedit>

=item *
C<pathupload>

=item *
C<pathimport>

=item *
C<pathdownload>

=item *
C<pathexport>

=item *
C<pathgenuid>

=back

See the documentation of the C<cvars> table in the C<createdb.pl> script
for the specification of each of these configuration variables.

The C<init> verb will set the C<epoch> to the time that was given as an
object parameter, and then initialize the C<lastmod> to a randomly
generated value in range [1, 4096].  All of the configuration variables
read from the JSON file will be checked and then written into the table.
C<authsecret> will be initialized to a random secret key and C<authpswd>
will be initialized to C<?> indicating that we are ready for a password
reset.

After the database is initialized with this verb, you can move over to
the CGI administration scripts.  Begin by using the password reset
script to set the administrator password, and then you can log into the
administrator control panel using that password.

=head2 peek verb

The C<peek> verb gets the current value of a given variable in the
C<cvars> table.  It takes an object parameter that names the
configuration variable to query for.  For security, however,
C<authsecret> and C<authpswd> can not be queried by this verb.  All
other defined verbs may be queried.  The full list is therefore:

=over 4

=item *
C<epoch>

=item *
C<lastmod>

=item *
C<authsuffix>

=item *
C<authlimit>

=item *
C<authcost>

=item *
C<pathlogin>

=item *
C<pathlogout>

=item *
C<pathreset>

=item *
C<pathadmin>

=item *
C<pathlist>

=item *
C<pathdrop>

=item *
C<pathedit>

=item *
C<pathupload>

=item *
C<pathimport>

=item *
C<pathdownload>

=item *
C<pathexport>

=item *
C<pathgenuid>

=back

See the documentation of the C<cvars> table in the C<createdb.pl> script
for the meaning of each of these configuration variables.

=head2 touch verb

The C<touch> verb updates the C<lastmod>.  It takes an object parameter
that must be an unsigned sequence of one or eight base-16 digits.
First, if the C<lastmod> variable is less than the given integer value,
it is increased to the given integer value.  Second, the usual procedure
is applied to increase the C<lastmod>, as described in the "General
rules" section of the C<createdb.pl> script documentation.

If you pass a value of zero, then this verb has the effect of increasing
the C<lastmod> by the usual procedure.  It shouldn't be necessary to do
this, however, since the other editing scripts will automatically do
this on their own.

The more useful application is when restoring a database image.  You can
make a backup image of the Yip CMS database by using the C<.backup>
command of the C<sqlite3> command on the Yip CMS database.  You can also
use the C<.restore> command to restore from a backup image.  However,
you need to be careful with the C<lastmod> configuration variable when
restoring so that client caches don't get interfered with.

The best way to restore is to make a note of the C<lastmod> value of the
current database before you restore from an image.  Then, restore from
the backup image.  Finally, use this C<touch> verb and pass as its
object value the last C<lastmod> value from the previous database before
it was overwritten by the restore.

HTTP clients may use caching correctly with the restored image before
the C<touch> operation is performed, provided that no changes are made
to the restored image.  Once the C<touch> operation is performed,
subsequent updates will not generate ETag values that have already been
used and therefore will not interfere with client caching.

=head2 config verb

The C<config> verb changes the freely mutable configuration variables in
the C<cvars> table.  The new variable values are read from a JSON file
on standard input.  The format of this JSON file is the same as the JSON
file passed to the C<init> verb, except that all properties are
optional.  Properties that are not included are left at their current
values.

=head2 logout verb

The C<logout> verb changes the C<authsecret> configuration variable to
a different randomly chosen value.  This has the effect of immediately
invalidating any currently active authorization cookies.  In other
words, any current administrators are immediately logged out and will
need to log in again with their password.

=head2 forgot verb

The C<forgot> verb is used to reset the password and login (as would be
the case for a forgotten password).  This will simultaneously change
C<authsecret> to a different randomly chosen value and set C<authpswd>
to C<?>  This has the same effect as for the C<logout> verb, except that
no logins are permitted after everyone is logged out, and the password
will need to be reset before administrator login works again.

=cut

# If we got no parameters, just print a summary screen and exit
#
unless ($#ARGV >= 0) {
  print q{Syntax:

  resetdb.pl init [datetime] < [json]
  resetdb.pl peek [propname]
  resetdb.pl touch [lbound]
  resetdb.pl config < [json]
  resetdb.pl logout
  resetdb.pl forgot

See the script documentation for further information.
};
  exit;
}

# If we got here, we have at least one parameter, so get the verb and
# check it
#
my $verb = "$ARGV[0]";
(($verb eq 'init') or ($verb eq 'peek') or ($verb eq 'touch') or
  ($verb eq 'config') or ($verb eq 'logout') or ($verb eq 'forgot')) or
  die "Unrecognized verb '$verb', stopped";

# Make sure parameter count is correct for the particular verb
#
if (($verb eq 'init') or ($verb eq 'peek') or ($verb eq 'touch')) {
  ($#ARGV == 1) or die "Wrong number of parameters for verb, stopped";
} else {
  ($#ARGV == 0) or die "Wrong number of parameters for verb, stopped";
}

# Define a hash that maps all property names that can be queried for
# with the "peek" verb as elements that map to a value of one; also,
# property names that map to a value of zero are recognized but can't
# be queried for with "peek" for security reasons
#
my %peek_props = (
  'epoch'        => 1,
  'lastmod'      => 1,
  'authsuffix'   => 1,
  'authsecret'   => 0,
  'authlimit'    => 1,
  'authcost'     => 1,
  'authpswd'     => 0,
  'pathlogin'    => 1,
  'pathlogout'   => 1,
  'pathreset'    => 1,
  'pathadmin'    => 1,
  'pathlist'     => 1,
  'pathdrop'     => 1,
  'pathedit'     => 1,
  'pathupload'   => 1,
  'pathimport'   => 1,
  'pathdownload' => 1,
  'pathexport'   => 1,
  'pathgenuid'   => 1
);

# Define a hash that maps all property names that can be set in a JSON
# input file to a value of one; also, property names that are recognized
# but can't be set with JSON map to a value of zero
#
my %json_props = (
  'epoch'        => 0,
  'lastmod'      => 0,
  'authsuffix'   => 1,
  'authsecret'   => 0,
  'authlimit'    => 1,
  'authcost'     => 1,
  'authpswd'     => 0,
  'pathlogin'    => 1,
  'pathlogout'   => 1,
  'pathreset'    => 1,
  'pathadmin'    => 1,
  'pathlist'     => 1,
  'pathdrop'     => 1,
  'pathedit'     => 1,
  'pathupload'   => 1,
  'pathimport'   => 1,
  'pathdownload' => 1,
  'pathexport'   => 1,
  'pathgenuid'   => 1
);

# Get decoded and checked object parameter; for "init" this will be an
# integer storing the seconds since the Unix epoch; for "peek" this will
# be a valid property name; for "touch" this will be an integer storing
# the given value; for other verbs this is left undefined
#
my $obj_param;

if ($verb eq 'init') {
  # Parse the datetime into fields
  ($ARGV[1] =~ /\A
                    ([0-9]{4})
                  \-([0-9]{2})
                  \-([0-9]{2})
                  T ([0-9]{2})
                  : ([0-9]{2})
                  : ([0-9]{2})
                \z/x) or die "Invalid datetime, stopped";
  
  my $year   = int($1);
  my $month  = int($2);
  my $day    = int($3);
  my $hour   = int($4);
  my $minute = int($5);
  my $second = int($6);
  
  # Rough range-check
  (($year >= 1970) and ($year <= 4999)) or
    die 'Year must be in range [1970, 4999], stopped';
  (($month >= 1) and ($month <= 12)) or
    die "Month out of range, stopped";
  (($day >= 1) and ($day <= 31)) or
    die "Day out of range, stopped";
  (($hour >= 0) and ($hour <= 23)) or
    die "Hour out of range, stopped";
  (($minute >= 0) and ($minute <= 59)) or
    die "Minute out of range, stopped";
  (($second >= 0) and ($second <= 59)) or
    die "Second out of range, stopped";
  
  # Check that YMD combination is valid
  (check_date($year, $month, $day)) or
    die "Invalid date, stopped";
  
  # Convert YMD into number of days since 1970-01-01
  my $doff = Date_to_Days($year, $month, $day) - Date_to_Days(1970,1,1);
  
  # Compute the number of seconds from Unix epoch to given date; since
  # Perl can normally use double-precision for huge integers, there
  # shouldn't be a year-2038 problem here
  $obj_param = ($doff * 86400)
                + ($hour * 3600) + ($minute * 60) + $second;
  
} elsif ($verb eq 'peek') {
  # Get the property name
  $obj_param = "$ARGV[1]";
  
  # Basic format check
  ($obj_param =~ /\A[A-Za-z0-9_]+\z/) or
    die "Invalid property name '$obj_param', stopped";
  
  # Check that name is recognized
  (exists $peek_props{$obj_param}) or
    die "Property name not recognized, stopped";
  
  # Check that name is allowed
  ($peek_props{$obj_param}) or
    die "Property '$obj_param' may not be queried with peek, stopped";
  
} elsif ($verb eq 'touch') {
  # Get the property value
  $obj_param = "$ARGV[1]";
  
  # Format check
  ($obj_param =~ /\A0*[0-9A-Fa-f]{1,8}\z/) or
    die "Invalid parameter value, stopped";
  
  # Decode integer value
  $obj_param = hex($obj_param);
}

# For "init" and "config" verbs, read in the JSON file, and check that
# all properties within are valid and have valid values
#
my $json;
if (($verb eq 'init') or ($verb eq 'config')) {
  
  # Read raw bytes in
  binmode(STDIN, ":raw") or die "Can't set binary input, stopped";
  {
    local $/;
    $json = <STDIN>;
  }
  
  # Parse as JSON
  eval {
    $json = decode_json($json);
  };
  if ($@) {
    die "Failed to parse JSON: $@";
  }
  
  # Make sure top-level entity is JSON object
  (ref($json) eq 'HASH') or
    die "JSON must encode a JSON object, stopped";
  
  # Check each property
  for my $pname (keys %$json) {
    # Check property format
    ($pname =~ /\A[A-Za-z0-9_]+\z/) or
      die "JSON property '$pname' has invalid name, stopped";
    
    # Check that property recognized
    (exists $json_props{$pname}) or
      die "JSON property '$pname' is unrecognized, stopped";
    
    # Check that property may be set with JSON
    ($json_props{$pname}) or
      die "JSON property '$pname' not allowed, stopped";
    
    # Get property value
    my $pval = $json->{$pname};
    
    # Check that property value is scalar
    (not ref($pval)) or
      die "JSON value for '$pname' must be scalar, stopped";
    
    # Convert property value to string
    $pval = "$pval";
    
    # Check specific property, normalizing integer properties and
    # converting UTF-8 path strings to binary
    if ($pname eq 'authsuffix') {
      ($pval =~ /\A[A-Za-z0-9_]{1,24}\z/) or
        die "JSON value for '$pname' is invalid, stopped";
      
    } elsif ($pname eq 'authlimit') {
      ($pval =~ /\A0*[1-9][0-9]{0,9}\z/) or
        die "JSON value for '$pname' is invalid, stopped";
      my $ival = int($pval);
      $pval = "$ival";
      
    } elsif ($pname eq 'authcost') {
      ($pval =~ /\A0*[1-9][0-9]?\z/) or
        die "JSON value for '$pname' is invalid, stopped";
      my $ival = int($pval);
      (($ival >= 5) and ($ival <= 31)) or
        die "JSON value for '$pname' is invalid, stopped";
      $pval = "$ival";
      
    } elsif ($pname =~ /\Apath/) {
      ($pval =~ /\A\//) or
        die "JSON value for '$pname' must begin with slash, stopped";
      ($pval =~ /\A[\x{20}-\x{7e}\x{a0}-\x{d7ff}\x{e000}-\x{ffff}]+\z/)
        or die "JSON value for '$pname' has invalid codevals, stopped";
      $pval = encode('UTF-8', $pval,
                Encode::FB_CROAK | Encode::LEAVE_SRC);
      
    } else {
      die "Unexpected";
    }
    
    # Write the (possibly changed) value back to the hash
    $json->{$pname} = $pval;
  }
}

# For "init" verb only, make sure that all the allowed properties are
# defined in the JSON
#
if ($verb eq 'init') {
  for my $pname (keys %json_props) {
    if ($json_props{$pname}) {
      (exists $json->{$pname}) or
        die "Property '$pname' is missing in JSON, stopped";
    }
  }
}

# Now we're ready to connect to the database
#
my $dbc = Yip::DB->connect($config_dbpath, 0);

# Choose the correct transaction mode for the verb
#
my $tmode;
if ($verb eq 'peek') {
  # The "peek" verb is read-only
  $tmode = 'r';

} elsif ($verb eq 'touch') {
  # The "touch" verb is read-write with lastmod update
  $tmode = 'rw';
  
} else {
  # All other verbs are read-write without lastmod update
  $tmode = 'w';
}

# Begin transaction
#
my $dbh = $dbc->beginWork($tmode);

# Perform the verbal action
#
if ($verb eq 'init') { # ===============================================
  # First step for "init" is to make sure nothing is currently in the
  # cvars table
  my $qr = $dbh->selectall_arrayref('SELECT cvarsid FROM cvars');
  ((not (ref($qr) eq 'ARRAY')) or (scalar(@$qr) < 1)) or
    die "cvars table must be empty to use init, stopped";
  
  # Set all the variables
  for my $pname ('epoch', 'lastmod', 'authsuffix', 'authsecret',
                  'authlimit', 'authcost', 'authpswd', 'pathlogin',
                  'pathlogout', 'pathreset', 'pathadmin', 'pathlist',
                  'pathdrop', 'pathedit', 'pathupload', 'pathimport',
                  'pathdownload', 'pathexport', 'pathgenuid') {
    # Determine the specific property value
    my $pval;
    if ($pname eq 'epoch') {
      $pval = sprintf("%x", $obj_param);
      
    } elsif ($pname eq 'lastmod') {
      my $lmi = 1 + makerandom(Size => 12, Strength => 0, Uniform => 1);
      $pval = sprintf("%x", $lmi);
      
    } elsif ($pname eq 'authsecret') {
      $pval = makerandom_octet(Length => 12, Strength => 0);
      $pval = encode_base64($pval, '');
      
    } elsif ($pname eq 'authpswd') {
      $pval = '?';
      
    } elsif ($json_props{$pname}) {
      $pval = $json->{$pname};
    }
    
    # Add the property into the table
    $dbh->do('INSERT INTO cvars(cvarskey, cvarsval) VALUES (?,?)',
              undef,
              $pname, $pval);
  }
  
} elsif ($verb eq 'peek') { # ==========================================
  # Query the requested variable
  my $qr = $dbh->selectrow_arrayref(
                  'SELECT cvarsval FROM cvars WHERE cvarskey=?',
                  undef,
                  $obj_param);
  (ref($qr) eq 'ARRAY') or die "Failed to find '$obj_param', stopped";
  $qr = "$qr->[0]";
  
  # Print the value
  print "$obj_param=$qr\n";
  
  # For epoch only, print the decoded date
  if ($obj_param eq 'epoch') {
    my $tv = hex($qr);
    my $dv = int($tv / 86400);
    $tv = $tv - ($dv * 86400);
    
    my ($y, $m, $d) = Add_Delta_Days(1970,1,1, $dv);
    
    my $h = int($tv / 3600);
    $tv = $tv % 3600;
    
    my $mi = int($tv / 60);
    $tv = $tv % 60;
    
    printf "(%04d-%02d-%02d %02d:%02d:%02d)\n",
            $y, $m, $d, $h, $mi, $tv;
  }
  
} elsif ($verb eq 'touch') { # =========================================
  # Query current lastmod value
  my $lmc = $dbh->selectrow_arrayref(
                    'SELECT cvarsval FROM cvars WHERE cvarskey=?',
                    undef,
                    'lastmod');
  (ref($lmc) eq 'ARRAY') or die "No lastmod variable defined, stopped";
  $lmc = hex($lmc->[0]);
  
  # If given floor value greater than current lastmod value, update
  # current lastmod value; when the transaction is closed, the lastmod
  # will be updated again in any case
  if ($lmc < $obj_param) {
    $dbh->do(
            'UPDATE cvars SET cvarsval=? WHERE cvarskey=?',
            undef,
            sprintf("%x", $obj_param), 'lastmod');
  }
  
} elsif ($verb eq 'config') { # ========================================
  # Make sure that all variables are defined
  for my $pname ('epoch', 'lastmod', 'authsuffix', 'authsecret',
                  'authlimit', 'authcost', 'authpswd', 'pathlogin',
                  'pathlogout', 'pathreset', 'pathadmin', 'pathlist',
                  'pathdrop', 'pathedit', 'pathupload', 'pathimport',
                  'pathdownload', 'pathexport', 'pathgenuid') {
    my $qrd = $dbh->selectrow_arrayref(
                'SELECT cvarsid FROM cvars WHERE cvarskey=?',
                undef,
                $pname);
    (ref($qrd) eq 'ARRAY') or
      die "Property '$pname' not currently defined in table, stopped";
  }
  
  # Update any given values
  for my $k (keys %$json) {
    $dbh->do('UPDATE cvars SET cvarsval=? WHERE cvarskey=?',
              undef,
              $json->{$k}, $k);
  }
  
} elsif ($verb eq 'logout') { # ========================================
  # Set a new admin secret key
  my $secret = makerandom_octet(Length => 12, Strength => 0);
  $secret = encode_base64($secret, '');
  $dbh->do('UPDATE cvars SET cvarsval=? WHERE cvarskey=?',
            undef,
            $secret, 'authsecret');
  
} elsif ($verb eq 'forgot') { # ========================================
  # Set a new admin secret key
  my $secret = makerandom_octet(Length => 12, Strength => 0);
  $secret = encode_base64($secret, '');
  $dbh->do('UPDATE cvars SET cvarsval=? WHERE cvarskey=?',
            undef,
            $secret, 'authsecret');
            
  # Reset password
  $dbh->do('UDPATE cvars SET cvarsval=? WHERE cvarskey=?',
            undef,
            '?', 'authpswd');
  
} else { # =============================================================
  die "Unexpected";
}

# Finish transaction; for the "touch" verb this will also update the
# lastmod in the usual way
#
$dbc->finishWork;

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
