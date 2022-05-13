#!/usr/bin/env perl
use strict;
use warnings;

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yipdrop.pl - Entity drop administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipdrop.pl?type=example
  /cgi-bin/yipdrop.pl?var=example
  /cgi-bin/yipdrop.pl?template=example
  /cgi-bin/yipdrop.pl?archive=715932
  /cgi-bin/yipdrop.pl?global=175983
  /cgi-bin/yipdrop.pl?post=540015

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles dropping various kinds of entities from the database.
The client must have an authorization cookie to use this script.

The GET request takes a query-string variable whose name indicates the
type of entity being dropped and whose value identifies the specific
entity of that type to drop.  See the synopsis for the patterns.  The
GET request does not actually perform the drop.  Instead, it provides a
form that confirms the operation and submits to itself with a POST
request.

This script is also the POST request target of the form it provides in
the GET request.  The POST request will drop the indicated entity from
the database.

=cut

# =========
# Templates
# =========

# GET form template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   eclass - the entity class
#   eid - the entity identifier
#
# The form action POSTs back to this script, with the following form
# variables:
#
#   eclass - the entity class
#   eid - the entity identifier
#
my $get_template = Yip::Admin->format_html('Drop entity', q{
    <h1>Drop entity</h1>
    <div id="homelink"><a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Back
      &laquo;</a></div>
    <form
        action="<TMPL_VAR NAME=_pathdrop>"
        method="post"
        enctype="application/x-www-form-urlencoded">
      <div class="ctlbox">
        <div>Entity type:</div>
        <div>
          <input
            type="text"
            name="eclass"
            class="txbox"
            readonly
            value="<TMPL_VAR NAME=eclass>">
        </div>
      </div>
      <div class="ctlbox">
        <div>Entity ID:</div>
        <div>
          <input
            type="text"
            name="eid"
            class="txbox"
            readonly
            value="<TMPL_VAR NAME=eid>">
        </div>
      </div>
      <div>&nbsp;</div>
      <div class="btnbox">
        <input type="submit" value="Drop" class="btn">
      </div>
    </form>
});

# POST success template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
my $done_template = Yip::Admin->format_html('Drop entity', q{
    <h1>Drop entity</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Home &laquo;</a>
    </div>
    <p>Drop operation successful.</p>
});

