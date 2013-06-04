RT::Extension::Reservations
===========================

Adds a reservations system to Request Tracker


A reservation is a ticket in a queue using the 'reservations'
lifecycle. To be activated, a reservation needs a start time (Starts),
an end time (Due) and the item being reserved (A URI which the ticket
RefersTo). It must also not conflict with any already activated
reservations.

Two reservations for the same URI conflict when the start times are
equal, their end times are equal, or either reservation's start or end
times fall between the other reservation's start and end times.
