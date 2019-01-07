#
# Unofficial PowerShell wrapper for the BluOS Web/REST API,
# served by Bluesound multi-room music devices.
# See: https://nadelectronics.com/bluos/
#
# Bluesound is an award-winning wireless hi-res sound system.
# (https://www.bluesound.com/)
#
# BluOS is an advanced operating system and music management software.
# (https://nadelectronics.com/bluos/)
#
# Sources:
#   - https://helpdesk.bluesound.com/discussions/viewtopic.php?f=4&t=2293&sid=e011c0bdf3ede3ea1aeb057de63c1da8
#   - https://github.com/venjum/bluesound
#

$RestApiPort = "11000"
$WebApiPort = "80"

function Blu-Invoke()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device = $Device,
		
		[string] $Path,
		
		[hashtable] $Options,
		
		[ValidateSet('Get', 'Post', 'Delete')]
		[string] $Method = 'Get',
		
		[hashtable]$Headers,
		
		[switch] $WebApi # Use Web API endpoint instead of the default REST API endpoint
	)
	#$pathAndQuery = [uri]::EscapeUriString($Path).Replace("+", "%2B").Replace("#", "%23") # Additional escaping for '+' and '#' characters (but not sure if necessary), Uri escapes everything else for us (including %20 for space).
	$pathAndQuery = $Path
	if ($Method.ToLower() -eq 'post') {
		$body = $Options
	} else {
		if ($Options) {
			$pathAndQuery += "?"
			foreach ($param in $Options.GetEnumerator())
			{
				$pathAndQuery += [uri]::EscapeDataString($param.Key) + "="
				if ($param.Value -is [array]) {
					# Escape individual array items and then combine with comma ',' character (not escape the comma)
					$escapedValues = @()
					foreach($paramValue in $param.Value) {
						$escapedValues += [uri]::EscapeDataString($paramValue)
					}
					$pathAndQuery += $escapedValues -join ','
				} else {
					$pathAndQuery += [uri]::EscapeDataString($param.Value)
				}
				$pathAndQuery += "&"
			}
			$pathAndQuery = $pathAndQuery.Remove($pathAndQuery.Length - 1)
		}
	}
	$ApiUrl = "http://${Device}:$(if($WebApi){${WebApiPort}}else{${RestApiPort}})"
	if ($PSCmdlet.ShouldProcess("${Device}", "Invoke")) {
		# REAL MODE:
		Invoke-RestMethod "${ApiUrl}/${pathAndQuery}" -Method $Method -Headers $Headers -Body $body
	} else {
		# TEST MODE:
		Write-Host "Invoke-RestMethod ${ApiUrl}/${pathAndQuery} -Method $Method -Headers $Headers -Body $body"
		if ($Headers) {
			Write-Host -NoNewline "Headers:"
			$Headers | Format-Table -HideTableHeaders
		}
		if ($Body) {
			Write-Host -NoNewline "Body:"
			$Body | Format-Table -HideTableHeaders
		}
	}
}

#
# Player status
#

function Blu-SyncStatus()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	(Blu-Invoke $Device "SyncStatus").SyncStatus
}
function Blu-Status()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[Nullable[uint32]] $Timeout
	)
	$Options = @{}
	if ($Timeout -ne $null) {
		$Options['timeout'] = $Timeout
	}
	(Blu-Invoke $Device "Status" $Options).status
}

#
# Playback
#

