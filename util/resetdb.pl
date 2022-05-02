#!/usr/bin/env perl
use strict;
use warnings;

# Yip imports
use Yip::DB;
use YipConfig;

=head1 NAME

resetdb.pl - Configure the cvars table of the Yip CMS database.

=head1 SYNOPSIS

  ./resetdb.pl init 2022-05-01T13:25:00 < vars.json
  ./resetdb.pl peek epoch
  ./resetdb.pl touch 4096
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
=item C<authsuffix>
=item C<authlimit>
=item C<authcost>
=item C<pathlogin>
=item C<pathlogout>
=item C<pathreset>
=item C<pathadmin>
=item C<pathlist>
=item C<pathdrop>
=item C<pathedit>
=item C<pathupload>
=item C<pathimport>
=item C<pathdownload>
=item C<pathexport>
=item C<pathgenuid>
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
=item C<epoch>
=item C<lastmod>
=item C<authsuffix>
=item C<authlimit>
=item C<authcost>
=item C<pathlogin>
=item C<pathlogout>
=item C<pathreset>
=item C<pathadmin>
=item C<pathlist>
=item C<pathdrop>
=item C<pathedit>
=item C<pathupload>
=item C<pathimport>
=item C<pathdownload>
=item C<pathexport>
=item C<pathgenuid>
=back

See the documentation of the C<cvars> table in the C<createdb.pl> script
for the meaning of each of these configuration variables.

=head2 touch verb

The C<touch> verb updates the C<lastmod>.  It takes an object parameter
that must be an unsigned sequence of one or more decimal digits, with
the decoded decimal value in signed 32-bit integer range.  First, if the
C<lastmod> variable is less than the given integer value, it is
increased to the given integer value.  Second, the usual procedure is
applied to increase the C<lastmod>, as described in the "General rules"
section of the C<createdb.pl> script documentation.

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
to the restored image.  Once the C<touch operation is performed,
subsequent updates will not generate ETag values that have already been
used and therefore will not interfere with client caching.

=head2 config verb

The C<config> verb changes the freely mutable configuration variables in
the C<cvars> table.  The new variable values are read from a JSON file
on standard input.  The format of this JSON file is the same as the JSON
file passed to the C<init> verb, except that all properties are
optional.  Properties that are not included are left at their current
values.

=head logout verb

The C<logout> verb changes the C<authsecret> configuration variable to
a different randomly chosen value.  This has the effect of immediately
invalidating any currently active authorization cookies.  In other
words, any current administrators are immediately logged out and will
need to log in again with their password.

=head forgot verb

The C<forgot> verb is used to reset the password and login (as would be
the case for a forgotten password).  This will simultaneously change
C<authsecret> to a different randomly chosen value and set C<authpswd>
to C<?>  This has the same effect as for the C<logout> verb, except that
no logins are permitted after everyone is logged out, and the password
will need to be reset before administrator login works again.

=cut
