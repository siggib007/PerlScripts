#!/usr/bin/perl

use strict;
use warnings;
use Opsware::NAS::Connect;
###############################################################################
# BEGIN CONFIG SECTION - Make changes here
###############################################################################
my $DEBUG = 0;
my $CONFIG = {
    '_default_' => { # the name '_default_' is hard-coded; do not change
        'match_model' => undef, # never match on this, used only as defaults
        'prompt' => qr/[\-\w+\.:\/]+(?:\([^\)]+\))?[>\#]\s?$/m,
        'error' => qr/^\%/, # Error messages prefix
        'collect' => [
            'show running-config interface {interface}',
            'show interface {interface}',
        ],
        'init' => [
            'terminal length 0',
        ],
        'activate' => [
            'configure terminal',
            'interface {interface}',
            'no shutdown',
            'exit',
            'end',
            'write memory',
        ],
        'deactivate' => [
            'configure terminal',
            'interface {interface}',
            'shutdown',
            'exit',
            'end',
            'write memory',
        ],
        'activate_rules' => undef,
        'deactivate_rules' => undef,
    },
    "cisco_4900" => {
        'match_model' => qr/WS-C49[0-9]{2}([\-EM](\-F|10GE)?)?/,
        'activate_rules' => [
            'description {description}',
            'switchport mode access',
            'storm-control broadcast include multicast',
            qr/^storm-control broadcast level [0-5](\.[0-5]{1,2})?$/,
            'storm-control action trap',
            'shutdown',
        ],
        'deactivate_rules' => [
            qr/^[\S]+ is (?!administratively )down/
        ],
    },
    'nexus' => {
        'match_model' => undef, # never match on this, used only for inclusion
        'activate' => [
            'configure terminal',
            'interface {interface}',
            'no shutdown',
            'exit',
            'end',
            'copy running-config startup-config',
        ],
        'deactivate' => [
            'configure terminal',
            'interface {interface}',
            'shutdown',
            'exit',
            'end',
            'copy running-config startup-config',
        ],
        'activate_rules' => [
            qr/^[\S]+ is down \(Administratively down\)$/,
            'description {description}',
            qr/^storm-control broadcast level [0-5](\.[0-5]{1,2})?$/,
            qr/^storm-control multicast level [0-5](\.[0-5]{1,2})?$/,
        ],
        'deactivate_rules' => [
            qr/^[\S]+ is down \((?!Administratively)/,
        ],
    },
    'nexus_5k' => {
        'match_model' => qr/^Nexus5\d{3}/,
        'include' => 'nexus',
        
    },
    'nexus_7k' => {
        'match_model' => qr/^Nexus7\d{3}/,
        'include' => 'nexus',
    },
    'nexus_3k' => {
        'match_model' => qr/Nexus\s?3\d{3}$/,
        'include' => 'nexus',
    },
    'ASR9K' => {
        'match_model' => qr/ASR-9\d{3}/,
        'activate' => [
            'configure terminal',
            'interface {interface}',
            'no shutdown',
            'exit',
            'commit',
            'end',
        ],
        'deactivate' => [
            'configure terminal',
            'interface {interface}',
            'shutdown',
            'exit',
            'commit',
            'end',
        ],
        'activate_rules' => [
            'shutdown',
        ],
        'deactivate_rules' => [
            qr/^[\S]+ is (?!administratively )down/
        ],
    },
    'NCS6K' => {
        'match_model' => qr/NCS-6\d{3}/,
        'activate' => [
            'configure terminal',
            'interface {interface}',
            'no shutdown',
            'exit',
            'commit',
            'end',
        ],
        'deactivate' => [
            'configure terminal',
            'interface {interface}',
            'shutdown',
            'exit',
            'commit',
            'end',
        ],
        'activate_rules' => [
            'shutdown',
        ],
        'deactivate_rules' => [
            qr/^[\S]+ is (?!administratively )down/
        ]
    },
    'Legacy' => {
        'match_model' => qr/^CISCO76/,
        'activate' => [
            'configure terminal',
            'interface {interface}',
            'no shutdown',
            'exit',
            'end',
            'write memory',
        ],
        'deactivate' => [
            'configure terminal',
            'interface {interface}',
            'shutdown',
            'exit',
            'end',
            'write memory',
        ],
        'activate_rules' => [
            'shutdown',
        ],
        'deactivate_rules' => [
            qr/^[\S]+ is (?!administratively )down/
        ],
    },
};
###############################################################################
# END CONFIG SECTION
###############################################################################

###############################################################################
# Beware, changes have consequences below this line!
###############################################################################
#my ($device, $interface, $description,
#    $action, $username, $password, $device_model);
my $action = undef;
my $options = {
    'na_host' => 'localhost',
    'na_port' => 8023,
    'timeout' => 30,
    'device' => undef,
    'device_model' => undef,
    'interface' => undef,
    'description' => undef,
    'username' => undef,
    'password' => undef,
    'debug' => 0,
};
if ($ARGV[0]) { # Run from CLI for testing/debugging
    use Getopt::Long;
    use Pod::Usage;
    my $help = undef;
    if ($ARGV[0] eq 'activate' || $ARGV[0] eq 'deactivate') {
        $action = shift(@ARGV);
    } else {
        warn("First argument must be the action: activate or deactivate.");
        pod2usage({ -verbose => 5, -exitval => 1 });
    }
    GetOptions(
        'hostname=s' => \$options->{'na_host'},
        'port=i' => \$options->{'na_port'},
        'device=s' => \$options->{'device'},
        'model=s' => \$options->{'device_model'},
        'interface=s' => \$options->{'interface'},
        'description=s' => \$options->{'description'},
        'timeout=i' => \$options->{'timeout'},
        'username=s' => \$options->{'username'},
        'password=s' => \$options->{'password'},
        'debug' => \$options->{'debug'},
        'help|?' => \$help
    ) or pod2usage({ -verbose => 5, -exitval => 1 });
    
    pod2usage({ -verbose => 5, -exitval => 0 }) if $help;
} else {
    # merge with 'options'
    $options = {%{$options}, %{{
        'na_port' => '$tc_proxy_telnet_port$',
        'device' => '#$tc_device_id$',
        'device_model' => '$tc_device_model$',
        'interface' => '$Interface$',
        'description' => '$Description$',
        'username' => '$tc_user_username$',
        'password' => '$tc_user_password$',
    }}}; 
    $action = '$Action$';
}

# make sure action is known
if ($action ne 'deactivate' && $action ne 'activate') {
    die("ERROR: unknown action '$action'\n");
}

# get the right config for this model and replace all the '{...}' placeholders
my $device_config = render_config_template(
    get_device_config($options->{'device_model'}), $options);
if (!$device_config) {
    die("ERROR: Device model '" . $options->{'device_model'} .
        "' not found in config.\n");
}

my $proxy = login($options);
if (!$proxy) {
    die("ERROR: Failed to connect to proxy at '" . $options->{'na_host'} . ":" .
        $options->{'na_port'} . ".\n");
}

my $is_connected = connect_device($proxy, $options->{'device'}, $device_config);
if (!$is_connected) {
    die("ERROR: Failed to connect to device: '" .
        $options->{'device'} . "'.\n");
}

my $interface_data = collect($proxy, $options->{'interface'},
    $device_config);
if (!$interface_data) {
    die("ERROR: Failed to collect data from device '" . $options->{'device'} . 
        "' for interface '" . $options->{'interface'} . "'\n");
}
my $is_valid = validate_interface($interface_data,
    $device_config->{$action . '_rules'});

if ($is_valid) {
    my $configured = configure_interface($proxy, $action, $device_config); 
    if (!$configured) {
        die("ERROR: Failed to configure interface: '" .
            $options->{'interface'} . "' on device '" .
            $options->{'device'} . "'.\n");
    }
} else {
    if ($action eq 'activate') {
        die("ERROR: Interface is not in the correct state or is not " .
            "configured correctly\n");
    } elsif ($action eq 'deactivate') {
        print "INFO: Interface '" . $options->{'interface'} .
            "' is already up/up or administrativley-down\n";
        exit(0);
    } else {
        die("ERROR: It should have been impossible to get here");
    }
}

exit(0);

# Collect data from device
sub collect {
    my $proxy = shift;
    my $interface = shift;
    my $config = shift;
    my @output = ();
    for my $cmd (@{$config->{'collect'}}) {
        $cmd =~ s/\{interface\}/$interface/;
        my @_tmp =$proxy->cmd($cmd);
        # look for error string in cli output
        my $error = find_pattern_in_list($config->{'error'}, \@_tmp);
        if ($error) {
            warn("WARNING: $error\n");
            return 0;
        }
        push (@output, @_tmp);
    }
    return \@output;
}

sub configure_interface {
    my $proxy = shift;
    my $action = shift; # 'activate' or 'deactivate';
    my $config = shift;
    
    for my $cmd (@{$config->{$action}}) {
        print "INFO: Running configuration command: $cmd\n";
        $proxy->cmd("$cmd\r\n");
    }
    return 1;
}

sub connect_device {
    my $proxy = shift;
    my $device = shift;
    my $config = shift;
    my $connected = $proxy->connect($device, $config->{'prompt'});
    if ($connected) {
        for my $command ( @{$config->{'init'}} ) {
            if ($command =~ qr/(conf|edit|write|copy)/) {
                die("ERROR: Cannot make changes inside init!\n");
            } else {
                $proxy->cmd($command);
            }
        }
    }
    return $connected;
}

sub disconnect_device {
    my $proxy = shift;
    $proxy->disconnect();
    return 1;
}

#
# Given a pattern, find the matching element in a list
# If the pattern a string and is prefixed by a '!' then a match will return
# false.
#
# Returns matched element in list or 'undef' if not found 
#
# Examples:
# "!no shutdown" == "no shutdown"; returns false
# "no shutdown" == "no shutdown"; returns true
# "qr/^vlan [0-9\,\s]+$/" =~ "vlan 100"; returns true
#
sub find_pattern_in_list {
    my $pattern = shift;
    my $list = shift;
    my $matched = undef;
    my $negative = 0;
    
    # should we switch on negative mode?
    if (substr($pattern, 0, 1) eq '!') {
        $pattern = substr($pattern, 1);
        $negative = 1;
        $matched = $pattern;
    }
    
    for my $line (@{$list}) {
        $line = trim($line);
        if ((ref($pattern) eq 'Regexp' && $line =~ $pattern)
            || $line eq $pattern) {
            
            # negative mode reverse the result if matched
            if ($negative == 1) {
                $matched = undef;
            } else {
                $matched = $line;
            }
            last;
        }
    }
    return $matched;
}

# Associate the device model to the appropriate configuration entry
#
# Limitations: can't recursively include config blocks.
sub get_device_config {
    my $model = shift;
    
    my $_config = undef;
    foreach my $family (keys %{$CONFIG}) {
        if (!exists $CONFIG->{$family}->{'match_model'}
            || !$CONFIG->{$family}->{'match_model'}) {
            next;
        }
        my $matcher = $CONFIG->{$family}->{'match_model'};
        if ($model =~ $matcher) {
            $_config = $CONFIG->{$family};
            if (exists $_config->{'include'}) {
                my $include = $_config->{'include'};
                
                if (exists $CONFIG->{$include}
                    && ref($CONFIG->{$include}) eq 'HASH') {
                    
                    $_config = {%{$CONFIG->{$include}}, %{$_config}};
                }
            }
            $_config = {%{$CONFIG->{'_default_'}}, %{$_config}};
            last; # exit on first match
        }
    }
    return $_config;
}

sub login {
    my $options = shift;
    my $proxy = Opsware::NAS::Connect->new(-user => $options->{'username'},
        -pass => $options->{'password'}, -host => $options->{'na_host'},
        -port => $options->{'na_port'}, -debug => $options->{'debug'});
    $proxy->login();
    return $proxy;
}

sub logout {
    my $proxy = shift;
    $proxy->logout();
    return 1;
}

sub render_config_template {
    my $config = shift;
    my $replacements = shift;
    if (ref($config) ne 'HASH') {
        return undef;
    }
    foreach my $key (keys %{$config}) {
        if (ref($config->{$key}) eq 'ARRAY') {
            my @tmp = ();
            foreach my $elem (@{$config->{$key}}) {
                push(@tmp, render_template($elem, $replacements));
            }
            @{$config->{$key}} = @tmp;
        } elsif (ref($config->{$key}) eq "HASH") {
            $config->{$key} = render_config_template($config->{$key},
                $replacements);
        } elsif (!ref($config->{$key})) {
            $config->{$key} = render_template($config->{$key}, $replacements);
        } 
    }
    return $config;
}

# simple template engine.  Replace {...} in text with real values
sub render_template {
    my $text = shift;
    my $replacements = shift;
    for my $key (keys %{$replacements}) {
        my $replacement = $replacements->{$key};
        if (index($text, "{$key}") != -1) {
           $text =~ s/\{$key\}/$replacement/;
        }
    }
    return $text;
}

#
# Removes white space from string
#
sub trim {
    my $str = shift;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

sub validate_interface {
    my $data = shift;
    my $rules = shift;
    for my $rule (@{$rules}) {
        my $matched = find_pattern_in_list($rule, $data);
        if (!$matched) {
            warn("WARNING: Failed to match on rule '$rule'\n");
            return 0;
        }
    }
    return 1;
}

# make sure we close all connections, even when dying.
END {
    if ($proxy) {
        print "INFO: Disconnecting from device...\n";
        disconnect_device($proxy);    
        print "INFO: Logging out of the HPNA proxy...\n";
        logout($proxy);
    }
}

__END__

=head1 NAME

Active or deactivate a pre-provisioned interface.

=head1 DESCRIPTION

This program will log into the specified device using the HPNA proxy.  It will
then read the current interface configuration from the device and validate it
against the specified rules.  If, the interface is configured correctly, it will
then be activated or deactivated

=head1 AUTHOR

    Jesse R. Mather <jesse.mather@t-mobile.com>

head1 CHANGES
1/31/2014 - jmather5 - Fixed prompt regex to not match when a device is copying
                       a file.
                       
=head1 USAGE

cisco_generic_port_activator.pl <activate|deactivate> options

Options:
    --hostname=<hostname|ipaddr>
    [--port=<integer>]
    [--timeout=<seconds>]
    --device=<#id|name|ipaddr>
    --model=<string>
    --interface=<string>
    --description=<string>
    --username=<string>
    --password=<string>
    [--debug=<0-25>]
    [--help|?]

=head1 OPTIONS

=over 8

=item B<--help>

Prints the help message and exits.

=item B<--host>

HPNA hostname or IP address

=item B<--port>

HPNA proxy port (default: 8023)

=item B<--timeout>

HPNA proxy timeout (default: 30 seconds)

=item B<--device>

Device ID (prefixed by '#'), hostname or IP adddress

=item B<--model>

Device model

=item B<--interface>

Interface to activate or desctivate

=item B<--description>

Interface's description

=item B<--username>

HPNA username

=item B<--password>

HPNA password

=item B<--debug>

Turn on proxy debugging and set level(accepts intergers: 0-25)

=back