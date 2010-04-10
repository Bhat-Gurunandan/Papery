package Papery::Pulp;

use strict;
use warnings;

use Papery::Util;    # do not import merge_meta()
use Storable qw( dclone );
use File::Spec;
use File::Path;

sub new {
    my ( $class, $meta ) = @_;
    return bless { meta => $meta ? dclone($meta) : {} }, $class;
}

sub merge_meta { Papery::Util::merge_meta( $_[0]->{meta}, $_[1] ); }

#
# Steps handlers
#

# utility method
sub _class_args {
    my ( $self, $step_handler) = @_;

    # compute the base class name
    my $base = $step_handler;
    $base =~ s/^_//;
    $base = 'Papery::' . ucfirst $base;

    # get the values from the meta
    my $which = $self->{meta}{$step_handler};
    my ( $class, @args ) = ref $which eq 'ARRAY' ? @{$which} : $which;
    return $class ? "$base\::$class" : $base, @args;
}

sub analyze_file {
    my ( $self,  $file )    = @_;
    my ( $class, @options ) = $self->_class_args('_analyzer');
    return $self if !$class;
    eval "require $class" or die $@;
    return $class->analyze_file( $self, $file, @options );
}

sub process {
    my ($self) = @_;
    my ( $class, @options ) = $self->_class_args('_processor');
    return $self if !$class;
    eval "require $class" or die $@;
    return $class->process($self, @options);
}

sub render {
    my ($self) = @_;
    my ( $class, @options ) = $self->_class_args('_renderer');
    return $self if !$class;
    eval "require $class" or die $@;
    return $class->render($self, @options);
}

sub save {
    my ($self) = @_;
    my $meta = $self->{meta};

    # _permalink is relative to __destination
    $meta->{_permalink} = $meta->{__source_path}
        if !exists $meta->{_permalink};

    my $abspath
        = File::Spec->catfile( $meta->{__destination}, $meta->{_permalink} );
    my ( $volume, $directories, $file ) = File::Spec->splitpath($abspath);

    # portably compute the directory path
    my $dir = File::Spec->catpath( $volume, $directories, '' );
    mkpath($dir) if !-e $dir;

    # now create the file and dump the output
    open my $fh, '>', $abspath or die "Can't create $abspath: $!";
    print {$fh} $meta->{_output};
    close $fh;

    return $self;
}

1;

