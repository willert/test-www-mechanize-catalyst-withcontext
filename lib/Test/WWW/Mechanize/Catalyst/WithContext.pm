package Test::WWW::Mechanize::Catalyst::WithContext;
# ABSTRACT: somewhat hackish way to access context through TWMC

our $VERSION = '0.03';

use 5.010;
use Moose;
use namespace::autoclean;

require Test::WWW::Mechanize::Catalyst;

extends 'Test::WWW::Mechanize::Catalyst';
with 'MooseX::Traits';

has '+_trait_namespace' => (
  default => 'Test::WWW::Mechanize::Catalyst::Trait'
);

has ctx => (
  is     => 'ro',
  isa    => 'Catalyst',
  writer => '_set_ctx',
);

has unredirected_ctx => (
  is      => 'ro',
  isa     => 'Catalyst',
  writer  => '_set_unredirected_ctx',
  clearer => '_clear_unredirected_ctx',
);

has _clobber_unredirected_ctx => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);

has _do_ctx_request => (
  is         => 'ro',
  isa        => 'CodeRef',
  lazy_build => 1,
);

sub _build__do_ctx_request {
  my $self = shift;
  my $ctx_request;
  my $test = 'Catalyst::Test';

  require Catalyst;
  if ( $Catalyst::VERSION >= 5.80001 ) {
    my $request = $test->_build_request_export({
      class => $self->{catalyst_app}
    });
    $ctx_request = Catalyst::Test->_build_ctx_request_export({
      class => $self->{catalyst_app}, request => $request,
    });
  };

  return sub{
    my $request = shift;
    return $ctx_request ? $ctx_request->( $request ) : (
      Catalyst::Test::local_request( $self->{catalyst_app}, $request ), undef
    );
  }
}

sub _do_catalyst_request {
  my ($self, $request) = @_;

  # taken almost 1:1 from Test::WWW::Mechanize::Catalyst

  my $uri = $request->uri;
  $uri->scheme('http') unless defined $uri->scheme;
  $uri->host('localhost') unless defined $uri->host;

  $request = $self->prepare_request($request);
  $self->cookie_jar->add_cookie_header($request) if $self->cookie_jar;

  # Woe betide anyone who unsets CATALYST_SERVER
  return $self->_do_remote_request($request)
    if $ENV{CATALYST_SERVER};

  $self->_set_host_header($request);

  my $res = $self->_check_external_request($request);
  return $res if $res;

  my @creds = $self->get_basic_credentials( "Basic", $uri );
  $request->authorization_basic( @creds ) if @creds;

  my ( $response, $ctx ) = $self->_do_ctx_request->( $request );

  if ( $response->code =~ m/^30/ ) {
    # avoid clobbering unredirected ctx during redirection chains
    # printf STDERR "Storing context for redirecting response\n", ;
    $self->_set_unredirected_ctx( $ctx ) unless $self->unredirected_ctx;
  } elsif ( $self->unredirected_ctx and not $self->_clobber_unredirected_ctx ) {
    # printf STDERR "Mark stored context for clobbering\n", ;
    $self->_clobber_unredirected_ctx( 1 );
  } elsif ( $self->unredirected_ctx ) {
    # printf STDERR "Clobbering unredirected context\n", ;
    $self->_clobber_unredirected_ctx( 0 );
    $self->_clear_unredirected_ctx;
  }

  $self->_set_ctx( $ctx );

  # LWP would normally do this, but we dont get down that far.
  $response->request($request);

  return $response
}

1;
__END__

=head1 AUTHORS

Sebastian Willert <s.willert@wecare.de>
Susanne Schmidt <susanne.schmidt@wecare.de>

=cut
