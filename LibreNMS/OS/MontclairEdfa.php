<?php
/**
 * MontclairEDFA.php
 *
 * Montclair EDFA
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * @link       https://www.librenms.org
 *
 * @copyright  2022 Nick Peelman
 * @author     Nick Peelman <nick@peelman.us>
 */

namespace LibreNMS\OS;

use App\Models\Device;
use LibreNMS\Interfaces\Discovery\OSDiscovery;
use LibreNMS\OS;

class MontclairEdfa extends OS implements OSDiscovery
{
    public function discoverOS(Device $device): void
    {
        $data = snmp_get_multi($this->getDeviceArray(), [
            'Montclair-MIB::devicePartNumber.0',
            'Montclair-MIB::deviceSerialNumber.0',
            'Montclair-MIB::deviceFirmwareVersion.0',
        ], '-OQUs');

        $device->hardware = $data[0]['devicePartNumber'] ?? null;
        $device->serial = $data[0]['deviceSerialNumber'] ?? null;
        $device->version = $data[0]['deviceFirmwareVersion'] ?? null;
    }
}
