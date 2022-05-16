#!/usr/bin/env perl
use strict;
use warnings;

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yipdownload.pl - Global resource and template download administration
CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipdownload.pl?template=example
  /cgi-bin/yipdownload.pl?global=907514

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script serves template text files and global resources directly to the
client, allowing for global resources and templates to be viewed and
downloaded.  The client must have an authorization cookie to use this
script.

B<Note:> Global resources are served by this script with caching
disabled so that the client always gets the current copy.  Also,
resources are served with attachment disposition intended for
downloading.  This is I<not> the script to use for serving global
resources to the public.

The GET request takes either a C<template> variable that names the
template to download, or a C<global> variable that gives the UID of the
global resource to download.  Only GET requests are supported.

=cut

# =========
# Templates
# =========

# Malformed request error template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   reason - an error message to show the user
#
my $err_template = Yip::Admin->format_html('Download', q{
    <h1>Download</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    <p>Download failed: <TMPL_VAR NAME=reason ESCAPE=HTML>!</p>
});

# Missing resource error template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
my $missing_template = Yip::Admin->format_html('Download', q{
    <h1>Download</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    <p>Not found!</p>
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
# Do not use for sending the not found error.  Instead, use
# send_missing.
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

# send_missing(yap)
#
# Send an error page back to the client indicating that the request
# resource was not found.
#
# Provide a Yip::Admin utility object.  This function does not return.
#
sub send_missing {
  # Check parameter count
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  # Get parameter and check
  my $yap = shift;
  (ref($yap) and $yap->isa('Yip::Admin')) or
    die "Wrong parameter type, stopped";
  
  # Set status and send error
  $yap->setStatus(404, 'Not Found');
  $yap->sendTemplate($missing_template);
}

# ==============
# CGI entrypoint
# ==============

# Get normalized method and make sure it is GET
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

# Make sure we didn't get both template and global
#
((not exists $vars->{'template'}) or (not exists $vars->{'global'})) or
  send_error($yap, 
    'Do not specify both template and global at same time');

# Make sure we got either template or global
#
((exists $vars->{'template'}) or (exists $vars->{'global'})) or
  send_error($yap, 'Specify either template or global');

# Different handling depending on type
#
if (exists $vars->{'template'}) { # ====================================
  # Update backlink
  $yap->setBacklink($yap->getVar('pathlist') . '?report=templates');
  
  # Get the template name and check format
  my $tname = $vars->{'template'};
  ($tname =~ /\A[A-Za-z0-9_]{1,31}\z/) or
    send_error($yap, 'Invalid template name');
  
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Look up the template code
  my $qr = $dbh->selectrow_arrayref(
                  'SELECT tmplcode FROM tmpl WHERE tmplname=?',
                  undef,
                  $tname);
  (ref($qr) eq 'ARRAY') or send_missing($yap);
  $qr = $qr->[0];
  
  # Finish transaction
  $dbh = $dbc->finishWork;
  
  # Send the template code back to client as plain text
  $yap->sendRaw($qr, 'text/plain; charset=utf-8', "$tname");
  
} elsif (exists $vars->{'global'}) { # =================================
  # Update backlink
  $yap->setBacklink($yap->getVar('pathlist') . '?report=globals');
  
  # Get the UID and check format
  my $uid = $vars->{'global'};
  ($uid =~ /\A[1-9][0-9]{5}\z/) or
    send_error($yap, 'Invalid unique ID');
  $uid = int($uid);
  
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Look up the resource and get its MIME type
  my $qr = $dbh->selectrow_arrayref(
                  'SELECT rtypeid, gresraw FROM gres WHERE gresuid=?',
                  undef,
                  $uid);
  (ref($qr) eq 'ARRAY') or send_missing($yap);
  my $ct  = $qr->[0];
  my $raw = $qr->[1];
  
  $qr = $dbh->selectrow_arrayref(
              'SELECT rtypemime FROM rtype WHERE rtypeid=?',
              undef,
              $ct);
  (ref($qr) eq 'ARRAY') or die "Foreign key missing, stopped";
  $ct = $qr->[0];
  
  # Finish transaction
  $dbc->finishWork;
  
  # Send the resource back to client with appropriate MIME type
  $yap->sendRaw($raw, $ct, "global-$uid");
  
} else { # =============================================================
  die "Unexpected";
}

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
