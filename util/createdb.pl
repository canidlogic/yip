#!/usr/bin/env perl
use strict;
use warnings;

# Yip imports
use Yip::DB;
use YipConfig;

=head1 NAME

createdb.pl - Create a new Yip CMS database with the appropriate
structure.

=head1 SYNOPSIS

  ./createdb.pl

=head1 DESCRIPTION

This script is used to create a new, empty CMS database for Yip, with
the appropriate structure but no records.  Uses Yip::DB and YipConfig,
so you must configure those two correctly before using this script.  See
the documentation in C<Yip::DB> for further information.

The database must not already exist or a fatal error occurs.  You must
use the C<resetdb.pl> script on the newly created database before it can
be used properly.

The SQL string embedded in this script contains the complete database
structure.  The following subsections describe the function of each
table within the database.  But first, there is a section of information
that applies across all tables.

=head2 General rules

Whenever any change is made to any table except C<cvars>, the C<lastmod>
record in C<cvars> must be updated.  When the variable is first defined
with the C<resetdb.pl> script, it has a randomly generated value in the
range [1, 4096].  Each time it is updated, the current value of the
variable is incremented by a randomly determined quantity in the range
[1, 64].  The C<makerandom> function of C<Crypt::Random> is used to
select these random values, with a bitsize of 12 bits for the initial
value and a C<Size> of 6 bits for the increment values; the C<Strength>
is always set to zero to prevent blocking, and C<Uniform> is always set
to one to use the full bit range.

The SQLite string mode should always be set to binary.  Text strings
should therefore be decoded and encoded between UTF-8 when passing
between the script and the database engine.  The C<Yip::DB> module will
properly set up binary string mode on the database.  Clients just need
to remember to manually encode Unicode strings into UTF-8 before passing
them into SQL statements, and manually decode binary strings received as
SQL results from UTF-8.

Template processing is used in multiple tables.  Templates always follow
the format defined by the C<HTML::Template> library.  The template
engine is initialized with its default configuration, except for the
following changes:

=over 4

=item C<die_on_bad_params> disabled

This means you don't have to actually use all the various parameters
that are defined for a template.

=item C<loop_context_vars> enabled

