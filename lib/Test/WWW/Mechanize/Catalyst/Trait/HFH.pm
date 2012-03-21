package Test::WWW::Mechanize::Catalyst::Trait::HFH;
# ABSTRACT: inspect HTML::FormHandler via TWMC

use 5.010;
use Moose::Role;
use namespace::autoclean;

require 'ctx';

has hfh_default_stash_key => (
  is  => 'ro',
  isa => 'Str',
  default => 'form',
);

has hfh_default_fetch_form => (
  is  => 'ro',
  isa => 'CodeRef',
  default => sub{ sub{
    my ( $self, $args ) = @_;

    my $key = ref $args eq 'HASH' && exists $args->{hfh_stash_key} ?
      delete $args->{hfh_stash_key} : $self->hfh_default_stash_key;

    my $ctx = $self->unredirected_ctx || $self->ctx
      or die "Can't fetch form without active catalyst context";

    return $ctx->stash->{ $key };
  }},
);


sub _splice_hfh_args {
  return +{ map{ $_ => delete $_[0]->{ $_ } } grep{/^hfh_/} keys %{ $_[0] }};
}

sub submit_form_success {
  my ( $self, $wm_args, $msg ) = @_;
  $msg ||= 'Form submission';

  my $builder = Test::Builder->new;
  $builder->subtest( $msg, sub{

    my $hfh_args = _splice_hfh_args( $wm_args );
    $self->submit_form_ok( $wm_args, 'Form submission' );

    my $form = $self->hfh_default_fetch_form->(
      $self, { %$wm_args, %$hfh_args }
    );

    $builder->ok( $form, 'CTX has a form attribute' ) or return;
    $builder->ok( $form->is_valid, 'Form is valid' ) or $builder->diag(
      q{Invalid fields: ['} . join(q{', '},$form->error_field_names ) . q{']}
    ) or $builder->diag( $builder->explain( $form->errors ) );
  });
}

sub submit_form_with_errors {
  my ( $self, $wm_args, $msg ) = @_;
  $msg ||= 'Form submission';

  croak "Needs 'hfh_errors' argument"
    unless ref $wm_args eq 'HASH' and exists $wm_args->{hfh_errors};

  my $builder = Test::Builder->new;
  $builder->subtest( $msg, sub{

    my $hfh_args = _splice_hfh_args( $wm_args );
    my @expected = @{ $hfh_args->{hfh_errors} };

    $self->submit_form_ok( $wm_args, 'Form submission' );

    my $form = $self->hfh_default_fetch_form->(
      $self, { %$wm_args, %$hfh_args }
    );

    $builder->ok( $form, 'CTX has a form attribute' ) or return;

    my @actual = $form->error_field_names;

    my @unexpected = grep{ $a = $_; not grep{ $_ eq $a } @expected } @actual;
    my @nonerror   = grep{ $a = $_; not grep{ $_ eq $a } @actual } @expected;

    $builder->ok( !@unexpected, 'No unexpected errors' ) or $builder->diag(
      q{Unexpected errors: ['} . join(q{', '}, @unexpected) . qq{']},
    ) or $builder->diag( $builder->explain([ $form->errors ]) );

    $builder->ok( !@nonerror, 'All errors found' ) or $builder->diag(
      q{Un-flagged or unknown fields: ['} . join(q{', '}, @nonerror) . qq{']},
    );
  });
}

1;
