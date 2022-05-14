#!/usr/bin/env perl
use strict;
use warnings;

# Non-core dependencies
use Crypt::Random qw(makerandom_itv);

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yipgenuid.pl - Unique ID generator administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipgenuid.pl?table=post
  /cgi-bin/yipgenuid.pl?table=global
  /cgi-bin/yipgenuid.pl?table=archive

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles generating random but unique identity codes for posts,
global resources, and archives.  The client must have an authorization
cookie to use this script.

The GET request takes a query-string variable C<table> that indicates
which table a unique identity is being generated for (C<post> C<global>
or C<archive>).  Each time the page is loaded, a new unique ID will be
randomly generated that does not currently match any record in the
indicated table.

GET is the only method supported by this script.

=cut

# =========
# Constants
# =========

# The maximum number of attempts to generate a unique number that can be
# made before the operation fails.
#
my $MAX_RETRY = 256;

# =========
# Templates
# =========

# GET template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   utable - the table the code is being generated for
#   ucode - the generated code
#
my $get_template = Yip::Admin->format_html('Generate unique ID', q{
    <h1>Generate unique ID</h1>
    <div id="homelink"><a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Back
      &laquo;</a></div>
    <form>
      <div class="ctlbox">
        <div>Table:</div>
        <div>
          <input
            type="text"
            class="txbox"
            readonly
            value="<TMPL_VAR NAME=utable>">
        </div>
      </div>
      <div class="ctlbox">
        <div>Generated UID:</div>
        <div>
          <input
            type="text"
            class="txbox"
            readonly
            value="<TMPL_VAR NAME=ucode>">
        </div>
      </div>
    </form>
});

# Error template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   reason - an error message to show the user
#
my $err_template = Yip::Admin->format_html('Generate unique ID', q{
    <h1>Generate unique ID</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Home &laquo;</a>
    </div>
    <p>Generation operation failed:
      <TMPL_VAR NAME=reason ESCAPE=HTML>!</p>
});

# ===============
# Local functions
# ===============

# send_error(yap, errmsg)
#
# Send the custom error template back to the client, indicating that the
# operation failed.  The provided error message will be included in the
# error page.
#
# Provide a Yip::Admin utility object.  This function does not return.
#
sub send_error {
  # Check parameter count
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  # Get parameters and check
  my $yap = shift;
  (ref($yap) and $yap->isa('Yip::Admin')) or
    die "Wrong parameter type, stopped";
  
  my $emsg = shift;
  (not ref($emsg)) or die "Wrong parameter type, stopped";
  $emsg = "$emsg";
  
  # Fill in custom parameters
  $yap->customParam('reason', $emsg);
  
  # Set status and send error
  $yap->setStatus(400, 'Bad Request');
  $yap->sendTemplate($err_template);
}

# ==============
# CGI entrypoint
# ==============

# Get normalized method and make sure it's GET
#
my $request_method = Yip::Admin->http_method;
($request_method eq 'GET') or Yip::Admin->invalid_method;

# Start by connecting to database and loading admin utilities
#
my $dbc = Yip::DB->connect($config_dbpath, 0);
my $yap = Yip::Admin->load($dbc);

# Check that client is authorized
#
$yap->checkCookie;

# Get query string
#
my $qs = '';
if (defined $ENV{'QUERY_STRING'}) {
  $qs = $ENV{'QUERY_STRING'};
}

# Parse query string
#
my $vars = Yip::Admin->parse_form($qs);

# Make sure required parameter was provided
#
(exists $vars->{'table'}) or
  send_error($yap, 'Query string missing table parameter');

# Determine the name of the table, the name of the primary key field,
# and the name of the UID field
#
my $table_name;
my $primary_col;
my $uid_col;

if ($vars->{'table'} eq 'post') { # ====================================
  $table_name  = 'post';
  $primary_col = 'postid';
  $uid_col     = 'postuid';
  
} elsif ($vars->{'table'} eq 'global') { # =============================
  $table_name  = 'gres';
  $primary_col = 'gresid';
  $uid_col     = 'gresuid';
  
} elsif ($vars->{'table'} eq 'archive') { # ============================
  $table_name  = 'parc';
  $primary_col = 'parcid';
  $uid_col     = 'parcuid';
  
} else { # =============================================================
  send_error($yap, "Unrecognized table: '$vars->{'table'}'");
}

# Generate the random ID and make sure it's unique
#
my $uid;
my $uid_found = 0;

my $dbh = $dbc->beginWork('r');
for(my $i = 0; $i < $MAX_RETRY; $i++) {
  # Random number
  $uid = makerandom_itv(Strength => 0,
                        Lower => 100000,
                        Upper => 1000000);
  
  # Check range
  (($uid >= 100000) and ($uid <= 999999)) or next;
  
  # Finish if unique, else continue on
  my $qr = $dbh->selectrow_arrayref(
              "SELECT $primary_col "
              . "FROM $table_name "
              . "WHERE $uid_col=?",
              undef,
              $uid);
  unless (ref($qr) eq 'ARRAY') {
    $uid_found = 1;
    last;
  }
}
($uid_found) or
  send_error($yap, 'Ran out of retry attempts during generation');
$dbc->finishWork;

# Set custom parameters
$yap->customParam('utable', $vars->{'table'});
$yap->customParam('ucode' , $uid);

# Send the result template to client
$yap->sendTemplate($get_template);

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
