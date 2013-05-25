package RT::Extension::Reservations;

use strict;
use warnings;
use version; our $VERSION = version->declare("0.9.0");


# Wrap some functions for reservation-specific logic

no warnings qw(redefine);

package RT::Ticket;


# Check for conflicting reservations
sub SetStarts {
    my $self = shift;
    my $value = shift;

    # Only applies to reservations lifecycle
    return $self->SUPER::SetStarts( $value )
        unless $self->QueueObj->Lifecycle->Name eq 'reservations';

    # Only applies if we have an asset
    my ( $asset, $msg ) = $self->GetReservationAsset;
    return $self->SUPER::SetStarts( $value )
        unless $asset;

    my $Starts = RT::Date->new( $self->CurrentUser );
    if ( defined $value ) {
        $Starts->Set( Format => 'ISO', Value => $value );
    }

    # Look for conflicts
    my @values = (
        $self->Id,
        $asset->URI,
        $Starts,
        $Starts, $Starts,
        join( " OR ", map { "Status = '$_'" } $self->QueueObj->Lifecycle->Valid('active') ),
    );

    my $sql = <<SQL;
id != %d
 AND RefersTo = '%s'
 AND (Starts = '%s'
  OR  (Starts <   '%s' AND    Due > '%s'))
 AND (%s)
SQL

    RT::Logger->info($sql);

    $sql = sprintf($sql, @values);

    my $tickets = RT::Tickets->new( $self->CurrentUser );
    $tickets->FromSQL( $sql );
    $tickets->RedoSearch;
    if ( my $ticket = $tickets->First ) {
        return ( 0, $self->loc('Can\'t set Starts to [_1]. Asset [_2] already reserved from [_3] to [_4] by ticket [_5]',
			       $Starts->AsString, $asset->Id, $ticket->StartsObj->AsString, $ticket->DueAsString, $ticket->Id) );
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

    # Only applies if we have an asset
    my ( $asset, $msg ) = $self->GetReservationAsset;
    return $self->SUPER::SetDue( $value )
        unless $asset;

    my $Due = RT::Date->new( $self->CurrentUser );
    if ( defined $value ) {
        $Due->Set( Format => 'ISO', Value => $value );
    }

    # Look for conflicts
    my @values = (
        $self->Id,
        $asset->URI,
        $Due,
        $Due, $Due,
        join( " OR ", map { "Status = '$_'" } $self->QueueObj->Lifecycle->Valid('active') ),
    );

    my $sql = <<SQL;
id != %d
 AND RefersTo = '%s'
 AND (Due = '%s'
  OR  (Starts <   '%s' AND    Due > '%s'))
 AND (%s)
SQL

    RT::Logger->info($sql);

    $sql = sprintf($sql, @values);

    my $tickets = RT::Tickets->new( $self->CurrentUser );
    $tickets->FromSQL( $sql );
    $tickets->RedoSearch;
    if ( my $ticket = $tickets->First ) {
        return ( 0, $self->loc('Can\'t set Due to [_1]. Asset [_2] already reserved from [_3] to [_4] by ticket [_5]',
			       $Due->AsString, $asset->Id, $ticket->StartsObj->AsString, $ticket->DueAsString, $ticket->Id) );
    }

    return $self->SUPER::SetDue( $value )
};


# Can't alter asset link for reservations out of initial status
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

    return $Orig_DeleteLink->( $self, %args )
        if $self->QueueObj->Lifecycle->IsInitial( $self->Status );

    if ( $args{'Type'} eq 'RefersTo' && $args{'Target'} ) {
        my $uri = RT::URI->new( $self->CurrentUser );
        $uri->FromURI( $args{'Target'} );
        my $obj = $uri->Resolver->Object;

        return ( 0, $self->loc('Can\'t delete asset from activated reservation') )
            if ( UNIVERSAL::isa($obj, 'RTx::AssetTracker::Asset') && $obj->id );
    }

    return $Orig_DeleteLink->( $self, %args );
};


