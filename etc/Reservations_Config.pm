#############################  WARNING  #############################
#                                                                   #
#                NEVER EDIT Reservations_Config.pm !                #
#                                                                   #
#      Instead, copy any sections you want to change to             #
#      Reservations_SiteConfig.pm and edit them there.              #
#      Otherwise, your changes will be lost when you upgrade        #
#      RT-Extension-Reservations.                                   #
#                                                                   #
#############################  WARNING  #############################

=head2 The reservations lifecycle

The reservations lifecycle is used for reservations in RT.

=over 4

=item initial

B<tentative> is the initial status for reservations.

=item active

B<booked> reservations are scheduled to be B<out> at some point in the
future, and therefore the reserved item can not be booked by other
reservations at that time. B<booked> is logically sort of between an
initial and an active status. It is a little odd, for example, that
generally the "Started" time, when the reservation was booked, is
earlier than the "Starts" time, when the reservation is supposed to go
out.

B<out> reservations are "currently in progress" - the reserved item
will not be available to go out on other reservations until
B<returned>.

=item inactive

B<returned> reservations have been checked in or otherwise freed their
reserved item to be booked or go out on other reservations.

B<settled> reservations have been ended in some way other than a
normal return. For example the reserved item was lost or damaged, and
is no longer available to be booked or go out on other reservations.

B<cancelled> reservations have been ended without the item ever going
out, and therefore the reserved item is once again available to be
booked or go out on other reservations.

B<deleted> is used to get rid of things that were never a real
reservation to begin with. This is never used except for cleaning up
testing reservations or erroneous entries.

=back

=cut

Set(%Lifecycles,
    reservations => {
        initial         => [ 'tentative' ],
        active          => [ 'booked', 'out' ],
        inactive        => [ 'returned', 'settled', 'cancelled', 'deleted' ],

        defaults => {
            on_create => 'tentative',
            on_merge  => 'cancelled',
            approved  => 'booked',
            denied    => 'cancelled',
            reminder_on_open     => 'out',
            reminder_on_resolve  => 'returned',
        },

        transitions => {
            ''        => [qw(tentative)],

            # from   => [ to list ],
            tentative => [qw(booked cancelled)],
            booked    => [qw(tentative out cancelled)],
            out       => [qw(returned settled)],
            returned  => [qw(deleted)],
            settled   => [qw(deleted)],
            cancelled => [qw(deleted)],
            deleted   => [qw()],
        },
        rights => {
            '* -> deleted'  => 'DeleteTicket',
            '* -> *'        => 'ModifyTicket',
        },
        actions => [
            'tentative -> booked'   => {
                label  => 'Confirm', # loc
            },
            'booked -> out'   => {
                label  => 'Check Out', # loc
            },
            'out -> returned' => {
                label  => 'Check In', # loc
            },
            '* -> cancelled' => {
                label  => 'Cancel', # loc
            },
        ],
    },
);


1;
