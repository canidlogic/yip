#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode encode);

# Non-core dependencies
use Date::Calc qw(check_date Add_Delta_Days Date_to_Days);
use JSON::Tiny qw(decode_json encode_json);

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yipedit.pl - Editor administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipedit.pl?class=types
  /cgi-bin/yipedit.pl?class=vars
  /cgi-bin/yipedit.pl?class=archives
  /cgi-bin/yipedit.pl?template=example

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles editing data types, template variables, archives, and
individual templates.  The client must have an authorization cookie to
use this script.

The GET request to this script must either have a C<class> variable or
a C<template> variable in the query string.  If there is a C<class>
variable, then it must have a value of either C<types> C<vars> or
C<archives>, indicating what class of data to edit.  If there is a
C<template> variable, then its value is the name of the template to
edit, which must be a string of one to 31 ASCII alphanumerics and
underscores.  The template need not currently exist.

The GET request will provide a form containing a text field where you
can edit data and a hidden form field that stores what is being edited.
The following subsections will define exactly what data is edited in
each of the cases.

This script is also the POST request target of the form it provides in
the GET request.  The POST request will read the edited data and update
the database accordingly.  For C<class> edits, all properties that are
defined within the edited JSON object will either be added or
overwritten.  For C<template> edits, either an existing template is
changed or a new template is created.  This script never deletes records
from the database.  It is only able to add new records and edit existing
ones.

=head2 Data type editing

When C<class=types> is the parameter, then the edited data with will be
a text file containing JSON.  The top-level JSON entity is an object.
Properties of this JSON object have property names corresponding to data
types defined in the C<rtype> table.  The values of each property are
JSON arrays of two elements, the first being a string holding the MIME
type for the data type, and the second being an integer storing the
cache handling code.  See the description of the C<rtype> table in the
C<createdb.pl> script for further details.

Note that deleting properties from the JSON object and then submitting
the edited JSON will B<not> delete the corresponding data types.  This
script is only able to add new data types or edit existing ones.

=head2 Template variable editing

When C<class=vars> is the parameter, then the edited data with will be
a text file containing JSON.  The top-level JSON entity is an object.
Properties of this JSON object have property names corresponding to
template variables defined in the C<vars> table.  The values of each
property are strings holding the value to set for the variable.  See the
description of the C<vars> table in the C<createdb.pl> script for
further details.

Note that deleting properties from the JSON object and then submitting
the edited JSON will B<not> delete the corresponding template variables.
This script is only able to add new variables or edit existing ones.

=head2 Archive editing

When C<class=archives> is the parameter, then the edited data with will
be a text file containing JSON.  The top-level JSON entity is an object.
Properties of this JSON object have property names that are strings of
exactly six decimal digits indicating the UID of the archive represented
by the property.  The values of each property are JSON arrays of two
elements, the first being a string holding the display name of the
archive and the second being a timecode in C<yyyy-mm-ddThh:mm:ss> format
stored in a string indicating the lastest post date stored in the
archive. See the description of the C<parc> table in the C<createdb.pl>
script for further details.

Note that deleting properties from the JSON object and then submitting
the edited JSON will B<not> delete the corresponding archive.  This
script is only able to add new archives or edit existing ones.

=head2 Template editing

When C<template=example> is the parameter, then the edited data will be
the text contents of the named template.  If no template with the given
name currently exists, the editor will start out blank.  There is also
a cache control field that determines caching behavior.  If set to -1,
then clients should never cache pages generated by this template
(C<no-store> semantics).  If set to 0, then clients can cache pages, but
the cached pages are immediately stale (C<no-cache> semantics).  If set
to a positive integer in range [1, 31536000], specifies the number of
seconds that cached pages remain fresh.

=cut

# =========
# Templates
# =========

