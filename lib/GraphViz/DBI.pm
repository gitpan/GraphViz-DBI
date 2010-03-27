use 5.008;
use strict;
use warnings;

package GraphViz::DBI;
our $VERSION = '1.100860';
# ABSTRACT: Graph database tables and relations
use Carp;
use GraphViz;
our $AUTOLOAD;

sub new {
    my $this  = shift;
    my $class = ref($this) || $this;
    my $self  = {};
    bless $self, $class;
    $self->_init(@_);
    return $self;
}

sub _init {
    my $self = shift;
    $self->set_dbh(+shift) if @_;
    $self->{g} = GraphViz->new();
}

sub set_dbh {
    my ($self, $dbh) = @_;
    $self->{dbh} = $dbh;
    return $self;
}

sub get_dbh {
    my $self = shift;
    return $self->{dbh};
}

sub get_tables {
    my $self = shift;
    $self->{tables} ||= [ $self->get_dbh->tables ];
    return @{ $self->{tables} };
}

sub is_table {
    my ($self, $table) = @_;
    $self->{is_table} ||= { map { $_ => 1 } $self->get_tables };
    return $self->{is_table}{$table};
}

sub is_foreign_key {

    # if the field name is of the form "<table>_id" and
    # "<table>" is an actual table in the database, treat
    # this as a foreign key.
    # This is my convention; override it to suit your needs.
    my ($self, $table, $field) = @_;
    return if $field =~ /$table[_-]id/i;
    return unless $field =~ /^(.*)[_-]id$/i;
    my $candidate = $1;
    return unless $self->is_table($candidate);
    return $candidate;
}

sub graph_tables {
    my $self = shift;
    my %table = map { $_ => 1 } $self->get_tables;
    for my $table ($self->get_tables) {
        my $sth = $self->get_dbh->prepare("select * from $table where 1 = 0");
        $sth->execute;
        my @fields = @{ $sth->{NAME} };
        $sth->finish;
        my $label = "{$table|";
        for my $field (@fields) {
            $label .= $field . '\l';
            if (my $dep = $self->is_foreign_key($table, $field)) {
                $self->{g}->add_edge({ from => $table, to => $dep });
            }
        }
        $self->{g}->add_node(
            {   name  => $table,
                shape => 'record',
                label => "$label}",
            }
        );
    }
    $self->{g};
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) or croak "$self is not an object";
    (my $name = $AUTOLOAD) =~ s/.*:://;
    return if $name =~ /DESTROY/;

    # hm, maybe GraphViz knows what to do with it...
    $self->{g}->$name(@_);
}
1;


__END__
=pod

=head1 NAME

GraphViz::DBI - Graph database tables and relations

=head1 VERSION

version 1.100860

=head1 SYNOPSIS

  use GraphViz::DBI;
  my $dbh = DBI->connect('...', '...', '...');
  print GraphViz::DBI->new($dbh)->graph_tables->as_png;

=head1 DESCRIPTION

This module constructs a graph for a database showing tables and
connecting them if they are related. While or after constructing the
object, pass an open database handle, then call C<graph_tables> to
determine database metadata and construct a GraphViz graph from the
table and field information.

The methods described here are defined by this class; all other method calls
are passed to the underlying GraphViz object:

=head1 METHODS

=head2 new([$dbh])

Constructs the object; also creates a GraphViz object. The constructor
accepts an optional open database handle.

=head2 set_dbh($dbh)

Sets the database handle.

=head2 get_dbh()

Returns the database handle.

=head2 get_tables()

Returns the tables defined in the database.

=head2 is_table($table)

Checks the database metadata whether the argument is a valid table name.

=head2 is_foreign_key($table, $field)

Determines whether the field belonging to the table is a foreign key
into some other table. If so, it is expected to return the name of that
table. If not, it is expected to return a false value.

For example, if there is a table called "product" and another table
contains a field called "product_id", then to indicate that this field is
a foreign key into the product table, the method returns "product". This
is the logic implemented in this class. You can override this method in
a subclass to suit your needs.

=head2 graph_tables()

This method goes through all tables and fields and calls appropriate
methods to determine which tables and which dependencies exist, then
hand the results over to GraphViz. It returns the GraphViz object.

=head1 FEATURE IDEAS

=over 4

=item *

Test with various database drivers to see whether they support the
metadata interface.

=item *

Make each table a vertical port with dependencies using those ports.

=item *

Provide the possibility to name edges to specify the type of relationship
('has-a', 'is-a', etc.).

=back

=head1 INSTALLATION

See perlmodinstall for information and options on installing Perl modules.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through the web interface at
L<http://rt.cpan.org/Public/Dist/Display.html?Name=GraphViz-DBI>.

=head1 AVAILABILITY

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see
L<http://search.cpan.org/dist/GraphViz-DBI/>.

The development version lives at
L<http://github.com/hanekomu/GraphViz-DBI/>.
Instead of sending patches, please fork this project using the standard git
and github infrastructure.

=head1 AUTHOR

  Marcel Gruenauer <marcel@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2001 by Marcel Gruenauer.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

