RT::Extension::Reservations
===========================

Adds a reservations system to the Request Tracker/Asset Tracker combination 


A reservation is a ticket in a queue using the 'reservations'
lifecycle. To be activated, a reservation needs a start time (Starts),
an end time (Due) and an asset (A RefersTo link, to an
RTx::AssetTracker::Asset). It must also not conflict with any already
activated reservations.

Two reservations conflict when their start times are equal, their end
times are equal, or either reservation's start or end times fall
between the other reservation's start and end times.
