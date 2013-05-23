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


Set(%Lifecycles,
    reservations => {
        initial         => [ 'tentative', 'booked' ],
        active          => [ 'out' ],
        inactive        => [ 'returned', 'settled', 'cancelled', 'deleted' ],

        defaults => {
            on_create => 'tentative',
            on_merge  => 'cancelled',
            approved  => 'booked',
            denied    => 'cancelled',
            reminder_on_open     => 'open',
            reminder_on_resolve  => 'resolved',
        },

        transitions => {
            ''        => [qw(tentative)],

            # from   => [ to list ],
            tentative => [qw(booked cancelled)],
            booked    => [qw(tentative out cancelled)],
            out       => [qw(returned settled booked)], #booked only for testing
            returned  => [qw(deleted booked)], #booked only for testing)],
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