function Blu-State()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	(Blu-Status $Device).status.state
}
function Blu-CanSeek()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	(Blu-Status $Device).status.canSeek
}
function Blu-Play()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		[Nullable[uint32]] $Item,
		[Nullable[uint32]] $Seek
	)
	# Arguments Item and Seek are optional, default is to play from current position.
	# Item is song number in current play queue.
	# Seek is position in seconds of current track.
	$Options = @{}
	if ($Item -ne $null) {
		$Options['id'] = $Item
	}
	if ($Seek -ne $null) {
		$Options['seek'] = $Seek
	}
	(Blu-Invoke $Device "Play" $Options).state
}
function Blu-PlayUrl()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[Parameter(Mandatory=$True)]
		$Url,
		
		[switch] $LegacyApi
	)
	# To play a custom stream url directly.
	# See Blu-RadioAddPreset for storing the custom stream url as a favorite,
	# using the Custom Station function in TuneIn, where you can add any streaming
	# url as a custom "radio station"
	# Implementation notes:
	# This functionality seems to be no longer officially supported, as it has
	# been replaced by the Custom Station function in TuneIn,: "TuneIn Custom Stations
	# replaces the option in BluOS 1.20.x and earlier versions to enter a custom
	# URL in the Configure Player Menu.").
	# I have found two methods that still works: One using the REST API, simply
	# requesting Play with the url as the parameter. The other is using the
	# basic web interface: http://<ip>/playurl will give you an interactive input form,
	# and an HTTP Post request with parameter "url=" containing the actual media URL will trigger
	# the playback.
	if ($LegacyApi) {
		Blu-Invoke $Device "playurl" @{'url'=$Url} -Method 'Post' -WebApi
	} else {
		Blu-Invoke $Device "Play" @{'url'=$Url}	
	}	
}
function Blu-Resume()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	# TODO: Same as Blu-Play, but always from current position - so just resume from pause state.
	#       Should have identical effect as "Blu-Pause -Toggle", assuming current state is paused!
	(Blu-Invoke $Device "Play").state
}
function Blu-Pause()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[switch]$Toggle
	)
	if ($Toggle)
	{
		# TODO: Return information of what is the resulting state (play or pause)!
		(Blu-Invoke $Device "Pause" @{'toggle' = 1}).state
	}
	else
	{
		(Blu-Invoke $Device "Pause").state
	}
}
function Blu-Stop()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	# Implementation note: Official app only supports play and pause,
	# not stop. When device is activated from "vacation mode" it is
	# in the stopped state.
	(Blu-Invoke $Device "Stop").state
}
function Blu-Skip()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	# TODO: Are there parameters to be able to skip more than one entry?
	(Blu-Invoke $Device "Skip").id
}
function Blu-Back()
{
	[CmdletBinding(SupportsShouldProcess=$True)] param()
	# TODO: Are there parameters to be able to move back more than one entry?
	(Blu-Invoke "Back").id
}
function Blu-Playqueue()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		[Nullable[uint32]] $Start,
		[Nullable[uint32]] $End
	)
	# Arguments Start and End are optional, default is to return all items.
	# Start and End is range of a subset, from given start index to (and including)
	# given end index, where the indexes are zero indexed. For example
	# Start=0 and End=0 gives a single, the first, entry of the queue.
	$Options = @{}
	if ($Start -ne $null) {
		$Options['start'] = $Start
	}
	if ($End -ne $null) {
		$Options['end'] = $End
	}
	(Blu-Invoke $Device "Playlist" $Options).playlist
}
function Blu-PlayqueueSave()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[Parameter(Mandatory=$True)]
		[string] $Name
	)
	# Save current playqueue as new playlist
	Blu-Invoke $Device "Save" @{'name'=$Name}
}
function Blu-PlayqueueClear()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	Blu-Invoke $Device "Clear"
}
function Blu-Volume()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[ValidateRange(0, 100)] [Nullable[byte]] $SetPercent
	)
	# Argument SetPercent is optional, default is to return current volume in percent and dB.
	# SetPercent specifies new volume, always in percent, to change to.
	# Implementation note: The response when changing volume indicates new volume in percent,
	# but not dB. Current volume in percent (but not dB) can also be returned from the Status
	# and SyncStatus methods.
	if ($SetPercent -ne $null) {
		$Options = @{'level'=$SetPercent}
		$Response = Blu-Invoke $Device "Volume" $Options
		[pscustomobject]@{'percent'=$Response.volume.'#text'; 'db'=$Response.volume.db}
	} else {
		(Blu-Invoke $Device "Volume" $Options).volume
	}
}
function Blu-Repeat()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[ValidateSet('Playqueue', 'Track', 'Off')] $Mode
	)
	# Argument Mode is optional, default is to return current state.
	# Implementation note: Current state can also be returned from the Status method.
	$Options = @{}
	$Modes = (Get-Variable "Mode").Attributes.ValidValues
	if ($Mode) {
		$ModeCaseSensitive = $Modes -eq $Mode | Select-Object -First 1
		$State = $Modes.IndexOf($ModeCaseSensitive)
		$Options = @{'state' = $State }
	}
	$Response = Blu-Invoke $Device "Repeat" $Options
	$Modes[$Response.playlist.repeat]
}
function Blu-Shuffle()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[ValidateSet('Off', 'On')] $Mode
	)
	# Argument Mode is optional, default is to return current state.
	# Implementation note: The /Shuffle request without parameters does not
	# return the current state, but turns off shuffle. To get the current state
	# we must therefore fetch it from the /Status request instead!
	$Modes = (Get-Variable "Mode").Attributes.ValidValues
	if ($Mode) {
		$ModeCaseSensitive = $Modes -eq $Mode | Select-Object -First 1
		$State = $Modes.IndexOf($ModeCaseSensitive)
		$Response = Blu-Invoke $Device "Shuffle" @{'state' = $State }
		$Modes[$Response.playlist.shuffle]
	} else {
		$Response = Blu-Status $Device
		$Modes[$Response.status.shuffle]
	}
}

