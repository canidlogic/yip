# NAME

yipreset.pl - Password reset administration CGI script for Yip.

# SYNOPSIS

    /cgi-bin/yipreset.pl

# DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles resetting or changing the administrator password.  After
a new Yip CMS database is created with `createdb.pl` and initialized
with `resetdb.pl`, this script is the next step, to set an
administrator password.  This script can also be used after a password
reset with `resetdb.pl` to set the new password after reset.  Finally,
this script can be used to change an existing password.

This is one of the few administrator CGI scripts that can function
without an authorization cookie.  If a valid authorization cookie is
present, then the GET form and the error page will provide a links back
to the administrator control panel.  Otherwise, the links will not be
provided.  That is the only difference between authorized and
unauthorized operation.

The operation of the script also varies depending on whether there is a
current administrator password in the Yip CMS database, or whether the
password is currently in a reset state.  If the password is in a reset
state, this script only asks for a new password to set and will set it
on a first-come first-serve basis.  If the password is not in a reset
state, then the current password must be provided in order to reset it.

Accessing this script with a GET request will display a form that asks
for the new password, another copy of the new password (to verify
against typos), and the current password (unless in a password reset
state).

This script is also the POST request target of the form it provides in
the GET request.  If the operation succeeds, a logout operation is
performed in addition to changing the password, and the success page
provides a link to the login page.  If the operation fails, an error
message is shown and the logout action is not performed.

# AUTHOR

Noah Johnson, `noah.johnson@loupmail.com`

# COPYRIGHT AND LICENSE

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
