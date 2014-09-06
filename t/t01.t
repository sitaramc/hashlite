#!/usr/bin/perl
# XXX incomplete; still need to add tests for delete, grep, and get
use 5.10.0;
use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
sub dd { say STDERR Dumper @_; }

use lib "$ENV{HOME}/bin";
use Tsh;

# plan -- change this when #tests changes
    try 'plan 99';

# settings/defines
    my $db = "/tmp/hltest.$$";

# setup test env
    system("rm -f $db");
    END { system("rm -f $db"); }

# create a new database
    try "
        hashlite new;                       /need database name/
        hashlite new $db;                   /need database name/
        hashlite new -d $db;                /need table name/
        hashlite -d $db new;                /need table name/
        hashlite -d $db new tbl1;           /need table name/

        hashlite -d $db new -t tbl1;        /echo .create table tbl1 .k text primary key, t int, v text... . sqlite3 $db/
        hashlite -d $db new -t tbl1 | sh;   ok; !/./
    ";

    try "
        hashlite tables;                    /need database name/
        hashlite -d $db tables;             ok; /tbl1/
        hashlite -d $db new -t tbl2 | sh;   ok; !/./
        hashlite -d $db new -t tbl2 | sh;   /table tbl2 already exists/

        hashlite tables;                    /need database name/
        hashlite -d $db tables;             ok; /tbl1/; /tbl2/

        hashlite -d $db dump;               ok; /table:.tbl1/; /table:.tbl2/
    ";

    try "
        hashlite -d $db -t tbl1 sk-1 sv-1;  /unknown command .sk-1/
        hashlite -d $db -t tbl1 set sk-1;   /syntax:/
        hashlite -d $db -t tbl1 set sk-1 sv-1;
                                            /syntax:/
        hashlite -d $db -t tbl1 set sk-1 = sv-1;
                                            ok; !/./
        hashlite -d $db dump > /tmp/junk.hlt
        hashlite -d $db dump;               ok;
    ";
cmp 'table:	tbl1
key:	sk-1
sv-1
table:	tbl2
';

    try "
        hashlite -d $db -t tbl1 set ck-1 subk-2;
                                            /syntax:/
        hashlite -d $db -t tbl1 set ck-1 subk-2 subv-1
                                            /syntax:/
        hashlite -d $db -t tbl1 set ck-1 subk-2 = subv-1
                                            ok; !/./
    ";

    try "
        hashlite -d $db dump;               ok;
    ";
cmp "table:	tbl1
key:	sk-1
sv-1
key:	ck-1
{
  'subk-2' => 'subv-1'
}

table:	tbl2
";

    try "
        hashlite -d $db keys -t tbl1;       ok;
    ";
cmp "sk-1
ck-1
";

    try "
        hashlite -d $db keys -t tbl2;       !ok; !/./
    ";

    try "
        hashlite -d $db dump -t tbl1;       ok;
    ";
cmp "key:	sk-1
sv-1
key:	ck-1
{
  'subk-2' => 'subv-1'
}

";
    try "
        hashlite -d $db dump -t tbl2;       ok; !/./
    ";