#
# Player grouping
#

function Blu-PlayerGroupAdd()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		[string] $GroupName,
		[string] $SlaveIP
	)
	(Blu-Invoke $Device "AddSlave" @{'slave' = $SlaveIP; 'group' = $GroupName }).addSlave.slave
}
function Blu-PlayerGroupRemove()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		[string] $SlaveIP
	)
	Blu-Invoke $Device "RemoveSlave" @{'slave' = $SlaveIP} | Out-Null
}

#
# Navigation
#

function Blu-Services()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	(Blu-Invoke $Device "Services").services
}
function Blu-Radios()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	# Implementation notes:
	# Request without service parameter defaults to "service=TuneIn".
	# Implemented request with service parameter "service=Capture"
	# as a separate moethod: Blu-Sources.
	(Blu-Invoke $Device "RadioBrowse").radiotime.item
}
function Blu-RadioAddPreset()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,

		[Parameter(Mandatory=$True)]
		$Name,

		[Parameter(Mandatory=$True)]
		$Url,
		
		$Service = "TuneIn"
	)
	# Add custom stream URL as a radio preset (custom station) in TuneIn.
	# See also Blu-PlayUrl.
	(Blu-Invoke $Device "RadioAddPreset" @{'name'=$Name; 'url'=$Url; 'service'=$Service}).favorite
}
function Blu-RadioPresets()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		$Service = "TuneIn"
	)
	# TODO: We just want the individual items, not the strange category elements, but as plain "objects"!
	(Blu-Invoke $Device "RadioPresets" @{'service'=$Service}).SelectNodes("/radiotime/category/item")
}
function Blu-RadioAddPreset()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,

		[Parameter(Mandatory=$True)]
		$Name,

		[Parameter(Mandatory=$True)]
		$Url,
		
		$Service = "TuneIn"
	)
	# Add custom stream URL as a radio preset (custom station) in TuneIn.
	# See also Blu-PlayUrl.
	(Blu-Invoke $Device "RadioAddPreset" @{'name'=$Name; 'url'=$Url; 'service'=$Service}).favorite
}
function Blu-RadioDeletePreset()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
	
		$Service = "TuneIn"
	)
	# TODO: Seems there is a RadioDeletePreset request, but have not yet found out
	# what parameters to use to identify the preset to delete!
	#(Blu-Invoke $Device "RadioDeletePreset" @{'name'=$Name; 'url'=$Url; 'service'=$Service}).favorite
}
function Blu-Sources()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	# Request without service parameter defaults to "service=TuneIn",
	# with service=Capture we get other inputs (which are enabled/connected).
	(Blu-Invoke $Device "RadioBrowse" ${'service' = 'Capture'}).radiotime.item
}
function Blu-Playlists()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		$Service = "LocalMusic"
	)
	# Request without service parameter defaults to "service=LocalMusic"
	(Blu-Invoke $Device "Playlists" @{'service'=$Service}).playlists.name
}
function Blu-Presets()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	(Blu-Invoke $Device "Presets").presets.preset
}
function Blu-SwitchToPreset()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[Parameter(Mandatory=$True)]
		[uint32]$Id
	)
	# TODO/Implementation notes:
	# Response is different depending on the type of preset,
	# e.g. for TuneIn it retuns the state value "stream",
	# while for a Tidal playlist it returns a different xml response
	# indicating the service and number of entries loaded.
	Blu-Invoke $Device "Preset" @{'id'=$Id}
}
function Blu-SwitchToPlaylist()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	# TODO:
	# http://192.168.1.38:11000/Genres?service=LocalMusic (Library)
}
function Blu-SwitchToRadio()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	# TODO:
	#http://192.168.1.38:11000/RadioBrowse?service=TuneIn (TuneIn Radio)
}
function Blu-SwitchSource()
{
	# TODO: Blu-Source returns the complete list, with URL and image properties
	# of each supported service!
	# TODO: Escape the image path or not? The following should work:
	# http://192.168.1.38:11000/Play?url=Capture%3Ahw%3A1%2C0%2F1%2F25%2F2&preset_id&image=/images/inputIcon.png (Optical Input)
	# http://192.168.1.38:11000/Play?url=Capture%3Abluez%3Abluetooth&preset_id&image=/images/BluetoothIcon.png (Bluetooth Input)
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[Parameter(Mandatory=$True)]
		[ValidateSet('Optical', 'Bluetooth', 'Spotify', 'RadioParadise')] $Source
	)
	$ServicePath = ""
	$Image = ""
	if ($Source -eq "Optical") {
		$ServicePath = 'Capture:hw:1,0/1/25/2'
		$Image = '/images/inputIcon.png'
	}
	elseif ($Source -eq "Bluetooth") {
		$ServicePath = 'Capture:bluez:bluetooth'
		$Image = '/images/BluetoothIcon.png'
	}
	elseif ($Source -eq "Spotify") {
		$ServicePath = 'Capture:spotify:play'
		$Image = '/images/SpotifyIcon.png'
	}
	elseif ($Source -eq "RadioParadise") {
		$ServicePath = 'Capture:RadioParadise:http://stream-tx3.radioparadise.com/aac-320'
		$Image = '/images/ParadiseRadioIcon.png'
	}
	Blu-Invoke $Device "Play" @{'url' = $ServicePath; 'preset_id' = ''; 'image' = $Image }
}
function Blu-Search()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[Parameter(Mandatory=$True)] $Query,
		$Service = "LocalMusic"
	)
	# Request without service parameter defaults to "service=LocalMusic"
	(Blu-Invoke $Device "Search" @{'expr'=$Query; 'service'=$Service}).search
}
function Blu-RadioSearch()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[Parameter(Mandatory=$True)] $Query,
		$Service = "TuneIn"
	)
	# Request without service parameter defaults to "service=LocalMusic"
	(Blu-Invoke $Device "RadioSearch" @{'expr'=$Query; 'service'=$Service}).radiotime.item
}
function Blu-Genres()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		$Service = "LocalMusic"
	)
	# Request without service parameter defaults to "service=LocalMusic"
	(Blu-Invoke $Device "Genres" @{'service'=$Service}).genres.genre
}
function Blu-Artwork()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	# TODO
	(Blu-Invoke $Device "Artwork" @{'service'="LocalMusic"; 'artist' = "?"; 'album' = "?"}).artwork
}
function Blu-Diagnostics()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	Blu-Invoke $Device "diag" @{'print'=1} -WebApi
}