# Can't alter asset link for reservations out of initial status
my $Orig_AddLink = \&AddLink;
*AddLink = sub {
    my $self = shift;
    my %args = ( Target       => '',
                 Type         => '',
                 @_ );

    # Only applies to reservations lifecycle
    return $Orig_AddLink->( $self, %args )
        unless $self->QueueObj->Lifecycle->Name eq 'reservations';

    return $Orig_AddLink->( $self, %args )
        if $self->QueueObj->Lifecycle->IsInitial( $self->Status );

    if ( $args{'Type'} eq 'RefersTo' && $args{'Target'} ) {
        my $uri = RT::URI->new( $self->CurrentUser );
        $uri->FromURI( $args{'Target'} );
        my $obj = $uri->Resolver->Object;

        return ( 0, $self->loc('Can\'t add another asset to reservation') )
            if ( UNIVERSAL::isa($obj, 'RTx::AssetTracker::Asset') && $obj->id );
    }

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

    RT::Logger->info($self->loc("Ticket [_1]: want to set status to [_2]", $self->Id, $args{'Status'}));
    # Are we trying to activate?
    return $Orig_SetStatus->( $self, %args )
        unless $self->QueueObj->Lifecycle->IsActive( $args{'Status'} );


    # Make sure we have valid start and end dates
    return ( 0, $self->loc('Can\'t be activated, \'Starts\' must be in the future.') )
        unless $self->StartsObj->Unix > time;

    return ( 0, $self->loc('Can\'t be activated, \'Due\' must be after \'Starts\'.') )
        unless $self->DueObj->Unix > $self->StartsObj->Unix;


    # Make sure we have a valid asset
    my ( $asset, $msg ) = $self->GetReservationAsset;
    return ( 0, $self->loc('Couldn\'t load asset: [_1]', $msg) )
        unless $asset;

    # Make sure linked asset is not already reserved
    my @values = (
        $self->Id,
        $asset->URI,
        $self->StartsObj->ISO,
        $self->DueObj->ISO,
        $self->StartsObj->ISO, $self->DueObj->ISO,
        $self->StartsObj->ISO, $self->DueObj->ISO,
        $self->StartsObj->ISO, $self->StartsObj->ISO,
        $self->DueObj->ISO, $self->DueObj->ISO,
        join( " OR ", map { "Status = '$_'" } $self->QueueObj->Lifecycle->Valid('active') ),
    );

    my $sql = <<SQL;
id != %d
 AND RefersTo = '%s'
 AND (Starts = '%s'
  OR     Due = '%s'
  OR  (Starts >   '%s' AND Starts < '%s')
  OR  (   Due >   '%s' AND    Due < '%s')
  OR  (Starts <   '%s' AND    Due > '%s')
  OR  (Starts <   '%s' AND    Due > '%s'))
 AND (%s)
SQL

    RT::Logger->info($sql);

    $sql = sprintf($sql, @values);

    my $tickets = RT::Tickets->new( $self->CurrentUser );
    $tickets->FromSQL( $sql );
    $tickets->RedoSearch;
    if ( my $ticket = $tickets->First ) {
        return ( 0, $self->loc('asset [_1] already reserved from [_2] to [_3] by ticket [_4]',
                              $asset->Id, $ticket->StartsObj->AsString, $ticket->DueAsString, $ticket->Id) );
    }

    return $Orig_SetStatus->( $self, %args );
};




=head2 GetReservationAsset

  This returns the asset we are reserving.

=cut

sub GetReservationAsset {
    my $self = shift;

    # Only applies to reservations lifecycle
    return ( 0, $self->loc('Not a reservation ticket') )
        unless $self->QueueObj->Lifecycle->Name eq 'reservations';

    my $links = $self->RefersTo;
    $links->RedoSearch;
    my $found = 0;
    my $Asset;
    RT::Logger->info( $self->loc("found [_1] links for ticket [_2]", $links->Count, $self->Id) );
    while ( my $link = $links->Next ) {
        my $target = $link->TargetObj;
        next unless ref( $target ) eq 'RTx::AssetTracker::Asset';

        $Asset = $target;
        $found++;
    }

    return ( 0, $self->loc('Too many referred assets') )
        if $found > 1;

    return ( 0, $self->loc('No referred asset') )
        if $found < 1;

    return ( $Asset, '' );
}


1;
