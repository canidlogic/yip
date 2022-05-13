#!/usr/bin/env perl
use strict;
use warnings;

# Non-core dependencies
use DBI qw(:sql_types);
use Digest::SHA qw(sha1_hex);

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yipupload.pl - Global resource upload administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipupload.pl

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles uploading global resources, which can either create new
global resources or overwrite existing ones.  The client must have an
authorization cookie to use this script.

The GET request will provide a form allowing the unique, six-digit ID of
the resource to be entered, the resource data type to be selected, and
the actual resource file to be uploaded.  The resource data type is a
multiple choice populated by the data types currently registered in the
database, with an error message displayed to user if there are no
currently registered data types.  The unique ID number must be six
digits beginning with a non-zero digit.  If no resource with that number
currently exists, a new global resource will be created.  Otherwise, an
existing resource will be overwritten.

This script is also the POST request target of the form it provides in
the GET request.  The POST request will read the uploaded resource and
update the database accordingly.

=cut

# =========
# Templates
# =========

# GET form template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   datatypes - array of recognized data types, each element containing
#   the properties "tname" "tmime" and "tcache" for the name, MIME type,
#   and cache value of the data type
#
# The form action POSTs back to this script in MIME format with file
# upload, with the following form variables:
#
#   uid - the unique ID for the resource
#   type - the data type name
#   upload - the uploaded file
#
my $get_template = Yip::Admin->format_html('Upload global resource', q{
    <h1>Upload global resource</h1>
    <div id="homelink"><a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Back
      &laquo;</a></div>
    <form
        action="<TMPL_VAR NAME=_pathupload>"
        method="post"
        enctype="multipart/form-data">
      <div class="ctlbox">
        <div>Global resource ID (######):</div>
        <div>
          <input
            type="text"
            name="uid"
            class="txbox"
            spellcheck="false">
        </div>
      </div>
      <div class="ctlbox">
        <div>Resource data type:</div>
        <div>
          <select name="type" class="slbox">
            <option value="" selected>--Select data type--</option>
<TMPL_LOOP NAME=datatypes>
            <option
              value="<TMPL_VAR NAME=tname>">
              <TMPL_VAR NAME=tname>
              (<TMPL_VAR NAME=tmime ESCAPE=HTML>)
              cache=<TMPL_VAR NAME=tcache>
            </option>
</TMPL_LOOP>
          </select>
        </div>
      </div>
      <div>&nbsp;</div>
      <div class="ctlbox">
        <div>Select file to upload:</div>
        <div>
          <input type="file" name="upload">
        </div>
      </div>
      <div>&nbsp;</div>
      <div class="btnbox">
        <input type="submit" value="Upload" class="btn">
      </div>
    </form>
});

# POST success template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
my $done_template = Yip::Admin->format_html('Upload global resource', q{
    <h1>Upload global resource</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Home &laquo;</a>
    </div>
    <p>Upload operation successful.</p>
});

# POST error template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   reason - an error message to show the user
#
my $err_template = Yip::Admin->format_html('Upload global resource', q{
    <h1>Upload global resource</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Home &laquo;</a>
    </div>
    <p>Upload operation failed: <TMPL_VAR NAME=reason ESCAPE=HTML>!</p>
});

# ===============
# Local functions
# ===============

# send_error(yap, errmsg)
#
# Send the custom error template back to the client, indicating that the
# operation failed.  The provided error message will be included in the
# error page.  May also be used by the GET page in certain cases.
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

# Get normalized method
#
my $request_method = Yip::Admin->http_method;

# Handle the different methods
#
if ($request_method eq 'GET') { # ======================================
  # GET method so start by connecting to database and loading admin
  # utilities
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $yap = Yip::Admin->load($dbc);
  
  # Check that client is authorized
  $yap->checkCookie;
  
  # Get all the data types
  my $dbh = $dbc->beginWork('r');
  my $qr = $dbh->selectall_arrayref(
              'SELECT rtypename, rtypemime, rtypecache '
              . 'FROM rtype ORDER BY rtypename ASC');
  ((ref($qr) eq 'ARRAY') and (scalar(@$qr) > 0)) or
    send_error($yap, 'No data types are currently defined');
  
  my @dta;
  for my $tr (@$qr) {
    push @dta, ({
                  tname  => $tr->[0],
                  tmime  => $tr->[1],
                  tcache => $tr->[2]
                });
  }
  
  $dbc->finishWork;
  
  # Set custom parameters
  $yap->customParam('datatypes' , \@dta);
  
  # Send the form template to client
  $yap->sendTemplate($get_template);
  
} elsif ($request_method eq 'POST') { # ================================
  # POST method so start by connecting to database and loading admin
  # utilities
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $yap = Yip::Admin->load($dbc);
  
  # Check that client is authorized
  $yap->checkCookie;
  
  # Read all the POSTed form uploads
  Yip::Admin->check_upload;
  my $vars = Yip::Admin->parse_upload(Yip::Admin->read_client);
  
  # Check that we got the three required fields and get them
  ((exists $vars->{'uid'}) and (exists $vars->{'type'}) and
      (exists $vars->{'upload'})) or
    Yip::Admin->bad_request;
  
  my $uid    = $vars->{'uid'};
  my $rtype  = $vars->{'type'};
  my $upload = $vars->{'upload'};
  
  # Trim type and make sure it was selected
  $rtype =~ s/\A[ \t]+//;
  $rtype =~ s/[ \t]+\z//;
  (length($rtype) > 0) or
    send_error($yap, 'Must select a data type');
  
  # Check that a file was uploaded
  (length($upload) > 0) or
    send_error($yap, 'Must upload a non-empty file');
  
  # Trim leading and trailing whitespace from UID, check it, and convert
  # to integer
  $uid =~ s/\A[ \t]+//;
  $uid =~ s/[ \t]+\z//;
  ($uid =~ /\A[1-9][0-9]{5}\z/) or
    send_error($yap, 'Invalid unique ID format');
  $uid = int($uid);
  
  # Compute SHA-1 hash in base16 lowercase
  my $dig = sha1_hex($upload);
  $dig =~ tr/A-Z/a-z/;
  
  # Start the update transaction
  my $dbh = $dbc->beginWork('rw');
  
  # Look up the foreign key for the data type
  my $rtk = $dbh->selectrow_arrayref(
                    'SELECT rtypeid FROM rtype WHERE rtypename=?',
                    undef,
                    $rtype);
  (ref($rtk) eq 'ARRAY') or
    send_error($yap, "Failed to find data type '$rtype' in database");
  $rtk = int($rtk->[0]);
  
  # Check whether the unique ID already exists to determine how to
  # update
  my $rowid = $dbh->selectrow_arrayref(
                      'SELECT gresid FROM gres WHERE gresuid=?',
                      undef,
                      $uid);
  if (ref($rowid) eq 'ARRAY') {
    # Global resource already exists, so get its rowid
    $rowid = int($rowid->[0]);
    
    # Update the record
    my $sth = $dbh->prepare(
                'UPDATE gres SET gresdig=?, rtypeid=?, gresraw=? '
                . 'WHERE gresid=?');
    $sth->bind_param(1, $dig);
    $sth->bind_param(2, $rtk);
    $sth->bind_param(3, $upload, SQL_BLOB);
    $sth->bind_param(4, $rowid);
    $sth->execute();
    
  } else {
    # Global resource doesn't already exist, so add it
    my $sth = $dbh->prepare(
                'INSERT INTO gres(gresuid, gresdig, rtypeid, gresraw) '
                . 'VALUES (?,?,?,?)');
    $sth->bind_param(1, $uid);
    $sth->bind_param(2, $dig);
    $sth->bind_param(3, $rtk);
    $sth->bind_param(4, $upload, SQL_BLOB);
    $sth->execute();
  }
  
  # Finish the update transaction
  $dbc->finishWork;
  
  # Send the done template
  $yap->sendTemplate($done_template);
  
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