#
# Other Player functionality
#

function Blu-RoomName()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	# TODO: Can be updated as well, but have not implemented that here yet.
	(Blu-SyncStatus $Device).name
}
function Blu-ModelName()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	(Blu-SyncStatus $Device).modelName
}
function Blu-Audiomodes()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	(Blu-Invoke $Device "audiomodes").audiomode	
}
function Blu-BluetoothSetting()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[ValidateSet('manual', 'automatic', 'guest', 'off')] $Mode
	)
	# Argument Mode is optional, default is to return current state.
	$Modes = (Get-Variable "Mode").Attributes.ValidValues
	if ($Mode) {
		$ModeCaseSensitive = $Modes -eq $Mode | Select-Object -First 1
		$State = $Modes.IndexOf($ModeCaseSensitive)
		$Modes[(Blu-Invoke $Device "audiomodes" @{'bluetoothAutoplay'=$State} -Method 'Post').audiomode.bluetoothAutoplay]
	} else {
		$Modes[(Blu-Audiomodes $Device).bluetoothAutoplay]
	}
}
function Blu-Brightness()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[ValidateSet('default', 'dim', 'off')]
		[string] $Brightness
	)
	Blu-Invoke $Device "ledbrightness" @{'brightness'=$Brightness} -Method 'Post' -WebApi
}
function Blu-Sleep()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[switch] $Set
	)
	# To change sleep time, it must be invoked with argument -Set, and for each
	# time it steps through the settings: 15, 30, 45, 60, 90 minutes, and off. 
	if ($Set) {
		(Blu-Invoke $Device "Sleep").sleep
	} else {
		(Blu-Status $Device).status.sleep
	}
}
function Blu-Alarms()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device
	)
	(Blu-Invoke $Device "Alarms").alarms.alarm
}
function Blu-AlarmSet()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[Nullable[uint32]] $Id, # Id of existing alarm to modify, skip if creating new!
		$Enable = 1, # Always 1 from GUI, not sure if setting it to 0 will disable it?
		$Hour = 8,
		$Minute = 30,
		$Days = "00000000", # Bit string representing weekdays (SMTWTFS)
		$Timeout = 0, # Minutes of alarm before turning off, 0 means never.
		$Volume = 0, # Volume in percent
		$FadeIn = 0, # 0 or 1
		$Sound = "Current play queue or station",
		$Image = "img/cover.png",
		$Url = "undefined",
		$TimeZone = "Europe/Oslo"
	)
	# TODO: Untested and needs refactoring!
	$Options = @{
		'enable' = 1
		'hour' = $Hour
		'minute' = $Minute
		'days' = $Days
		'duration' = $Timeout
		'volume' = $Volume
		'fadeIn' = $FadeIn
		'sound' = $Sound
		'image' = $Image
		'url' = $Url
		'tz' = $TimeZone
	}
	if ($Id -ne $null) {
		$Options['id'] = $Id
	}
	(Blu-Invoke $Device "Alarms" $Options).alarms.alarm
}
function Blu-AlarmDelete()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[Parameter(Mandatory=$True)]
		$Id
	)
	$Options = @{'id'=$Id;'delete'=1}
	(Blu-Invoke $Device "Alarms" $Options).alarms.alarm
}
function Blu-Reboot()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory=$True, HelpMessage="The hostname or IP address of the BluOS device to control")]
		[string] $Device,
		
		[switch] $Force
	)
	# Reboot the player device. An interactive configuration prompt will be
	# shown, unless argument Force is specified.
	# Implementation notes:
	# Using the basic web interface, http://<ip>/reboot will give you an interactive user interface
	# with buttons Yes and No (parameter "noheader=1" can be added for an even more minimalistic and
	# stand-alone web interface, without the navigation menu on top), and an HTTP Post request with
	# parameter "yes" will trigger the actual reboot.
	if ($Force -or $PSCmdlet.ShouldContinue("Are you sure you want to reboot player ${Device}", "Confirm reboot")) {
		Blu-Invoke $Device "reboot" @{'noheader'=1; 'yes'=1} -Method 'Post' -WebApi
	}
}