package FusionInventory::Agent::Task::Inventory::Input::Win32::USB;

use strict;
use warnings;

use FusionInventory::Agent::Tools::Generic;
use FusionInventory::Agent::Tools::Win32;

sub isEnabled {
    return 1;
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};

    foreach my $device (_getDevices(logger => $params{logger}, datadir => $params{datadir})) {
        $inventory->addEntry(
            section => 'USBDEVICES',
            entry   => $device
        );
    }
}

sub _getDevices {
    my @devices;
    my $seen;

    foreach my $device (_getDevicesFromWMI(@_)) {
        next if $device->{VENDORID} =~ /^0+$/;

        # avoid duplicates
        next if $seen->{$device->{SERIAL}}++;

        # pseudo serial generated by windows
        delete $device->{SERIAL} if $device->{SERIAL} =~ /&/;

        my $vendor = getUSBDeviceVendor(id => $device->{VENDORID}, @_);
        if ($vendor) {
            $device->{MANUFACTURER} = $vendor->{name};

            my $entry = $vendor->{devices}->{$device->{PRODUCTID}};
            if ($entry) {
                $device->{CAPTION} = $entry->{name};
            }
        }

        push @devices, $device;
    }

    return @devices;
}

sub _getDevicesFromWMI {
    my @devices;

    foreach my $object (getWMIObjects(
        class      => 'CIM_LogicalDevice',
        properties => [ qw/DeviceID Name/ ]
    )) {
        next unless $object->{DeviceID} =~ /^USB\\VID_(\w+)&PID_(\w+)\\(.*)/;

        push @devices, {
            NAME      => $object->{Name},
            VENDORID  => $1,
            PRODUCTID => $2,
            SERIAL    => $3
        };
    }

    return @devices;
}

1;
