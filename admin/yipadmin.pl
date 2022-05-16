#!/usr/bin/env perl
use strict;
use warnings;

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yipadmin.pl - Control panel administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipadmin.pl

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script is the main control panel screen.  The client must have an
authorization cookie to use this script.

GET is the only method supported by this script.

=cut

# =========
# Templates
# =========

# GET template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
my $get_template = Yip::Admin->format_html('Control panel', q{
    <h1>Control panel</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathlogout>">
        &raquo; Log out &laquo;
      </a>
    </div>
    <div style="text-align: center;">
      
      <div class="linkhead">
        <a href="<TMPL_VAR NAME=_pathlist>?report=posts" class="btn">
          Posts
        </a>
      </div>
      <div class="linkbar">
        <a href="<TMPL_VAR NAME=_pathlist>?report=archives" class="btn">
          Archives
        </a>
      </div>

      <div class="linkhead">
        <a href="<TMPL_VAR NAME=_pathlist>?report=globals" class="btn">
          Global resources
        </a>
      </div>
      <div class="linkbar">
        <a href="<TMPL_VAR NAME=_pathlist>?report=types" class="btn">
          Data types
        </a>
      </div>

      <div class="linkhead">
        <a href="<TMPL_VAR NAME=_pathlist>?report=vars" class="btn">
          Template variables
        </a>
      </div>
      <div class="linkbar">
        <a href="<TMPL_VAR NAME=_pathlist>?report=templates"
            class="btn">
          Templates
        </a>
      </div>

      <div class="linkhead">
        <a href="<TMPL_VAR NAME=_pathreset>" class="btn">
          Change password
        </a>
      </div>
    </div>
});

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

# Send template
#
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
