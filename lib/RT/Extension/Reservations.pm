=head1 NAME

  RT::Extension::Reservations - Extension to add reservations to RT

=head1 SYNOPSIS


=head1 DESCRIPTION

A reservation is a ticket in a queue using the 'reservations'
lifecycle. To be activated, a reservation needs a start time (Starts),
an end time (Due) and the item being reserved (A URI which the ticket
RefersTo). It must also not conflict with any already activated
reservations.

Two reservations for the same URI conflict when the start times are
equal, their end times are equal, or either reservation's start or end
times fall between the other reservation's start and end times.

=head1 METHODS


=cut


package RT::Extension::Reservations;

use strict;
use warnings;
use version; our $VERSION = version->declare("0.9.0");


# Wrap some functions for reservation-specific logic

no warnings qw(redefine);

package RT::Ticket;


=head2 FindConflicts

Returns a list of reservations that conflict with the current
reservation, or with the given parameters.

=cut

sub FindConflicts {
    my $self = shift;
    my %args = (
        URI    => undef,
        Starts => undef,
        Due    => undef,
        @_,
    );

    my $conflicts = RT::Tickets->new( $self->CurrentUser );
    my ($URI, $Starts, $Due) = (undef, undef, undef);

    # if we have an object, load existing URI and dates
    if ( $self->Id ) {
        $URI = $self->GetReservationURI;
        $Starts = $self->StartsObj->ISO;
        $Due = $self->DueObj->ISO;
    }

    # load args to override existing URI and dates
    $URI    = $args{'URI'}    if $args{'URI'};
    $Starts = $args{'Starts'} if $args{'Starts'};
    $Due    = $args{'Due'}    if $args{'Due'};

    return $conflicts unless $URI && ( $Starts || $Due );

    # search for conflicting tickets
    my @clauses;
    push @clauses, "RefersTo = '$URI'";
    push @clauses, 'id != ' . $self->Id if $self->Id;
    {
        my @statuses = map { "Status = '$_'" } $self->QueueObj->Lifecycle->Valid('active');
        push @clauses, '(' . join( " OR ", @statuses ) . ')';
    }
    {
        my @times;
        if ( $Starts ) {
            push @times, "Starts = '$Starts'";
            push @times, "(Starts < '$Starts' AND Due > '$Starts')";
        }
        if ( $Due ) {
            push @times, "Due = '$Due'";
            push @times, "(Starts < '$Due' AND Due > '$Due')";
        }
        if ( $Starts && $Due ) {
            push @times, "(Starts > '$Starts' AND Starts < '$Due')";
            push @times, "(Due > '$Starts' AND Due < '$Due')";
        }
        push @clauses, '(' . join( " OR ", @times ) . ')';
    }
    my $sql = join( " AND ", @clauses );

    $conflicts->FromSQL( $sql );
    $conflicts->RedoSearch;

    return $conflicts;
}
        

# Check for conflicting reservations
sub SetStarts {
    my $self = shift;
    my $value = shift;

    # Only applies to reservations lifecycle
    return $self->SUPER::SetStarts( $value )
        unless $self->QueueObj->Lifecycle->Name eq 'reservations';

    # Only applies if we are activated
    return $self->SUPER::SetStarts( $value )
        if $self->QueueObj->Lifecycle->IsInitial( $self->Status );

    # Only applies if we have a URI
    my $uri = $self->GetReservationURI;
    return $self->SUPER::SetStarts( $value )
        unless $uri;

    my $tickets = $self->FindConflicts( Starts => $value );
    if ( my $ticket = $tickets->First ) {
        return ( 0, $self->loc('Can\'t set Starts to [_1]. [_2] already reserved from [_3] to [_4] by reservation [_5]',
                               $value, $uri, $ticket->StartsObj->AsString, $ticket->DueAsString, $ticket->Id) );
    }

    return $self->SUPER::SetStarts( $value );
};


# Check for conflicting reservations
sub SetDue {
    my $self = shift;
    my $value = shift;

    # Only applies to reservations lifecycle
    return $self->SUPER::SetDue( $value )
        unless $self->QueueObj->Lifecycle->Name eq 'reservations';

    # Only applies if we are activated
    return $self->SUPER::SetDue( $value )
        if $self->QueueObj->Lifecycle->IsInitial( $self->Status );

    # Only applies if we have a uri
    my $uri = $self->GetReservationURI;
    return $self->SUPER::SetDue( $value )
        unless $uri;

    my $tickets = $self->FindConflicts( Due => $value );
    if ( my $ticket = $tickets->First ) {
        return ( 0, $self->loc('Can\'t set Due to [_1]. [_2] already reserved from [_3] to [_4] by reservation [_5]',
                               $value, $uri, $ticket->StartsObj->AsString, $ticket->DueAsString, $ticket->Id) );
    }

    return $self->SUPER::SetDue( $value )
};


