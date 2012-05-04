#!/usr/bin/perl -w

use strict;
use lib qw| /path/to/qoan |;  # Include path to Qoan
use Qoan::Controller;

my( $q );

$q = Qoan::Controller->new_request;

# Put any configuration stuff here.

$q->process_request;


exit;


# Put your action map/supporting routines here.
