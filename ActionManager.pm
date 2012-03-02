
package Qoan::ActionManager;

# Qoan::ActionManager
# 
# ACTIONS
#	SEQUENCE
#		Action names in order.
#	VALIDATIONS applicable to all actions (e.g. authorization, sequence check)
#	URI_MAP
#		Any number of regexes and associated action name.
#	ACTION_NAME
#		URI_MAP
#		ACTION CODE ref or ID
#		VALIDATIONS specific to action
# 

use strict;

use Exporter;
#use Qoan::Helper;

our( $VERSION, @ISA, @EXPORT, @EXPORT_OK );

# Hashes for request components.
our( %request, %session, %user );

$VERSION = '0.01';

@ISA = qw| Exporter |;

@EXPORT = @EXPORT_OK = qw| request  session  user |;



sub get_action_map
{
	return;
}


sub controller_env
{
	return;
}


sub controller_report
{
	return;
}


sub controller_warn
{
	return;
}


1;