This gives you additional template variables for use within loops.  See
C<HTML::Template> documentation for further details of what this means.
(You can ignore this if you don't need it.)

=item C<no_includes> enabled

This prevents templates from loading other templates with include
statements.  Templates are stored within the database, so loading won't
work properly anyway.

=back

=head2 cvars table

The C<cvars> tables stores configuration variables related to the
administration CGI scripts, as well as the C<epoch> and C<lastmod>
variables.  These variables can't be altered through the CGI
administration scripts, to prevent accidentally locking oneself out of
administration CGI or corrupting core functionality of the database.

This table is a simple key/value map where the key field is C<cvarskey>
and the value field is C<cvarsval>.  Each of the C<path> variables must
begin with a forward slash and should be URI path on the server, such
that they can be directly embedded within HTML element attribute values
without any further escaping.  The following variables are defined in
this table:

=over 4

=item C<epoch>

The number of seconds since midnight at the start of January 1, 1970
that the epoch used by the Yip CMS occurs.  Once set, this may not be
changed.  Stored as an unsigned base-16 string.  This epoch is in a
"floating" timezone that is equivalent to whatever the local timezone
is.  No leap seconds are used, and daylight saving time jumps are left
ambiguous so that every day has exactly 24 hours and every minute has
exactly 60 seconds.  The decoded epoch time may be not be later than
23:59 on December 31, 4999.

=item C<lastmod>

An integer value that is increased each time there is any update to the
CMS database for any table except the C<cvars> table.  This is used to
generate unique ETag values for generated pages, so that caching can
work correctly.  This must be updated by scripts that change the
database in any way except for the C<cvars> table.  Stored as an
unsigned base-16 string.  See the earlier section on "General Rules" for
the specifics of how this value is used.  Random processes are involved
to make it difficult for HTTP clients to deduce information that they
shouldn't have access to.

=item C<authsuffix>

The name suffix of the cookie used for authorizing administrator CGI
operations.  Must be a sequence of one to 24 ASCII alphanumerics and
underscores.  To form the full cookie name, C<__Host-> will be prefixed
to this suffix, which means a cookie for only this specific domain, for
the whole domain, on HTTPS only.  Within the current domain, no other
CGI system should use cookies with the same cookie name.

=item C<authsecret>

A randomly generated string of 16 base-64 characters.  To generate a
value, begin with twelve random octets generated by C<Crypt::Random> and
then encode these twelve random octets into sixteen random base-64
characters.  This random key will be used to generate HMAC-MD5 digests
to validate client cookies for administrator CGI operations.  Each time
the secret key is changed, everyone currently "logged in" with a valid
cookie will immediately be logged out and have to authenticate again.

=item C<authlimit>

The number of minutes that an issued cookie value will work for before
it becomes invalid.  New cookies are issued at the end of each
successful operation, so this is essentially an inactivity timer, after
which authorization cookies automatically lose their validity.  Stored
as an unsigned decimal string.

=item C<authcost>

The bcrypt I<cost> parameter for hashing the password used in
C<authpswd>.  The higher the cost, the more difficult it is to break the
password hash, but the more time it takes to check a password.  Must be
an integer in range [5, 31].  Changing this has no effect on the current
password hash, so you must then reset the password for this to take
effect.  Stored as an unsigned decimal string.

=item C<authpswd>

The C<Crypt::Bcrypt> password hash of the password that must be provided
to login in and get an administrator cookie B<OR> the special value C<?>
which means that no password will currently work, except the password
reset script will accept any value for the current password.  The C<?>
therefore is used to initialize the system, after which the password is
reset to its appropriate value.  It can also be used for a password
reset if the current password is forgotten.

=item C<pathlogin>

Path to the login script.  GET is a prompt page, POST performs the
login.

=item C<pathlogout>

Path to the logout script.  GET is a confirmation page, POST performs
the logout.

=item C<pathreset>

Path to the password reset script.  GET is a prompt page, POST performs
the reset.

=item C<pathadmin>

Path to the administrator control panel page, which has links to all the
other administration scripts.  GET method only.

=item C<pathlist>

Path to the listing script.  This takes a GET query string containing a
single variable C<report> that must be one of the values C<types>
C<vars> C<templates> C<archives> C<globals> or C<posts> and generates a
report for the requested type.  The C<templates> C<globals> and C<posts>
reports have links to C<pathdownload> and C<pathexport> scripts so that
any of the listed data items can be downloaded.  The C<templates> report
also has links to C<pathedit> for each template.  All reports have links
for each item leading to the C<pathdrop> script confirmation that allows
items to be dropped.

=item C<pathdrop>

Path to the drop script.  GET requests require a single variable whose
key identifies the type of resource to drop and whose value identifies
the ID of the resource to drop.  The key name might be one of C<type>
C<var> C<template> C<archive> C<global> or C<post>.  The GET request is
a prompt page to confirm deletion, and then the POST request will
perform the actual drop.

=item C<pathedit>

Path to the editor script.  GET requests require a single variable whose
key is either C<class> or C<template>.  If the key is C<class> then the
value must be either C<types> C<vars> or C<archives>.  If the key is
C<template> then the value must be the name of a template to edit.  The
GET page will fill an editable text area with the current state.  For
C<class> requests, the current state will be JSON text containing all
the current data.  For C<template> requests, the current state will be
the current template value, or an empty string if no template with that
name is currently defined.  POST requests then perform the update, which
may add new records or update current records, but never drops records.

=item C<pathupload>

Path to the upload global resource script.  GET requests display an
input form, and POST requests perform the update.  File upload is used
to transfer the resource.  New resources may be added or existing
resources may be overwritten.

=item C<pathimport>

Path to the import post script.  GET requests display an input form, and
POST requests perform the update.  File upload is used to transfer the
post, which is contained within a Zip archive.  The import operation is
able to either add a new post or overwrite an existing post.

=item C<pathdownload>

Path to the download script.  This takes a GET query string with a
single variable whose key identifies the type of resource requested and
whose value identifies the ID of the resource.  The key name is either
C<template> or C<global>.  The script transfers the raw data contents.

=item C<pathexport>

Path to the export post script.  GET requests require a single variable
C<post> whose value is the UID of the post that is being requested.
This shows a confirmation prompt.  The POST request will generate the
actual archive of the post to download.

=item C<pathgenuid>

Path to the UID generator script.  Takes a GET query string containing
a single variable C<table> that is either C<post> C<global> or
C<archive> indicating what type of object this UID is being generated
for.  Each GET requests randomly generates a new unique ID.

=back

=head2 rtype table

The C<rtype> table defines data types used for serving global resources.
It does I<not> define the type used for generated HTML pages (see later
in this section), though if static HTML pages are uploaded as global
resources, these HTML pages I<will> have their types recorded in this
table.

Each data type has an C<rtypename> field that is used to uniquely
identify the data type.  This field is I<not> the MIME type, since
multiple data type records could have the exact same MIME type.  This
type name is never transmitted to HTTP clients, so it does not have to
follow any public standards.  The name must be a case-sensitive sequence
of one to 31 ASCII alphanumerics and underscores.

Each data type has an C<rtypemime> field that stores the MIME type given
to HTTP clients that request resources of this type.  This does not have
to be unique within the C<rtype> table.  This field is the value that
will be transmitted in the C<Content-Type> header.

The syntax of the C<rtypemime> field is based on the syntax given in
RFC 2045 section 5.1 "Syntax of the Content-Type Header Field."  It must
follow this syntax:

  mime-type := token "/" token (param)*
  
  param := ";" SP token "=" (uval | qval)
  
  token := tchar+
  qval  := <"> (qchar)* <">
  uval  := uchar+
  
  uchar is any visible US-ASCII character in range [0x21, 0x7E] EXCEPT:
  ( ) < > @ , ; : \ " / [ ] ? =
  
  tchar is same as uchar except it excludes uppercase letters
  
  qchar is any printing US-ASCII character in range [0x20, 0x7E] EXCEPT
  the double quote

The full MIME type string is limited to at most 63 characters.

Each data type also has an C<rtypecache> field that stores client
caching information for the specific data type.  This is an integer
value.  If it is greater than zero, then it specifies the number of
seconds that the resource stays fresh in the client cache (C<max-age>
semantics).  Positive values may not exceed 31536000, which is the
number of seconds in 365 days.  If this integer value has the special
value zero, then it means clients may cache the resource, but the cached
copy is immediately stale (C<no-cache> semantics).  If this integer
value has the special value -1, then it means clients should never cache
the resource (C<no-store> semantics).

For generated HTML pages, the following MIME type is always used:

  text/html; charset=utf-8

(This is also allowed by the XHTML specification as a compatibility
feature.)

Generated CGI pages always use C<no-store> as the cache behavior to
prevent any sort of caching.  Other generated pages have their cache
behavior defined by the template record in the C<tmpl> table.

=head2 gres table

The C<gres> table stores global resources.  Each global resource has a
C<gresuid> field that uniquely identifies it within the global resource
table.  This field is an integer value in range [100000, 999999].  You
can use the UID generation script to generate a random unique value.

Each global resource also has a C<gresdig> field that stores a SHA-1
digest of the binary resource data as a base-16 string with lowercase
letters.

The type of each global resource is determined by a foreign key into the
C<rtype> table.

Finally, the C<gresraw> field stores the raw binary BLOB of the
resource.

Global resources are intended for things like CSS stylesheets, webfonts,
and logo images that are used across the website.  However, you can also
store static HTML pages as global resources.

The caching behavior of resources is determined by the data type record
in the C<rtype> table.  The SHA-1 digest of the binary data is used as
the ETag value for caching.

=head2 vars table

The C<vars> table stores template variables.  See also the C<cvars>
table, which has the same structure but stores configuration variables
instead.  All of the variables defined in the C<vars> table are
"non-critical" which means that no matter what you do this table, it
shouldn't lock you out of the CGI administration scripts or totally
break the database, so you should be able to fix any problems you may
cause using the CGI administration tools.

This table is a simple key/value map where the key field is C<varskey>
and the value field is C<varsval>.  The names stored in the key field
must be one to 31 characters long and consist only of ASCII lowercase
letters, digits, and underscores.  The values are strings.

There is a difference between variables whose name starts with an
underscore and variables for which the first character of the name is
not an underscore.  Variables that do not start with an underscore are
public template variables that are accessible to all templates.
Variables that start with an underscore are I<not> directly accessible
in templates, though they may have an effect on how templates are
processed.

It is completely up to the client to decide which template variables to
use (so long as the names don't begin with an underscore).  However,
only the following underscore names are defined:

=over 4

=item C<_longm>

The long month names.  Whenever templates have generated template
variables involving dates, one of the date variables given is the long
month name.  This is intended to be the full name of the month written
out in the local language.  Since this is displayed to the user of the
generated pages, it should be properly localized to the language that
the user expects.

Specifically, the string value of this variable must be twelve separate
names in order of the months with ASCII vertical bar used as the
separator character with no additional whitespace.  (Therefore, there
should be exactly eleven vertical bars.)  This value should be a binary
string encoded in UTF-8.

=item C<_shortm>

Equivalent to C<_longm> except each month name should have its
abbreviated form.  (In many locales, there are standard abbreviations
for months.)  If there are no abbreviated forms, this variable can be
set to the same value as C<_longm>

=back

=head2 post table

The C<post> table stores the posts.  Each post has a C<postuid> field
that uniquely identifies it within the post table.  This field is an
integer value in range [100000, 999999].  You can use the UID generation
script to generate a random unique value.

Each post also has a C<postdate> that stores the publication time of the
post.  This value is an integer that counts the number of seconds that
have elapsed since the epoch defined by the C<epoch> variable in the
C<cvars> table.  No leap seconds are used, and daylight saving time
jumps are left ambiguous so that every day has exactly 24 hours and
every minute has exactly 60 seconds.  Negative values are allowed, so
long as the negative value added to the C<epoch> value does not go below
zero.  For positive values, the value added to the C<epoch> value must
not go beyond December 31, 4999.  Each post must have a unique
C<postdate> so that posts can unambiguously be sorted.

Finally, each post has a C<postcode> field that stores the post as a
binary string encoded in UTF-8.  This is an HTML template in the format
of C<HTML::Template> but normally it doesn't contain a full HTML page,
rather just the body text of the post.

Within the C<HTML::Template> code for the post, all variables that do
not begin with an underscore in the C<vars> table will be available as
template variables.  In addition, the following variables that all begin
with an underscore will be set for the specific post:

=over 4

=item C<_full>

Set to true integer value of 1 if currently generating a post page.  Set
to false integer value of 0 if currently generating a catalog or archive
listing.  If you ignore this, then posts will appear the same both when
viewed individually and when viewed in catalog and archive listings.
Otherwise, you can use this as a conditional within the template so that
the full text only appears for post pages, and otherwise a link appears
to the post page for "Read more" type of functionality.

=item C<_partial>

The inverse of the C<_full> variable, such that when C<_full> is one,
this is zero, and when C<_full> is zero, this is one.

=item C<_uid>

The UID of the post as a string of exactly six decimal digits.

=item C<_year>

The four-digit year of the publication time.

=item C<_mon>

The month number of the publication time in range [1, 12].  May be
either a one-digit or two-digit decimal number.

=item C<_monz>

Equivalent to C<_mon> except zero-padded to always be two digits.

=item C<_mons>

The short name of the month.  This is determined by looking up the month
number index within the string of short month names stored in the
C<_shortm> variable in the C<vars> table.

=item C<_monl>

The long name of the month.  This is determined by looking up the month
number index within the string of long month names stored in the
C<_longm> variable in the C<vars> table.

=item C<_day>

The day of the month of the publication time, in range [1, 31].  May be
either a one-digit or two-digit decimal number.

=item C<_dayz>

Equivalent to C<_day> except zero-padded to always be two digits.

=item C<_hr24>

The hour of the publication time, in a 24-hour format in range [0, 23].
May be either a one-digit or two-digit decimal number.

=item C<_hr24z>

Equivalent to C<_hr24> except zero-padded to always be two digits.

=item C<_hr12>

The hour of the publication time, in a 12-hour format in range [1, 12].
May be either a one-digit or two-digit decimal number.

=item C<_hr12z>

Equivalent to C<_hr12> except zero-padded to always be two digits.

=item C<_apml>

Whether the publication time in 12-hour format is AM or PM.  This
variable is either a single lowercase letter C<a> or a single lowercase
letter C<p>

=item C<_apmu>

Equivalent to C<_apml> except in uppercase.

=item C<_min>

The minute of the publication time, in range [0, 59].  May be either a
one-digit or two-digit decimal number.

=item C<_minz>

Equivalent to C<_min> except zero-padded to always be two digits.

=item C<_sec>

The seconds of the publication time, in range [0, 59].  May be either a
one-digit or two-digit decimal number.

=item C<_secz>

Equivalent to C<_sec> except zero-padded to always be two digits.

=back

=head2 att table

The C<att> table stores attached resources.  This table is similar to
the global resources table, except each resource is associated with a
specific post.

Each resource record has a foreign key to the C<post> table to identify
which post the resource is attached to, and a field C<attidx> that
stores an integer in range [1000, 9999] which is the index of the
resource for the specific post.  The foreign key to the C<post> table
together with the C<attidx> field uniquely identify each attached
resource.

Each attached resource also has an C<attdig> field that stores a SHA-1
digest of the binary resource data as a base-16 string with lowercase
letters.

The type of each attached resource is determined by a foreign key into
the C<rtype> table.

Finally, the C<attraw> field stores the raw binary BLOB of the resource.

The caching behavior of attached resources is determined by the data
type record in the C<rtype> table.  The SHA-1 digest of the binary data
is used as the ETag value for caching.

=head2 parc table

The C<parc> table defines post archives.  Having all posts in a single
page listing can quickly make the catalog page impractically large.  To
organize a large number of posts, older posts can be moved to archives.
Then, the catalog page only includes the most recent posts and links to
each of the archives.  For simplicity, Yip does not allow hierarchies of
archives; each post must either be a recent post, or it must in exactly
one of the archives.

Each archive has a C<parcuid> field that uniquely identifies it within
the archive table.  This field is an integer value in the range
[100000, 999999].  You can use the UID generation script to generate a
random unique value.

Each archive also has a C<parcname> field that will be display name of
the archive shown to user.  This is a binary string, and you can include
Unicode if you encode it into UTF-8.

Finally, each archive has a C<parcuntil> field that determines which
records included in the archive.  Each archive must have a unique
C<parcuntil> field.  If an archive has the lowest C<parcuntil> field of
all the archives, then it will include all the oldest posts, up to and
including the C<postdate> equal to C<parcuntil>.  Otherwise, let the
I<lesser archive> be the archive that has the next-lowest C<parcuntil>
field value.  An archive that is not the oldest archive will include all
posts that have a C<postdate> less than or equal to the C<parcuntil>
field B<AND> greater than the C<parcuntil> of the lesser archive.

Posts that have a C<postdate> greater than the C<parcuntil> field of the
newest archive will not be in any archive and appear on the main catalog
page.  If there are no archives defined, then all posts will appear on
the main catalog page.

=head2 templ table

The C<tmpl> table stores HTML templates used for generated page content.
However, this table does I<not> store templates used for the
administration CGI scripts; those templates are embedded directly within
the scripts.

Each template has a C<tmplname> field that uniquely identifies the
template.  Each template also has a C<tmplcache> field that stores
caching information for all pages generated by this template; see the
description of the C<rtypecache> field in the C<rtype> table for the
details of what the caching field means.  The ETag of generated pages
will be set to the C<lastmod> variable defined in the C<cvars> table.
Finally, the C<tmplcode> field stores the actual template code as a
binary string encoded in UTF-8.

Within the C<HTML::Template> code, all variables that do not begin with
an underscore in the C<vars> table will be available as template
variables.  In addition, each specific template may have specific
template variables that all begin with an underscore.  These specific
template variables are documented in the subsections below.

Only certain template names are recognized in the Yip system.  It is
allowable to add templates with other names, but these will serve no
purpose.  The following subsections document the recognized templates.

=head3 catalog template

The C<catalog> template generates the main catalog page.  The main
catalog page lists all posts that are not archived, and also lists all
archives.  The following specific template variables are defined in
addition to the usual template variables:

=over 4

=item C<_posts>

An array that can be used in a template loop, which contains all the
posts that are not in any archive, in reverse chronological order (most
recent post first).  Each post element will have all the underscore
variables that are defined for post-code templates (see the C<post>
table documentation), except for the C<_full> and C<_partial> variables.
In addition, each post element will have a C<_code> variable that stores
the code that was generated by running the post-code template with
C<_full> set to zero and C<_partial> set to one.

=item C<_archives>

An array that can be used in a template loop, which contains all the
archives, in reverse chronological order (most recent archive first).
Each archive element will have a C<_name> variable storing the name of
the archive and a C<_uid> variable storing the unique ID of the archive.

=back

=head3 archive template

The C<archive> template generates pages for specific archives.  Each
archive page lists just the posts that are contained within that
archive.  The following specific template variables are defined in
addition to the usual template variables:

=over 4

=item C<_posts>

An array that can be used in a template loop, which contains all the
posts within this archive, in reverse chronological order (most recent
post first).  The format of each post element is exactly the same as in
the C<_posts> variable for the catalog template.

=item C<_name>

The name of this archive.

=item C<_uid>

The unique ID of this archive.

=back

=head3 post template

The C<post> template generates pages for specific posts.  In addition to
the usual template variables, it also includes all underscore variables
that are defined for post-code templates (see the C<post> table
documentation), except for the C<_full> and C<_partial> variables.  In
addition to these variables, the following are also defined:

=over 4

=item C<_code>

The HTML code that was generated by running the post-code template for
this post with C<_full> set to one and C<_partial> set to zero.

=item C<_archive>

The (non-zero) unique ID of the archive to which this post belongs, or
zero if it is not in any archive.  You can use a template conditional on
this variable to check whether the post is in an archive.

=back

=cut

# Define a string holding the whole SQL script for creating the
# structure of the database, with semicolons used as the termination
# character for each statement and nowhere else
#
my $sql_script = q{

CREATE TABLE cvars(
  cvarsid  INTEGER PRIMARY KEY ASC,
  cvarskey TEXT UNIQUE NOT NULL,
  cvarsval TEXT NOT NULL
);

CREATE UNIQUE INDEX ix_cvars_key
  ON cvars(cvarskey);

CREATE TABLE rtype(
  rtypeid    INTEGER PRIMARY KEY ASC,
  rtypename  TEXT UNIQUE NOT NULL,
  rtypemime  TEXT NOT NULL,
  rtypecache INTEGER NOT NULL
);

CREATE UNIQUE INDEX ix_rtype_name
  ON rtype(rtypename);

CREATE TABLE gres(
  gresid  INTEGER PRIMARY KEY ASC,
  gresuid INTEGER UNIQUE NOT NULL,
  gresdig TEXT NOT NULL,
  rtypeid INTEGER NOT NULL
            REFERENCES rtype(rtypeid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  gresraw BLOB NOT NULL
);

CREATE UNIQUE INDEX ix_gres_uid
  ON gres(gresuid);

CREATE TABLE vars(
  varsid  INTEGER PRIMARY KEY ASC,
  varskey TEXT UNIQUE NOT NULL,
  varsval TEXT NOT NULL
);

CREATE UNIQUE INDEX ix_vars_key
  ON vars(varskey);

CREATE TABLE post(
  postid   INTEGER PRIMARY KEY ASC,
  postuid  INTEGER UNIQUE NOT NULL,
  postdate INTEGER UNIQUE NOT NULL,
  postcode TEXT NOT NULL
);

CREATE UNIQUE INDEX ix_post_uid
  ON post(postuid);

CREATE UNIQUE INDEX ix_post_date
  ON post(postdate);

CREATE TABLE att(
  attid   INTEGER PRIMARY KEY ASC,
  postid  INTEGER NOT NULL
            REFERENCES post(postid)
              ON DELETE CASCADE
              ON UPDATE RESTRICT,
  attidx  INTEGER NOT NULL,
  attdig  TEXT NOT NULL,
  rtypeid INTEGER NOT NULL
            REFERENCES rtype(rtypeid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  attraw  BLOB NOT NULL,
  UNIQUE  (postid, attidx)
);

CREATE INDEX ix_att_post
  ON att(postid);

CREATE UNIQUE INDEX ix_att_rec
  ON att(postid, attidx);

CREATE TABLE parc(
  parcid    INTEGER PRIMARY KEY ASC,
  parcuid   INTEGER UNIQUE NOT NULL,
  parcname  TEXT NOT NULL,
  parcuntil INTEGER UNIQUE NOT NULL
);

CREATE UNIQUE INDEX ix_parc_uid
  ON parc(parcuid);

CREATE UNIQUE INDEX ix_parc_until
  ON parc(parcuntil);

};

# ==================
# Program entrypoint
# ==================

# Check that we didn't get any arguments
#
($#ARGV < 0) or die "Not expecting arguments, stopped";

# Open database connection to a new database
#
my $dbc = Yip::DB->connect($config_dbpath, 1);

# Begin r/w transaction and get handle; do NOT update lastmod
# automatically
#
my $dbh = $dbc->beginWork('w');

# Parse our SQL script into a sequence of statements, each ending with
# a semicolon
#
my @sql_list;
@sql_list = $sql_script =~ m/(.*?);/gs
  or die "Failed to parse SQL script, stopped";

# Run all the SQL statements needed to build the the database structure
#
for my $sql (@sql_list) {
  $dbh->do($sql);
}
  
# Commit the transaction
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