# GET form template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   modet - set to 1 if editing a template, 0 otherwise
#   modec - set to 1 if editing a class, 0 otherwise
#
#   tname - initial value for template name (if modet)
#   tcache - initial value for cache value (if modet)
#
#   cname - name of class being edited (if modec)
#
#   itext - initial value of editor control
#
# The form action POSTs back to this script, with the following form
# variables:
#
#   template - name of the template to edit (if modet)
#   cache - cache value for the template (if modet)
#   class - name of class being edited (if modec)
#   text - the edited text
#
my $get_template = Yip::Admin->format_html('Editor', q{
    <h1>Editor</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    <form
        action="<TMPL_VAR NAME=_pathedit>"
        method="post"
        enctype="application/x-www-form-urlencoded">
<TMPL_IF NAME=modet>
      <div class="ctlbox">
        <div>Editing template:</div>
        <div>
          <input
            type="text"
            name="template"
            class="txbox"
            spellcheck="false"
            value="<TMPL_VAR NAME=tname>">
        </div>
      </div>
      <div class="ctlbox">
        <div>Cache age (seconds) or 0 for no-cache or -1 for
          no-store:</div>
        <div>
          <input
            type="number"
            name="cache"
            class="txbox"
            min="-1"
            max="31536000"
            value="<TMPL_VAR NAME=tcache>">
        </div>
      </div>
</TMPL_IF>
<TMPL_IF NAME=modec>
      <div class="ctlbox">
        <div>Editing class:</div>
        <div>
          <input
            type="text"
            name="class"
            class="txbox"
            readonly
            value="<TMPL_VAR NAME=cname>">
        </div>
      </div>
</TMPL_IF>
      <div class="ctlbox">
        <div>Editor:</div>
        <div>
<textarea name="text" spellcheck="false">
<TMPL_VAR NAME=itext ESCAPE=HTML></textarea>
        </div>
      </div>
      <div>&nbsp;</div>
      <div class="btnbox">
        <input type="submit" value="Submit" class="btn">
      </div>
    </form>
});

# POST success template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
my $done_template = Yip::Admin->format_html('Editor', q{
    <h1>Editor</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    <p>Edit operation successful.</p>
});

# POST error template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   reason - an error message to show the user
#
my $err_template = Yip::Admin->format_html('Editor', q{
    <h1>Editor</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    <p>Edit operation failed: <TMPL_VAR NAME=reason ESCAPE=HTML>!</p>
});

# ===============
# Local functions
# ===============

# send_error(yap, errmsg)
#
# Send the custom error template back to the client, indicating that the
# edit operation failed.  The provided error message will be included in
# the error page.  May also be used by the GET page in certain cases.
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

