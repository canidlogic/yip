#!/usr/bin/env perl
use strict;
use warnings;

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yipdownload.pl - Global resource, attachment, and template download
administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipdownload.pl?template=example
  /cgi-bin/yipdownload.pl?global=907514
  /cgi-bin/yipdownload.pl?local=8519841009
  
  /cgi-bin/yipdownload.pl?template=example&preview=1
  /cgi-bin/yipdownload.pl?global=907514&preview=1
  /cgi-bin/yipdownload.pl?local=8519841009&preview=1

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script serves template text files, global resources, and attachment
files directly to the client, allowing for global resources,
attachments, and templates to be viewed and downloaded.  The client must
have an authorization cookie to use this script.

B<Note:> Global resources and attachment files are served by this script
with caching disabled so that the client always gets the current copy.
Also, resources and attachments are served with attachment disposition
intended for downloading.  This is I<not> the script to use for serving
global resources or attachments to the public.

The GET request takes either a C<template> variable that names the
template to download, or a C<global> variable that gives the UID of the
global resource to download, or a C<local> variable that takes ten
digits, the first six being the UID of a post and the last four being
the attachment index to fetch.  Only GET requests are supported.

If the optional C<preview> parameter is provided and set to 1, then
instead of serving with attachment disposition, the resource is served
with the default inline disposition so that the browser will attempt to
show the resource or attachment or template directly.  Providing
C<preview> with it set to 0 is equivalent to not providing the parameter
at all.  No other value is valid.

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
    <p class="msg">
      Download failed: <TMPL_VAR NAME=reason ESCAPE=HTML>!
    </p>
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
    <p class="msg">
      Not found!
    </p>
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

# Make sure we got exactly one of template, global, and local
#
my $qsc = 0;
for my $qsn ('template', 'global', 'local') {
  if (exists $vars->{$qsn}) {
    $qsc++;
  }
}
($qsc == 1) or
  send_error($yap, 'Invalid script invocation');

# Set backlink
#
if (exists $vars->{'template'}) {
  $yap->setBacklink($yap->getVar('pathlist') . '?report=templates');

} elsif (exists $vars->{'global'}) {
  $yap->setBacklink($yap->getVar('pathlist') . '?report=globals');

} elsif (exists $vars->{'local'}) {
  $yap->setBacklink($yap->getVar('pathlist') . '?report=posts');
  
} else {
  die "Unexpected";
}

# If local parameter is present and it has the correct format, update
# the backlink to lead to the post preview, else leave it at its current
# setting of leading back to the post report
#
if (exists $vars->{'local'}) {
  if ($vars->{'local'} =~ /\A[1-9][0-9]{5}[1-9][0-9]{3}\z/) {
    my $bli = substr($vars->{'local'}, 0, 6);
    $yap->setBacklink($yap->getVar('pathexport')
                        . "?post=$bli&preview=1");
  }
}

# Check for preview mode
#
my $is_preview = 0;
if (exists $vars->{'preview'}) {
  if ($vars->{'preview'} =~ /\A0\z/) {
    $is_preview = 0;
  
  } elsif ($vars->{'preview'} =~ /\A1\z/) {
    $is_preview = 1;
  
  } else {
    send_error($yap, 'Invalid preview mode');
  }
}

# Different handling depending on type
#
if (exists $vars->{'template'}) { # ====================================
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
  
  # Determine disposition parameter
  my $disp = undef;
  if (not $is_preview) {
    $disp = "$tname";
  }
  
  # Send the template code back to client as plain text
  $yap->sendRaw($qr, 'text/plain; charset=utf-8', $disp);
  
} elsif (exists $vars->{'global'}) { # =================================
  # Get the UID and check format
  my $uid = $vars->{'global'};
  ($uid =~ /\A[1-9][0-9]{5}\z/) or
    send_error($yap, 'Invalid unique ID');
  $uid = int($uid);
  
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Look up the resource and get its MIME type
  my $qr = $dbh->selectrow_arrayref(
                  'SELECT rtypemime, gresraw '
                  . 'FROM gres '
                  . 'INNER JOIN rtype ON rtype.rtypeid=gres.rtypeid '
                  . 'WHERE gresuid=?',
                  undef,
                  $uid);
  (ref($qr) eq 'ARRAY') or send_missing($yap);
  my $ct  = $qr->[0];
  my $raw = $qr->[1];
  
  # Finish transaction
  $dbc->finishWork;
  
  # Determine disposition parameter
  my $disp = undef;
  if (not $is_preview) {
    $disp = "global-$uid";
  }
  
  # Send the resource back to client with appropriate MIME type
  $yap->sendRaw($raw, $ct, $disp);

} elsif (exists $vars->{'local'}) { # =================================
  # Parse the local code
  ($vars->{'local'} =~ /\A([1-9][0-9]{5})([1-9][0-9]{3})\z/) or
    send_error($yap, 'Invalid attachment local code');
  my $uid = int($1);
  my $ati = int($2);
  
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Look up the attachment and get its MIME type
  my $qr = $dbh->selectrow_arrayref(
                  'SELECT rtypemime, attraw '
                  . 'FROM att '
                  . 'INNER JOIN rtype ON rtype.rtypeid=att.rtypeid '
                  . 'INNER JOIN post ON post.postid=att.postid '
                  . 'WHERE postuid=? AND attidx=?',
                  undef,
                  $uid, $ati);
  (ref($qr) eq 'ARRAY') or send_missing($yap);
  my $ct  = $qr->[0];
  my $raw = $qr->[1];
  
  # Finish transaction
  $dbc->finishWork;
  
  # Determine disposition parameter
  my $disp = undef;
  if (not $is_preview) {
    $disp = "att-$uid-$ati";
  }
  
  # Send the resource back to client with appropriate MIME type
  $yap->sendRaw($raw, $ct, $disp);

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