# Can't alter URI for reservations out of initial status
my $Orig_DeleteLink = \&DeleteLink;
*DeleteLink = sub {
    my $self = shift;
    my %args = (
        Target => undef,
        Type   => undef,
        @_
    );

    # Only applies to reservations lifecycle
    return $Orig_DeleteLink->( $self, %args )
        unless $self->QueueObj->Lifecycle->Name eq 'reservations';

    # Only applies if we are activated
    return $Orig_DeleteLink->( $self, %args )
        if $self->QueueObj->Lifecycle->IsInitial( $self->Status );

    return ( 0, $self->loc('Can\'t delete URI from activated reservation') )
	if ( $args{'Type'} eq 'RefersTo' && $args{'Target'} );

    return $Orig_DeleteLink->( $self, %args );
};


# Can't alter URI for reservations out of initial status
my $Orig_AddLink = \&AddLink;
*AddLink = sub {
    my $self = shift;
    my %args = ( Target       => '',
                 Type         => '',
                 @_ );

    # Only applies to reservations lifecycle
    return $Orig_AddLink->( $self, %args )
        unless $self->QueueObj->Lifecycle->Name eq 'reservations';

    # Only applies if we are activated
    return $Orig_AddLink->( $self, %args )
        if $self->QueueObj->Lifecycle->IsInitial( $self->Status );

    return ( 0, $self->loc('Can\'t add another URI to activated reservation') )
	if ( $args{'Type'} eq 'RefersTo' && $args{'Target'} );

    return $Orig_AddLink->( $self, %args );
};


# Wrap to check validity of changes for our workflow
my $Orig_SetStatus = \&SetStatus;
*SetStatus = sub {
    my $self = shift;
    my %args;
    if (@_ == 1) {
        $args{Status} = shift;
    }
    else {
        %args = (@_);
    }

    # Only applies to reservations lifecycle
    return $Orig_SetStatus->( $self, %args )
        unless $self->QueueObj->Lifecycle->Name eq 'reservations';

    # Are we trying to activate?
    return $Orig_SetStatus->( $self, %args )
        unless $self->QueueObj->Lifecycle->IsActive( $args{'Status'} );


    # Make sure we have valid start and end dates
    return ( 0, $self->loc('Can\'t be activated, \'Starts\' must be set') )
        unless $self->StartsObj->Unix;

    return ( 0, $self->loc('Can\'t be activated, \'Due\' must be after \'Starts\'.') )
        unless $self->DueObj->Unix > $self->StartsObj->Unix;


    # Make sure we have a valid uri
    my $uri = $self->GetReservationURI;
    return ( 0, $self->loc('Can\'t be activated, no valid uri') )
        unless $uri;

    my $tickets = $self->FindConflicts;
    if ( my $ticket = $tickets->First ) {
        return ( 0, $self->loc('[_1] already reserved from [_2] to [_3] by reservation [_4]',
                              $uri, $ticket->StartsObj->AsString, $ticket->DueAsString, $ticket->Id) );
    }

    return $Orig_SetStatus->( $self, %args );
};



=head2 GetReservationURI

This returns the URI we are reserving. The reservation ticket must
ReferTo exactly one URI for it to be a valid reservation.

=cut

sub GetReservationURI {
    my $self = shift;

    # Only applies to reservations lifecycle
    return ( 0, $self->loc('Not a reservation ticket') )
        unless $self->QueueObj->Lifecycle->Name eq 'reservations';

    my $links = $self->RefersTo;
    $links->RedoSearch;
    my $found = 0;
    my $URI;
    while ( my $link = $links->Next ) {
        $URI = $link->Target;
        $found++;
    }

    return wantarray ? ( undef, $self->loc('Too many referred URIs') ) : undef
        if $found > 1;

    return wantarray ? ( undef, $self->loc('No referred URI') ) : undef
        if $found < 1;

    return ( $URI );
}


require RT::Base;
RT::Base->_ImportOverlays();

1;