# valid_mime(str)
#
# Check whether the given string is a valid MIME content-type.
#
sub valid_mime {
  # Check parameter count
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  # Get parameter and check
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  $str = "$str";
  
  # First of all, check that everything is printing US-ASCII
  ($str =~ /\A[\x{20}-\x{7e}]*\z/) or return 0;
  
  # Second of all, replace all quoted strings with U+001A SUB
  $str =~ s/"[^"]*"/\x{1a}/g;
  
  # After quoted string replacement, no quotes should remain
  (not ($str =~ /"/)) or return 0;
  
  # Now that quoted strings have been collapsed, make sure that the last
  # character is not a semicolon and that semicolon never occurs before
  # anything other than a space
  (not ($str =~ /;\z/)) or return 0;
  (not ($str =~ /;[^ ]/)) or return 0;
  
  # Semicolon only occurs before space, so split string into a main type
  # followed by zero or more parameter declarations
  my @ta = split /; /, $str;
  
  # Check each parameter
  for(my $i = 1; $i <= $#ta; $i++) {
    my $ps = $ta[$i];
    
    ($ps =~ /\A([^=]+)=([^=]+)\z/) or return 0;
    my $a = $1;
    my $b = $2;
    
    ($a =~ /\A[^ \(\)<>@,;:\\\"\/\[\]\?\=A-Z]+\z/) or return 0;
    (($b eq "\x{1a}") or
      ($b =~ /\A[^ \(\)<>@,;:\\\"\/\[\]\?\=]+\z/)) or return 0;
  }
  
  # Check the main type
  my $mt = $ta[0];
  
  ($mt =~ /\A([^\/]+)\/([^\/]+)\z/) or return 0;
  my $c = $1;
  my $d = $2;
  
  ($c =~ /\A[^ \(\)<>@,;:\\\"\/\[\]\?\=A-Z]+\z/) or return 0;
  ($d =~ /\A[^ \(\)<>@,;:\\\"\/\[\]\?\=A-Z]+\z/) or return 0;
  
  # If we got here, the MIME type is valid
  return 1;
}

# decode_time(time, epoch)
#
# Decode an integer time value from the database into a standard
# datetime string.
#
# time is the time value to decode and epoch is the epoch value from the
# database cvars table.
#
# Returns a string in yyyy-mm-ddThh:mm:ss format.
#
sub decode_time {
  # Check parameter count
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  # Get parameters and check
  my $ti = shift;
  my $ep = shift;
  
  ((not ref($ti)) and (not ref($ep))) or
    die "Wrong parameter type, stopped";
  ((int($ti) == $ti) and (int($ep) == $ep)) or
    die "Wrong parameter type, stopped";
  
  $ti = int($ti);
  $ep = int($ep);
  
  # Get number of seconds since Unix epoch
  $ti = $ti + $ep;
  ($ti >= 0) or die "Time value out of range, stopped";
  
  # Divide into day count and remaining time value
  my $dc = int($ti / 86400);
  $ti = $ti - ($dc * 86400);
  
  # Get date from day count
  my ($year, $month, $day) = Add_Delta_Days(1970, 1, 1, $dc);
  (($year >= 1970) and ($year <= 4999)) or
    die "Time value out of range, stopped";
  
  # Break remaining time value into hours minutes seconds
  my $hr = int($ti / 3600);
  $ti = $ti % 3600;
  my $mn = int($ti / 60);
  my $sc = $ti % 60;
  
  # Return formatted datetime string
  return sprintf("%04d-%02d-%02dT%02d:%02d:%02d",
                  $year, $month, $day,
                  $hr,   $mn,    $sc);
}

# encode_time(str, epoch)
#
# Encode a string in yyyy-mm-ddThh:mm:ss format into an integer time
# value for the database according to a given epoch.
#
# epoch is the epoch value from the database cvars table.
#
# Returns an integer.  Assumes the string has already been checked, and
# causes fatal errors if there are any problems.
#
sub encode_time {
  # Check parameter count
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  # Get parameters and check
  my $str = shift;
  my $ep  = shift;
  
  ((not ref($str)) and (not ref($ep))) or
    die "Wrong parameter type, stopped";
  (int($ep) == $ep) or
    die "Wrong parameter type, stopped";
  
  $str = "$str";
  $ep  = int($ep);
  
  # Parse the string
  ($str =~ /\A
            ([0-9]{4})
              \-
            ([0-9]{2})
              \-
            ([0-9]{2})
              T
            ([0-9]{2})
              :
            ([0-9]{2})
              :
            ([0-9]{2})
          \z/x) or
    die "Invalid datetime string";
  
  my $year  = int($1);
  my $month = int($2);
  my $day   = int($3);
  my $hr    = int($4);
  my $mn    = int($5);
  my $sc    = int($6);
  
  # Range-check fields
  (($year >= 1970) and ($year <= 4999)) or
    die "Year out of range";
  (($month >= 1) and ($month <= 12)) or
    die "Month out of range";
  (($day >= 1) and ($day <= 31)) or
    die "Day out of range";
  (($hr >= 0) and ($hr <= 23)) or
    die "Hour out of range";
  (($mn >= 0) and ($mn <= 59)) or
    die "Minute out of range";
  (($sc >= 0) and ($sc <= 59)) or
    die "Second out of range";
  (check_date($year, $month, $day)) or
    die "Date is invalid";
  
  # Get number of days since Unix epoch
  my $dc = Date_to_Days($year, $month, $day) - Date_to_Days(1970, 1, 1);
  
  # Compute the seconds since Unix epoch
  my $tv = ($dc * 86400)
              + ($hr * 3600)
              + ($mn * 60)
              + $sc;
  
  # Adjust by epoch
  $tv = $tv - $ep;
  
  # Return value
  return $tv;
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
  
  # Get the query string
  my $qs = '';
  if (defined $ENV{'QUERY_STRING'}) {
    $qs = $ENV{'QUERY_STRING'};
  }
  
  # Parse the query string
  my $vars = Yip::Admin->parse_form($qs);
  
  # Make sure we don't have both class and template variables at same
  # time
  (not ((exists $vars->{'class'}) and (exists $vars->{'template'}))) or
    send_error($yap, "Can't edit both class and template at same time");
  
  # Make sure we have either class or template variable
  ((exists $vars->{'class'}) or (exists $vars->{'template'})) or
    send_error($yap, "Must provide class or template query parameter");
  
  # Handle the different cases
  if (exists $vars->{'template'}) { # ----------------------------------
    # Update backlink
    $yap->setBacklink($yap->getVar('pathlist') . '?report=templates');
    
    # Get template name and check it
    my $tname = "$vars->{'template'}";
    ($tname =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      send_error($yap, 'Template name must be 1 to 31 ASCII '
                        . 'alphanumerics and underscores');
    
    # Set default values which are used if template doesn't exist
    my $tcache = 0;
    my $tcode  = '';
    
    # Look up the template, which may or may not already exist, and set
    # default values if the template exists
    my $dbh = $dbc->beginWork('r');
    my $tq = $dbh->selectrow_arrayref(
                'SELECT tmplcache, tmplcode FROM tmpl WHERE tmplname=?',
                undef,
                $tname);
    if (ref($tq) eq 'ARRAY') {
      $tcache = int($tq->[0]);
      $tcode  = decode('UTF-8', $tq->[1],
                  Encode::FB_CROAK | Encode::LEAVE_SRC);
    }
    
    $dbc->finishWork;
    
    # Set custom parameters
    $yap->customParam('modet' , 1);
    $yap->customParam('modec' , 0);
    $yap->customParam('tname' , $tname);
    $yap->customParam('tcache', $tcache);
    $yap->customParam('cname' , '');
    $yap->customParam('itext' , $tcode);
    
    # Send the form template to client
    $yap->sendTemplate($get_template);
    
  } elsif ($vars->{'class'} eq 'types') { # ----------------------------
    # Update backlink
    $yap->setBacklink($yap->getVar('pathlist') . '?report=types');
    
    # Query all data types
    my $dbh = $dbc->beginWork('r');
    my $qr = $dbh->selectall_arrayref(
                'SELECT rtypename, rtypemime, rtypecache '
                . 'FROM rtype ORDER BY rtypename ASC');
    
    # Begin building the JSON text
    my $json = "{\n";
    my $first_rec = 1;
    
    # Add each data type record
    if (ref($qr) eq 'ARRAY') {
      for my $r (@$qr) {
        my $name  = encode_json "$r->[0]";
        my $mime  = encode_json "$r->[1]";
        my $cache = int($r->[2]);
        
        if ($first_rec) {
          $first_rec = 0;
        } else {
          $json = $json . ",\n";
        }
        
        $json = $json . "  $name: [$mime, $cache]"
      }
    }
    
    # Finish building the JSON text
    $json = $json . "\n}\n";
    
    # Finish database work
    $dbc->finishWork;
    
    # Set custom parameters
    $yap->customParam('modet' , 0);
    $yap->customParam('modec' , 1);
    $yap->customParam('tname' , '');
    $yap->customParam('tcache', '');
    $yap->customParam('cname' , 'types');
    $yap->customParam('itext' , $json);
    
    # Send the form template to client
    $yap->sendTemplate($get_template);
    
  } elsif ($vars->{'class'} eq 'vars') { # -----------------------------
    # Update backlink
    $yap->setBacklink($yap->getVar('pathlist') . '?report=vars');
    
    # Query all template variables
    my $dbh = $dbc->beginWork('r');
    my $qr = $dbh->selectall_arrayref(
                'SELECT varskey, varsval '
                . 'FROM vars ORDER BY varskey ASC');
    
    # Begin building the JSON text
    my $json = "{\n";
    my $first_rec = 1;
    
    # Add each data type record
    if (ref($qr) eq 'ARRAY') {
      for my $r (@$qr) {
        my $key = encode_json "$r->[0]";
        my $val = encode_json(
                    decode('UTF-8', "$r->[1]",
                      Encode::FB_CROAK | Encode::LEAVE_SRC)
                  );
        
        if ($first_rec) {
          $first_rec = 0;
        } else {
          $json = $json . ",\n";
        }
        
        $json = $json . "  $key: $val"
      }
    }
    
    # Finish building the JSON text
    $json = $json . "\n}\n";
    
    # Finish database work
    $dbc->finishWork;
    
    # Set custom parameters
    $yap->customParam('modet' , 0);
    $yap->customParam('modec' , 1);
    $yap->customParam('tname' , '');
    $yap->customParam('tcache', '');
    $yap->customParam('cname' , 'vars');
    $yap->customParam('itext' , $json);
    
    # Send the form template to client
    $yap->sendTemplate($get_template);
    
  } elsif ($vars->{'class'} eq 'archives') { # -------------------------
    # Update backlink
    $yap->setBacklink($yap->getVar('pathlist') . '?report=archives');
    
    # Query all template variables
    my $dbh = $dbc->beginWork('r');
    my $qr = $dbh->selectall_arrayref(
                'SELECT parcuid, parcname, parcuntil '
                . 'FROM parc ORDER BY parcuntil DESC');
    
    # Begin building the JSON text
    my $json = "{\n";
    my $first_rec = 1;
    
    # Add each data type record
    if (ref($qr) eq 'ARRAY') {
      for my $r (@$qr) {
        my $uid  = encode_json "$r->[0]";
        my $name = encode_json(
                      decode('UTF-8', "$r->[1]",
                        Encode::FB_CROAK | Encode::LEAVE_SRC)
                    );
        my $tval = encode_json(
                      decode_time($r->[2], $yap->getVar('epoch'))
                    );
        
        if ($first_rec) {
          $first_rec = 0;
        } else {
          $json = $json . ",\n";
        }
        
        $json = $json . "  $uid: [$name, $tval]"
      }
    }
    
    # Finish building the JSON text
    $json = $json . "\n}\n";
    
    # Finish database work
    $dbc->finishWork;
    
    # Set custom parameters
    $yap->customParam('modet' , 0);
    $yap->customParam('modec' , 1);
    $yap->customParam('tname' , '');
    $yap->customParam('tcache', '');
    $yap->customParam('cname' , 'archives');
    $yap->customParam('itext' , $json);
    
    # Send the form template to client
    $yap->sendTemplate($get_template);
    
  } else { # -----------------------------------------------------------
    send_error($yap, "Unrecognized class name");
  }
  
} elsif ($request_method eq 'POST') { # ================================
  # POST method so start by connecting to database and loading admin
  # utilities
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $yap = Yip::Admin->load($dbc);
  
  # Check that client is authorized
  $yap->checkCookie;
  
  # Read all the POSTed form variables
  Yip::Admin->check_form;
  my $vars = Yip::Admin->parse_form(Yip::Admin->read_client);
  
  # Make sure we don't have both class and template variables at same
  # time
  (not ((exists $vars->{'class'}) and (exists $vars->{'template'}))) or
    Yip::Admin->bad_request;
  
  # Make sure we have either class or template variable
  ((exists $vars->{'class'}) or (exists $vars->{'template'})) or
    Yip::Admin->bad_request;
  
  # If we have template variable, make sure we have cache variable
  if (exists $vars->{'template'}) {
    (exists $vars->{'cache'}) or Yip::Admin->bad_request;
  }
  
  # Make sure we have text variable
  (exists $vars->{'text'}) or Yip::Admin->bad_request;
  
  # Update backlink
  if (exists $vars->{'template'}) {
    $yap->setBacklink($yap->getVar('pathlist') . '?report=templates');
  } elsif ($vars->{'class'} eq 'types') {
    $yap->setBacklink($yap->getVar('pathlist') . '?report=types');
  } elsif ($vars->{'class'} eq 'vars') {
    $yap->setBacklink($yap->getVar('pathlist') . '?report=vars');
  } elsif ($vars->{'class'} eq 'archives') {
    $yap->setBacklink($yap->getVar('pathlist') . '?report=archives');
  } else {
    die "Unexpected";
  }
  
  # If we are editing a class, parse the text as JSON; else, leave the
  # JSON variable undefined
  my $json;
  if (exists $vars->{'class'}) {
    eval {
      $json = encode('UTF-8', $vars->{'text'},
                Encode::FB_CROAK | Encode::LEAVE_SRC);
      $json = decode_json($json);
    };
    if ($@) {
      send_error($yap, "Failed to parse JSON: \"$@\"");
    }
  }
  
  # Handle the different cases
  if (exists $vars->{'template'}) { # ----------------------------------
    # Get template name and check it
    my $tname = "$vars->{'template'}";
    ($tname =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      send_error($yap, 'Template name must be 1 to 31 ASCII '
                        . 'alphanumerics and underscores');
    
    # Get cache setting and check it
    my $tcache = "$vars->{'cache'}";
    if ($tcache eq '-1') {
      $tcache = -1;
    } elsif ($tcache =~ /\A[\+\-]?0+\z/) {
      $tcache = 0;
    } elsif ($tcache =~ /\A\+?0*[1-9][0-9]{0,8}\z/) {
      $tcache = int($tcache);
    } else {
      send_error($yap, 'Template cache setting is invalid');
    }
    (($tcache >= -1) and ($tcache <= 31536000)) or
      send_error($yap, 'Template cache setting is out of range');
    
    # Get template text and encode into UTF-8
    my $ttext = "$vars->{'text'}";
    $ttext = encode('UTF-8', $ttext,
                Encode::FB_CROAK | Encode::LEAVE_SRC);
    
    # Open work block to update database
    my $dbh = $dbc->beginWork('rw');
    
    # Check whether template by that name already exists
    my $qr = $dbh->selectrow_arrayref(
                    'SELECT tmplid FROM tmpl WHERE tmplname=?',
                    undef,
                    $tname);
    if (ref($qr) eq 'ARRAY') {
      # Template already exists so we need to update it
      $dbh->do(
              'UPDATE tmpl SET tmplcache=?, tmplcode=? '
              . 'WHERE tmplname=?',
              undef,
              $tcache, $ttext, $tname);
      
    } else {
      # Template does not already exist so we need to insert it
      $dbh->do(
              'INSERT INTO tmpl(tmplname, tmplcache, tmplcode) '
              . 'VALUES (?,?,?)',
              undef,
              $tname, $tcache, $ttext);
    }
    
    # Finish work block and send done template
    $dbc->finishWork;
    $yap->sendTemplate($done_template);
    
  } elsif ($vars->{'class'} eq 'types') { # ----------------------------
    # Check that top-level JSON entity is JSON object
    (ref($json) eq 'HASH') or
      send_error($yap, 'JSON entity must be an object');
    
    # Go through and check all properties
    for my $pname (keys %$json) {
      # Check name is valid type name
      ($pname =~ /\A[A-Za-z0-9_]{1,31}\z/) or
        send_error($yap, "Data type '$pname' has invalid name");
      
      # Check that value is array reference with two scalar elements
      (ref($json->{$pname}) eq 'ARRAY') or
        send_error($yap, "Data type '$pname' needs array value");
      (scalar(@{$json->{$pname}}) == 2) or
        send_error($yap, "Data type '$pname' needs two elements");
      ((not ref($json->{$pname}->[0])) and
          (not ref($json->{$pname}->[1]))) or
        send_error($yap, "Data type '$pname' needs scalar elements");
      
      # Check MIME property
      (valid_mime($json->{$pname}->[0])) or
        send_error($yap, "Data type '$pname' has invalid MIME type");
      
      # Get cache setting and check it
      my $tcache = "$json->{$pname}->[1]";
      if ($tcache eq '-1') {
        $tcache = -1;
      } elsif ($tcache =~ /\A[\+\-]?0+\z/) {
        $tcache = 0;
      } elsif ($tcache =~ /\A\+?0*[1-9][0-9]{0,8}\z/) {
        $tcache = int($tcache);
      } else {
        send_error($yap, "Data type '$pname' has invalid cache age");
      }
      (($tcache >= -1) and ($tcache <= 31536000)) or
        send_error($yap, "Data type '$pname' has invalid cache age");
      $json->{$pname}->[1] = $tcache;
    }
    
    # Open work block to update database
    my $dbh = $dbc->beginWork('rw');
    
    for my $pname (keys %$json) {
      # Check whether data type already defined
      my $qr = $dbh->selectrow_arrayref(
                'SELECT rtypeid FROM rtype WHERE rtypename=?',
                undef,
                $pname);
      if (ref($qr) eq 'ARRAY') {
        # Data type already defined, so update it
        $dbh->do(
                'UPDATE rtype SET rtypemime=?, rtypecache=? '
                . 'WHERE rtypename=?',
                undef,
                $json->{$pname}->[0],
                $json->{$pname}->[1],
                $pname);
        
      } else {
        # Data type not defined yet, so insert it
        $dbh->do(
                'INSERT INTO rtype(rtypename, rtypemime, rtypecache) '
                . 'VALUES (?,?,?)',
                undef,
                $pname,
                $json->{$pname}->[0],
                $json->{$pname}->[1]);
      }
    }
    
    # Finish work block and send done template
    $dbc->finishWork;
    $yap->sendTemplate($done_template);
  
  } elsif ($vars->{'class'} eq 'vars') { # -----------------------------
    # Check that top-level JSON entity is JSON object
    (ref($json) eq 'HASH') or
      send_error($yap, 'JSON entity must be an object');
    
    # Go through and check all properties
    for my $pname (keys %$json) {
      # Check name is valid template variable name
      ($pname =~ /\A[A-Za-z0-9_]{1,31}\z/) or
        send_error($yap, "Variable '$pname' has invalid name");
      (not ($pname =~ /[A-Z]/)) or
        send_error($yap, "Variable name '$pname' must be lowercase");
      
      # Check that value is scalar
      (not ref($json->{$pname})) or
        send_error($yap, "Variable '$pname' needs scalar value");
    }
    
    # Open work block to update database
    my $dbh = $dbc->beginWork('rw');
    
    for my $pname (keys %$json) {
      # Check whether template variable already defined
      my $qr = $dbh->selectrow_arrayref(
                'SELECT varsid FROM vars WHERE varskey=?',
                undef,
                $pname);
      if (ref($qr) eq 'ARRAY') {
        # Variable already defined, so update it
        $dbh->do(
                'UPDATE vars SET varsval=? WHERE varskey=?',
                undef,
                encode('UTF-8', $json->{$pname},
                    Encode::FB_CROAK | Encode::LEAVE_SRC),
                $pname);
        
      } else {
        # Variable not defined yet, so insert it
        $dbh->do(
                'INSERT INTO vars(varskey, varsval) VALUES (?,?)',
                undef,
                $pname,
                encode('UTF-8', $json->{$pname},
                    Encode::FB_CROAK | Encode::LEAVE_SRC));
      }
    }
    
    # Finish work block and send done template
    $dbc->finishWork;
    $yap->sendTemplate($done_template);
  
  } elsif ($vars->{'class'} eq 'archives') { # -------------------------
    # Check that top-level JSON entity is JSON object
    (ref($json) eq 'HASH') or
      send_error($yap, 'JSON entity must be an object');
    
    # Go through and check all properties
    for my $pname (keys %$json) {
      # Check name is valid UID
      ($pname =~ /\A[1-9][0-9]{5}\z/) or
        send_error($yap, "Archive '$pname' has invalid UID");
      
      # Check that value is array reference with two scalar elements
      (ref($json->{$pname}) eq 'ARRAY') or
        send_error($yap, "Archive '$pname' needs array value");
      (scalar(@{$json->{$pname}}) == 2) or
        send_error($yap, "Archive '$pname' needs two elements");
      ((not ref($json->{$pname}->[0])) and
          (not ref($json->{$pname}->[1]))) or
        send_error($yap, "Archive '$pname' needs scalar elements");
      
      # Get timestamp and check it
      my $ts = "$json->{$pname}->[1]";
      ($ts =~ /\A
                ([0-9]{4})
                  \-
                ([0-9]{2})
                  \-
                ([0-9]{2})
                  T
                ([0-9]{2})
                  :
                ([0-9]{2})
                  :
                ([0-9]{2})
              \z/x) or
        send_error($yap, "Archive '$pname' has invalid datetime");
      
      my $year  = int($1);
      my $month = int($2);
      my $day   = int($3);
      my $hr    = int($4);
      my $mn    = int($5);
      my $sc    = int($6);
      
      (($year >= 1970) and ($year <= 4999)) or
        send_error($yap, "Archive '$pname' has year out of range");
      (($month >= 1) and ($month <= 12)) or
        send_error($yap, "Archive '$pname' has invalid month");
      (($day >= 1) and ($day <= 31)) or
        send_error($yap, "Archive '$pname' has invalid day");
      (($hr >= 0) and ($hr <= 23)) or
        send_error($yap, "Archive '$pname' has invalid hour");
      (($mn >= 0) and ($mn <= 59)) or
        send_error($yap, "Archive '$pname' has invalid minute");
      (($sc >= 0) and ($sc <= 59)) or
        send_error($yap, "Archive '$pname' has invalid second");
      (check_date($year, $month, $day)) or
        send_error($yap, "Archive '$pname' has invalid date");
    }
    
    # Open work block to update database
    my $dbh = $dbc->beginWork('rw');
    
    for my $pname (keys %$json) {
      # Get the fields in encoded format
      my $uid   = int($pname);
      my $aname = $json->{$pname}->[0];
      my $adate = encode_time(
                    $json->{$pname}->[1], $yap->getVar('epoch'));
      
      # Check whether archive already defined
      my $qr = $dbh->selectrow_arrayref(
                'SELECT parcid FROM parc WHERE parcuid=?',
                undef,
                $uid);
      if (ref($qr) eq 'ARRAY') {
        # Archive already defined, so update it
        $dbh->do(
                'UPDATE parc SET parcname=?, parcuntil=? '
                . 'WHERE parcuid=?',
                undef,
                $aname, $adate, $uid);
        
      } else {
        # Archive not defined yet, so insert it
        $dbh->do(
                'INSERT INTO parc(parcuid, parcname, parcuntil) '
                . 'VALUES (?,?,?)',
                undef,
                $uid, $aname, $adate);
      }
    }
    
    # Finish work block and send done template
    $dbc->finishWork;
    $yap->sendTemplate($done_template);
    
  } else { # -----------------------------------------------------------
    Yip::Admin->bad_request;
  }
  
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
