package PGXN::Manager::Router;

use 5.12.0;
use utf8;
use Plack::Builder;
use Router::Simple::Sinatraish;
use Plack::App::File;
use aliased 'PGXN::Manager::Controller::Root';
use PGXN::Manager;

# The routing table. Define all new routes here.
get '/'            => sub { Root->home(shift) };
get '/auth'        => sub { Root->auth(shift) };
get '/auth/upload' => sub { Root->uplod(shift) };

sub app {
    my $router = shift->router;

    builder {
        mount '/ui' => Plack::App::File->new(root => './www/ui/');
        mount '/' => builder {
            enable 'JSONP';
            if (my $mids = PGXN::Manager->instance->config->{middleware}) {
                enable @$_ for @$mids;
            }
            # Authenticate all requests undef /auth
            enable_if {
                shift->{PATH_INFO} =~ m{^/auth\b}
            }'Auth::Basic', authenticator => sub {
                my ($username, $password) = @_;
                PGXN::Manager->conn->run(sub {
                    return ($_->selectrow_array(
                        'SELECT authenticate_user(?, ?)',
                        undef, $username, $password
                    ))[0];
                });
            };
            sub {
                my $env = shift;
                my $route = $router->match($env) or return [404, [], ['not found']];
                return $route->{code}->($env);
            };
        };
    };
};

1;

=head1 Name

PGXN::Manager::Router - The PGXN::Manager request router.

=head1 Synopsis

  # In app.pgsi
  use PGXN::Manager::Router;
  PGXN::Manager::Router->app;

=head1 Description

This class defines the HTTP request routing table used by PGXN::Manager.
Unless you're modifying the PGXN::Manager routes and controllers, you won't
have to worry about it. Just know that this is the class that Plack uses to
fire up the app.

=head1 Interface

=head2 Class Methods

=head3 C<app>

  PGXN::Manager->app;

Returns the PGXN::Manager Plack app. See F<bin/pgxn_manager.pgsgi> for an
example usage. It's not much to look at. But Plack uses the returned code
reference to power the application.

=head1 Author

David E. Wheeler <david.wheeler@pgexperts.com>

=head1 Copyright and License

Copyright (c) 2010 David E. Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