# POST error template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   reason - an error message to show the user
#
my $err_template = Yip::Admin->format_html('Drop entity', q{
    <h1>Drop entity</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Home &laquo;</a>
    </div>
    <p>Drop operation failed: <TMPL_VAR NAME=reason ESCAPE=HTML>!</p>
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
  
  # Get query string
  my $qs = '';
  if (defined $ENV{'QUERY_STRING'}) {
    $qs = $ENV{'QUERY_STRING'};
  }
  
  # Parse query string
  my $vars = Yip::Admin->parse_form($qs);
  
  # Make sure exactly one of the recognized parameters was provided
  my $pcount = 0;
  for my $p ('type', 'var', 'template', 'archive', 'global', 'post') {
    if (exists $vars->{$p}) {
      $pcount++;
    }
  }
  ($pcount == 1) or send_error($yap, 'Invalid query string');
  
  # Get class and identifier based on the specific type
  my $eclass;
  my $eid;
  
  if (exists $vars->{'type'}) {
    $eclass = 'type';
    $eid = $vars->{'type'};
    ($eid =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      send_error($yap, 'Invalid data type name');
    
  } elsif (exists $vars->{'var'}) {
    $eclass = 'var';
    $eid = $vars->{'var'};
    ($eid =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      send_error($yap, 'Invalid variable name');
    $eid =~ tr/A-Z/a-z/;
    
  } elsif (exists $vars->{'template'}) {
    $eclass = 'template';
    $eid = $vars->{'template'};
    ($eid =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      send_error($yap, 'Invalid template name');
    
  } elsif (exists $vars->{'archive'}) {
    $eclass = 'archive';
    $eid = $vars->{'archive'};
    ($eid =~ /\A[1-9][0-9]{5}\z/) or
      send_error($yap, 'Invalid archive unique ID');
    $eid = int($eid);
    
  } elsif (exists $vars->{'global'}) {
    $eclass = 'global';
    $eid = $vars->{'global'};
    ($eid =~ /\A[1-9][0-9]{5}\z/) or
      send_error($yap, 'Invalid global resource unique ID');
    $eid = int($eid);
    
  } elsif (exists $vars->{'post'}) {
    $eclass = 'post';
    $eid = $vars->{'post'};
    ($eid =~ /\A[1-9][0-9]{5}\z/) or
      send_error($yap, 'Invalid post unique ID');
    $eid = int($eid);
    
  } else {
    die "Unexpected";
  }
  
  # Set custom parameters
  $yap->customParam('eclass', $eclass);
  $yap->customParam('eid'   , $eid);
  
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
  Yip::Admin->check_form;
  my $vars = Yip::Admin->parse_form(Yip::Admin->read_client);
  
  # Check that we got the two required fields and get them
  ((exists $vars->{'eclass'}) and (exists $vars->{'eid'})) or
    Yip::Admin->bad_request;
  
  my $eclass = $vars->{'eclass'};
  my $eid    = $vars->{'eid'};
  
  # Handle the different classes
  if ($eclass eq 'type') { # ===========================================
    # Check eid format
    ($eid =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      send_error($yap, 'Invalid data type name');
    
    # Begin transaction
    my $dbh = $dbc->beginWork('rw');
    
    # Determine the rtypeid
    my $rtypeid = $dbh->selectrow_arrayref(
                      'SELECT rtypeid FROM rtype WHERE rtypename=?',
                      undef,
                      $eid);
    (ref($rtypeid) eq 'ARRAY') or
      send_error($yap, "Did not find a data type named '$eid'");
    $rtypeid = $rtypeid->[0];
    
    # Check that no global resources or post attachments currently use
    # the indicated data type
    my $qr = $dbh->selectrow_arrayref(
                    'SELECT gresid FROM gres WHERE rtypeid=?',
                    undef,
                    $rtypeid);
    (not (ref($qr) eq 'ARRAY')) or
      send_error($yap, 'Data type still in use in gres');
    
    $qr = $dbh->selectrow_arrayref(
                    'SELECT attid FROM att WHERE rtypeid=?',
                    undef,
                    $rtypeid);
    (not (ref($qr) eq 'ARRAY')) or
      send_error($yap, 'Data type still in use in att');
    
    # Drop the data type record
    $dbh->do('DELETE FROM rtype WHERE rtypeid=?', undef, $rtypeid);
    
    # End transaction
    $dbc->finishWork;
    
  } elsif ($eclass eq 'var') { # =======================================
    # Check eid format
    ($eid =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      send_error($yap, 'Invalid variable name');
    $eid =~ tr/A-Z/a-z/;
    
    # Begin transaction
    my $dbh = $dbc->beginWork('rw');
    
    # Determine the varsid
    my $varsid = $dbh->selectrow_arrayref(
                      'SELECT varsid FROM vars WHERE varskey=?',
                      undef,
                      $eid);
    (ref($varsid) eq 'ARRAY') or
      send_error($yap, "Did not find a variable named '$eid'");
    $varsid = $varsid->[0];
    
    # Drop the variable
    $dbh->do('DELETE FROM vars WHERE varsid=?', undef, $varsid);
    
    # End transaction
    $dbc->finishWork;
    
  } elsif ($eclass eq 'template') { # ==================================
    # Check eid format
    ($eid =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      send_error($yap, 'Invalid template name');
    
    # Begin transaction
    my $dbh = $dbc->beginWork('rw');
    
    # Determine the tmplid
    my $tmplid = $dbh->selectrow_arrayref(
                      'SELECT tmplid FROM tmpl WHERE tmplname=?',
                      undef,
                      $eid);
    (ref($tmplid) eq 'ARRAY') or
      send_error($yap, "Did not find a template named '$eid'");
    $tmplid = $tmplid->[0];
    
    # Drop the template
    $dbh->do('DELETE FROM tmpl WHERE tmplid=?', undef, $tmplid);
    
    # End transaction
    $dbc->finishWork;
    
  } elsif ($eclass eq 'archive') { # ===================================
    # Check eid format
    ($eid =~ /\A[1-9][0-9]{5}\z/) or
      send_error($yap, 'Invalid archive unique ID');
    $eid = int($eid);
    
    # Begin transaction
    my $dbh = $dbc->beginWork('rw');
    
    # Determine the parcid
    my $parcid = $dbh->selectrow_arrayref(
                      'SELECT parcid FROM parc WHERE parcuid=?',
                      undef,
                      $eid);
    (ref($parcid) eq 'ARRAY') or
      send_error($yap, "Did not find an archive with UID '$eid'");
    $parcid = $parcid->[0];
    
    # Drop the archive
    $dbh->do('DELETE FROM parc WHERE parcid=?', undef, $parcid);
    
    # End transaction
    $dbc->finishWork;
    
  } elsif ($eclass eq 'global') { # ====================================
    # Check eid format
    ($eid =~ /\A[1-9][0-9]{5}\z/) or
      send_error($yap, 'Invalid global resource unique ID');
    $eid = int($eid);
    
    # Begin transaction
    my $dbh = $dbc->beginWork('rw');
    
    # Determine the gresid
    my $gresid = $dbh->selectrow_arrayref(
                      'SELECT gresid FROM gres WHERE gresuid=?',
                      undef,
                      $eid);
    (ref($gresid) eq 'ARRAY') or
      send_error($yap,
        "Did not find a global resource with UID '$eid'");
    $gresid = $gresid->[0];
    
    # Drop the global resource
    $dbh->do('DELETE FROM gres WHERE gresid=?', undef, $gresid);
    
    # End transaction
    $dbc->finishWork;
    
  } elsif ($eclass eq 'post') { # ======================================
    # Check eid format
    ($eid =~ /\A[1-9][0-9]{5}\z/) or
      send_error($yap, 'Invalid post unique ID');
    $eid = int($eid);
    
    # Begin transaction
    my $dbh = $dbc->beginWork('rw');
    
    # Determine the postid
    my $postid = $dbh->selectrow_arrayref(
                      'SELECT postid FROM post WHERE postuid=?',
                      undef,
                      $eid);
    (ref($postid) eq 'ARRAY') or
      send_error($yap,
        "Did not find a post with UID '$eid'");
    $postid = $postid->[0];
    
    # Drop all attachments to that post first
    $dbh->do('DELETE FROM att WHERE postid=?', undef, $postid);
    
    # Second, drop the post record itself
    $dbh->do('DELETE FROM post WHERE postid=?', undef, $postid);
    
    # End transaction
    $dbc->finishWork;
    
  } else { # ===========================================================
    die "Unexpected";
  }
  
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
