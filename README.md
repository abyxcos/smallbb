# smallbb
A small bulletin board in perl

## Dependencies
This is a [Plack](http://plackperl.org/) app, and uses [SQLite](https://sqlite.org/).
* [Plack](http://search.cpan.org/~miyagawa/Plack-1.0033/lib/Plack.pm)
* [PSGI](http://search.cpan.org/~miyagawa/PSGI-1.102/PSGI.pod)
* [DBD::SQLite](http://search.cpan.org/~ishigaki/DBD-SQLite-1.46/lib/DBD/SQLite.pm)
* [HTML::Escape](http://search.cpan.org/dist/HTML-Escape/)

## Installation
Smallbb should be installed outside the web server directory, as this may accidentally allow the database to be downloaded. Only the database and the CSS files are required in the installation directory. The smallbb.psgi application may be installed elsewhere.
    sqlite3 boards.db < smallbb.schema

## Usage
Run the application in the installation directory. Multiple installations in separate directories can be served by a single application file.
    plackup smallbb.psgi

## Configuration
Smallbb may be configured via the variables at the top of the file.

## Theming
Smallbb uses the same template system as jekyll. The default smallbb template is the jekyll default.

## License
Smallblog is released under the ISC (2-BSD) license. Please see [LICENSE](https://github.com/abyxcos/smallbb/blob/master/LICENSE) for the full text.
