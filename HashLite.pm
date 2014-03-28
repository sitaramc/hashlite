package HashLite;

@EXPORT = qw(
  new
  set
  get
  _exists
  _grep
);
use Exporter 'import';

use strict;
use warnings;
use 5.10.0;

use Data::Dumper;
$Data::Dumper::Terse    = 1;
$Data::Dumper::Indent   = 1;
$Data::Dumper::Sortkeys = 1;

use DBI;
use Storable qw(freeze thaw);

sub new {
    my $class = shift;

    my $DB = shift;
    # we assume it's already created
    die "'$DB' does not exist" unless -f $DB;
    my $dbh = DBI->connect( "dbi:SQLite:dbname=$DB", "", "", { RaiseError => 1 } );

    return bless { DB => $DB, dbh => $dbh }, $class;
}

sub set {
    my $this = shift;
    my $dbh  = $this->{dbh};

    my $table = shift;
    my ( $k, $v ) = @_;

    unless ( defined $v ) {
        my $sth = $dbh->prepare_cached("delete from $table where k = ?");
        return 0 + $sth->execute($k);
    }

    my $t = ref($v) || 0;
    $v = freeze($v) if $t;

    # XXX any encryption must happen here

    if ( _exists( $this, $table, $k ) ) {
        my $sth = $dbh->prepare_cached("update $table set t = ?, v = ? where k = ?");
        $sth->execute( $t, $v, $k );

    } else {
        my $sth = $dbh->prepare_cached("insert into $table (k, t, v) values(?,?,?)");
        $sth->execute( $k, $t, $v );
    }
}

sub get {
    my $this = shift;
    my $DB   = $this->{DB};

    my $table = shift or die "'get' needs arguments";
    if ( $table eq 'tables' ) {
        return [ split( ' ', `echo .tables | sqlite3 $DB | sort` ) ];
    }

    die "'get' needs more arguments after '$table'" unless @_;

    if ( $table eq 'keys' ) {
        # current 1st arg is a table name, optionally followed by a key
        # pattern and a value pattern; see _keys code
        return _keys( $this, @_ );
    }

    # now it's a normal table
    my $key = shift;
    return _get( $this, $table, $key );
}

sub _exists {
    my $this = shift;
    my $dbh  = $this->{dbh};

    my $table = shift;
    my $sth   = $dbh->prepare_cached("select k from $table where k = ?");
    return @{ $dbh->selectall_arrayref( $sth, undef, +shift ) };
}

sub _grep {
    my $this = shift;

    # returns hash of keys+values of rows that satisfy callback
    my ( $table, $code ) = @_;
    my $ks = _keys( $this, $table );
    my @ret;
    for my $k (@$ks) {
        my $v = get( $this, $table, $k );
        push @ret, $k, $v if $code->( $k, $v );
    }
    return @ret;
}

sub _keys {
    my $this = shift;
    my $dbh  = $this->{dbh};

    my $table = shift or die 'need table name';
    my $k_patt = shift || '';
    my $v_patt = shift || '';

    # XXX not sure how useful the v_patt is when it's a frozen perl ds
    my $cmd = "select k from $table";
    $cmd .= " where" if $k_patt or $v_patt;
    $cmd .= " k like '%$k_patt%'" if $k_patt;
    $cmd .= " and"                if $k_patt and $v_patt;
    $cmd .= " v like '%$v_patt%'" if $v_patt;
    $cmd .= " order by rowid";

    my $sth = $dbh->prepare_cached($cmd);
    my $x   = $dbh->selectall_arrayref($sth);
    return [ map { @$_ } @{$x} ] if @$x;
    return ();
}

sub _get {
    my $this = shift;
    my $dbh  = $this->{dbh};

    my $table = shift;
    my $sth   = $dbh->prepare_cached("select t, v from $table where k = ?");
    my $x     = $dbh->selectall_arrayref( $sth, undef, +shift );

    my ( $t, $v ) = ( 0, undef );
    ( $t, $v ) = @{ $x->[0] } if ref( $x->[0] );

    # XXX any decryption must happen here

    $v = thaw($v) if $t;

    return $v;
}

1;
__END__

read t; echo "
    create table $t ( k text primary key, t boolean, v text );
" | sqlite3 hh.db
