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
param
(
	[Parameter(HelpMessage='Default hostname or IP address of the BluOS device to control')]
	[string] $Device,

	[Parameter(HelpMessage='Port number of the REST API on the BluOS device, used for the majority of functions')]
	[uint16] $RestApiPort = 11000,

	[Parameter(HelpMessage='Port number for Web API on the BluOS device, used for a limited set of functions')]
	[uint16] $WebApiPort = 80
)

function Blu-Invoke()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[string] $Path,
		
		[hashtable] $Options,
		
		[ValidateSet('Get', 'Post', 'Delete')]
		[string] $Method = 'Get',
		
		[hashtable] $Headers,
		
		[switch] $WebApi, # Use Web API endpoint instead of the default REST API endpoint

		[switch] $RawResponse
	)
	#$PathAndQuery = [uri]::EscapeUriString($Path).Replace("+", "%2B").Replace("#", "%23") # Additional escaping for '+' and '#' characters (but not sure if necessary), Uri escapes everything else for us (including %20 for space).
	$PathAndQuery = $Path
	if ($Method.ToLower() -eq 'post') {
		$Body = $Options
	} elseif ($Options) {
		$PathAndQuery += "?"
		foreach ($param in $Options.GetEnumerator()) {
			$PathAndQuery += [uri]::EscapeDataString($param.Key) + "="
			if ($param.Value -is [array]) {
				# Escape individual array items and then combine with comma ',' character (not escape the comma)
				$EscapedValues = @()
				foreach($paramValue in $param.Value) {
					$EscapedValues += [uri]::EscapeDataString($paramValue)
				}
				$PathAndQuery += $EscapedValues -join ','
			} else {
				$PathAndQuery += [uri]::EscapeDataString($param.Value)
			}
			$PathAndQuery += "&"
		}
		$PathAndQuery = $PathAndQuery.Remove($PathAndQuery.Length - 1)
	}
	$ApiUrl = "http://${Device}:$(if($WebApi){${WebApiPort}}else{${RestApiPort}})"
	Write-Verbose "Invoke-RestMethod ${ApiUrl}/${PathAndQuery} -Method ${Method}$(if($Headers){" -Headers $($Headers | ConvertTo-Json -Compress)"})$(if($Body){" -Body $($Body | ConvertTo-Json -Compress)"})"
	if ($PSCmdlet.ShouldProcess("${Device} ${Method} request ${PathAndQuery}", 'Invoke')) {
		$Response = Invoke-RestMethod "${ApiUrl}/${PathAndQuery}" -Method $Method -Headers $Headers -Body $Body
		if ($Response -is [System.Xml.XmlDocument]) { # Expecing XML from REST API, but not from Web API ($WebApi)
			Write-Verbose $Response.OuterXml
			if ($RawResponse) {
				# Return entire response as is, i.e. typically a complete XmlDocument object.
				$Response
			} else {
				# Instead of returning the complete XmlDocument object, including the xml prolog element,
				# return the XmlElement representing the document element.
				# In addition: If it is a simple element, with no attributes, and only a single XmlText
				# child node, then return the textual value as a plain string instead of the element!
				# Alt 1:
				#$Properties = $_ | Get-Member -MemberType Property
				#if ($Properties.Count -eq 1 -and $Properties[0].Name = '#text') {
				# Alt 2:
				#if ($Response.DocumentElement.Attributes.Count -eq 0 -and $Response.DocumentElement.ChildNodes.Count -eq 1 -and $Response.DocumentElement.ChildNodes[0].Name -eq '#text') {
				# Alt 3:
				if ($Response.DocumentElement.Attributes.Count -eq 0 -and $Response.DocumentElement.ChildNodes.Count -eq 1 -and $Response.DocumentElement.ChildNodes[0] -is [System.Xml.XmlText]) {
					$Response.DocumentElement.ChildNodes[0].Value
				} else {
					$Response.DocumentElement
				}
			}
		} else {
			$Response
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
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	Blu-Invoke -Device $Device -Path SyncStatus
}
function Blu-Status()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[Nullable[uint32]] $Timeout
	)
	$Options = @{}
	if ($Timeout -ne $null) {
		$Options['timeout'] = $Timeout
	}
	Blu-Invoke -Device $Device -Path Status -Options $Options
}

#
# Playback
#

function Blu-State()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	(Blu-Status -Device $Device).state
}
function Blu-CanSeek()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	(Blu-Status -Device $Device).canSeek
}
function Blu-Play()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
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
	Blu-Invoke -Device $Device -Path Play -Options $Options
}
function Blu-PlayUrl()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
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
		Blu-Invoke -Device $Device -Path playurl -Options @{ url = $Url } -Method Post -WebApi
	} else {
		Blu-Invoke -Device $Device -Path Play -Options @{ url = $Url }
	}	
}
function Blu-Resume()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	# TODO: Same as Blu-Play, but always from current position - so just resume from pause state.
	#       Should have identical effect as "Blu-Pause -Toggle", assuming current state is paused!
	Blu-Invoke -Device $Device -Path Play
}
function Blu-Pause()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[switch] $Toggle
	)
	if ($Toggle)
	{
		Blu-Invoke -Device $Device -Path Pause -Options @{ toggle = 1 }
	}
	else
	{
		Blu-Invoke -Device $Device -Path Pause
	}
}
function Blu-Stop()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	# Implementation note: Official app only supports play and pause,
	# not stop. When device is activated from "vacation mode" it is
	# in the stopped state.
	Blu-Invoke -Device $Device -Path Stop
}
function Blu-Skip()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	# TODO: Are there parameters to be able to skip more than one entry?
	Blu-Invoke -Device $Device -Path Skip
}
function Blu-Back()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	# TODO: Are there parameters to be able to move back more than one entry?
	Blu-Invoke -Device $Device -Path Back
}
function Blu-Playqueue()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[Nullable[uint32]] $StartPosition,
		[Nullable[uint32]] $EndPosition
	)
	# Arguments StartPosition and EndPosition are optional zero-based indices into the playqueue,
	# giving a range including the specified start/end. For example Start=0 and End=0 gives a single,
	# the first, entry of the queue. Default start is 0 and end is last entry, without specifying
	# any of them all items will be returned.
	$Options = @{}
	if ($StartPosition -ne $null) {
		$Options['start'] = $StartPosition
	}
	if ($EndPosition -ne $null) {
		$Options['end'] = $EndPosition
	}
	Blu-Invoke -Device $Device -Path Playlist -Options $Options
}
function Blu-PlayqueueListTracks()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[Nullable[uint32]] $StartPosition,
		[Nullable[uint32]] $EndPosition
	)
	(Blu-PlayqueueList -Device $Device -StartPosition $StartPosition -EndPosition $EndPosition).song
}
function Blu-PlayqueueDeleteTrack()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[Parameter(Mandatory=$True)]
		[uint32] $Position
	)
	Blu-Invoke -Device $Device -Path Delete -Options ${ id = $Position }
}
function Blu-PlayqueueMoveTrack()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[Parameter(Mandatory=$True)]
		[uint32] $FromPosition,
		[Parameter(Mandatory=$True)]
		[uint32] $ToPosition
	)
	Blu-Invoke -Device $Device -Path Move -Options ${ old = $FromPosition; new = $ToPosition }
}
function Blu-PlayqueueSave()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[Parameter(Mandatory=$True)]
		[string] $Name
	)
	# Save current playqueue as new playlist
	Blu-Invoke -Device $Device -Path Save -Options @{ name = $Name }
}
function Blu-PlayqueueClear()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	Blu-Invoke -Device $Device -Path Clear
}
function Blu-Volume()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	Blu-Invoke -Device $Device -Path Volume
}
function Blu-VolumeSetPercent()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[ValidateRange(0, 100)] [byte] $Value, # Percent of configured available volume range for the player
		[switch] $TellSlaves
	)
	Blu-Invoke -Device $Device -Path Volume -Options @{ level = $Value; tell_slaves = [int]$TellSlaves.IsPresent }
}
function Blu-VolumeSetDb()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[ValidateRange(-80, 0)] [int16] $Value, # Limited by configured available volume range for the player, default between -80 and 0.
		[switch] $TellSlaves
	)
	Blu-Invoke -Device $Device -Path Volume -Options @{ abs_db = $Value; tell_slaves = [int]$TellSlaves.IsPresent }
}
function Blu-VolumeAdjust()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[byte] $Value = 2, # Relative value in dB, negative is decrease, positive is increase.
		[switch] $TellSlaves
	)
	Blu-Invoke -Device $Device -Path Volume -Options @{ db = $Value; tell_slaves = [int]$TellSlaves.IsPresent }
}
function Blu-VolumeMute()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[switch] $Unmute,
		[switch] $TellSlaves
	)
	Blu-Invoke -Device $Device -Path Volume -Options @{ mute = [int]!$Unmute.IsPresent; tell_slaves = [int]$TellSlaves.IsPresent }
}
function Blu-Repeat()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[ValidateSet('Playqueue', 'Track', 'Off')] $Mode
	)
	# Argument Mode is optional, default is to return current state.
	# Implementation note: Current state can also be returned from the Status method.
	$Options = @{}
	$Modes = (Get-Variable "Mode").Attributes.ValidValues
	if ($Mode) {
		$ModeCaseSensitive = $Modes -eq $Mode | Select-Object -First 1
		$State = $Modes.IndexOf($ModeCaseSensitive)
		$Options = @{ state = $State }
	}
	$Response = Blu-Invoke -Device $Device -Path Repeat -Options $Options
	$Modes[$Response.playlist.repeat]
}
function Blu-Shuffle()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
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
		$Response = Blu-Invoke -Device $Device -Path Shuffle -Options @{ state = $State }
		$Modes[$Response.playlist.shuffle]
	} else {
		$Response = Blu-Status -Device $Device
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
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[string] $GroupName,
		[string] $SlaveIP,
		[ValidateSet('MultiPlayer', 'StereoPair', 'HomeTheater')] [string] $GroupType,
		[string] $SlaveType = 'right'
	)
	$Options = @{ slave = $SlaveIP; group = $GroupName }
	if ($GroupType -eq 'StereoPair') {
		if ($SlaveType -eq 'right') {
			$Options['channelMode'] = 'left'
			$Options['slaveChannelMode'] = 'right'
		} elseif ($SlaveType -eq 'left') {
			$Options['channelMode'] = 'right'
			$Options['slaveChannelMode'] = 'left'
		} else {
			throw "SlaveType in StereoPair must be either 'left' or 'right'"
		}
		Blu-Invoke -Device $Device -Path AddSlave -Options $Options
	} elseif ($GroupType -eq 'HomeTheater') {
		throw "HomeTheater groups not implemented yet - see README.md"
	}
	Blu-Invoke -Device $Device -Path AddSlave -Options $Options
}
function Blu-PlayerGroupRemove()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		[string] $SlaveIP
	)
	Blu-Invoke -Device $Device -Path RemoveSlave -Options @{ slave = $SlaveIP } | Out-Null
}

#
# Navigation
#

function Blu-Services()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	(Blu-Invoke -Device $Device -Path Services).service
}
function Blu-Radios()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	# Request without service parameter defaults to "service=TuneIn".
	# With service=Capture we get other enabled/connected inputs, this request
	# is performed from separate method: Blu-Sources.
	(Blu-Invoke -Device $Device -Path RadioBrowse).item
}
function Blu-RadioPresets()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		$Service = "TuneIn"
	)
	# TODO: We just want the individual items, not the strange category elements, but as plain "objects"!
	(Blu-Invoke -Device $Device -Path RadioPresets -Options @{ service = $Service }).SelectNodes("/radiotime/category/item")
}
function Blu-RadioAddPreset()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,

		[Parameter(Mandatory=$True)]
		$Name,

		[Parameter(Mandatory=$True)]
		$Url,
		
		$Service = "TuneIn"
	)
	# Add custom stream URL as a radio preset (custom station) in TuneIn.
	# See also Blu-PlayUrl.
	(Blu-Invoke -Device $Device -Path RadioAddPreset -Options @{ name = $Name; url = $Url; service = $Service }).favorite
}
function Blu-RadioDeletePreset()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
	
		$Service = "TuneIn"
	)
	# TODO: Seems there is a RadioDeletePreset request, but have not yet found out
	# what parameters to use to identify the preset to delete!
	#(Blu-Invoke -Device $Device -Path RadioDeletePreset @{'name'=$Name; 'url'=$Url; 'service'=$Service}).favorite
}
function Blu-Sources()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	# Request with option service=Capture returns enabled/connected inputs.
	# Requests without service parameter defaults to "service=TuneIn", this request
	# is performed from separate method: Blu-Radios.
	(Blu-Invoke -Device $Device -Path RadioBrowse -Options @{ service = Capture }).item
}
function Blu-Playlists()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		$Service = "LocalMusic"
	)
	# Request without service parameter defaults to "service=LocalMusic"
	(Blu-Invoke -Device $Device -Path Playlists -Options @{ service = $Service }).name
}
function Blu-Presets()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	(Blu-Invoke -Device $Device -Path Presets).preset
}
function Blu-SwitchToPreset()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[Parameter(Mandatory=$True)]
		[byte] $Id
	)
	# TODO/Implementation notes:
	# Response is different depending on the type of preset,
	# e.g. for TuneIn it retuns the state value "stream",
	# while for a Tidal playlist it returns a different xml response
	# indicating the service and number of entries loaded.
	Blu-Invoke -Device $Device -Path Preset -Options @{ id = $Id }
}
function Blu-SwitchToPlaylist()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	# TODO:
	# http://192.168.1.38:11000/Genres?service=LocalMusic (Library)
}
function Blu-SwitchToRadio()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
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
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[Parameter(Mandatory=$True)]
		[ValidateSet('Optical', 'Bluetooth', 'Spotify', 'RadioParadise')] [string] $Source
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
	Blu-Invoke -Device $Device -Path Play -Options @{ url = $ServicePath; preset_id = ''; image = $Image }
}
function Blu-Search()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[Parameter(Mandatory=$True)] $Query,
		$Service = "LocalMusic"
	)
	# Request without service parameter defaults to "service=LocalMusic"
	Blu-Invoke -Device $Device -Path Search -Options @{ expr = $Query; service = $Service }
}
function Blu-RadioSearch()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[Parameter(Mandatory=$True)] $Query,
		$Service = "TuneIn"
	)
	# Request without service parameter defaults to "service=LocalMusic"
	(Blu-Invoke -Device $Device -Path RadioSearch -Options @{ expr = $Query; service = $Service }).item
}
function Blu-Genres()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		$Service = "LocalMusic"
	)
	# Request without service parameter defaults to "service=LocalMusic"
	(Blu-Invoke -Device $Device -Path Genres -Options @{ service = $Service }).genre
}
function Blu-Artwork()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		$Service = "LocalMusic"
	)
	# TODO
	Blu-Invoke -Device $Device -Path Artwork -Options @{ service = $Service; artist = "?"; album = "?"}
}
function Blu-Diagnostics()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	Blu-Invoke -Device $Device -Path diag -Options @{ print = 1 } -WebApi
}

#
# Other Player functionality
#

function Blu-RoomName()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	# TODO: Can be updated as well, but have not implemented that here yet.
	(Blu-SyncStatus -Device $Device).name
}
function Blu-ModelName()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	(Blu-SyncStatus -Device $Device).modelName
}
function Blu-Audiomodes()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	(Blu-Invoke -Device $Device -Path audiomodes).audiomode
}
function Blu-BluetoothSetting()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[ValidateSet('manual', 'automatic', 'guest', 'off')] [string] $Mode
	)
	# Argument Mode is optional, default is to return current state.
	$Modes = (Get-Variable "Mode").Attributes.ValidValues
	if ($Mode) {
		$ModeCaseSensitive = $Modes -eq $Mode | Select-Object -First 1
		$State = $Modes.IndexOf($ModeCaseSensitive)
		$Modes[(Blu-Invoke -Device $Device -Path audiomodes -Options @{ bluetoothAutoplay = $State } -Method Post).audiomode.bluetoothAutoplay]
	} else {
		$Modes[(Blu-Audiomodes -Device $Device).bluetoothAutoplay]
	}
}
function Blu-OutputMode()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[ValidateSet('default', 'left', 'right')] [string] $Mode
	)
	# Argument Mode is optional, default is to return current state.
	if ($Mode) {
		(Blu-Invoke -Device $Device -Path audiomodes -Options @{ channelMode = $Mode.ToLower() } -Method Post).audiomode.channelMode
	} else {
		(Blu-Audiomodes -Device $Device).audiomode.channelMode
	}
}
function Blu-Brightness()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[ValidateSet('default', 'dim', 'off')]
		[string] $Brightness
	)
	Blu-Invoke -Device $Device -Path ledbrightness -Options @{ brightness = $Brightness } -Method Post -WebApi
}
function Blu-Sleep()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,

		[switch] $Set
	)
	# To change sleep time, it must be invoked with argument -Set, and for each
	# time it steps through the settings: 15, 30, 45, 60, 90 minutes, and off. 
	if ($Set) {
		(Blu-Invoke -Device $Device -Path Sleep).sleep
	} else {
		(Blu-Status -Device $Device).sleep
	}
}
function Blu-Alarms()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	(Blu-Invoke -Device $Device -Path Alarms).alarm
}
function Blu-AlarmSet()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
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
		enable = 1
		hour = $Hour
		minute = $Minute
		days = $Days
		duration = $Timeout
		volume = $Volume
		fadeIn = $FadeIn
		sound = $Sound
		image = $Image
		url = $Url
		tz = $TimeZone
	}
	if ($Id -ne $null) {
		$Options['id'] = $Id
	}
	(Blu-Invoke -Device $Device -Path Alarms -Options $Options).alarm
}
function Blu-AlarmDelete()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
		[Parameter(Mandatory=$True)]
		$Id
	)
	(Blu-Invoke -Device $Device -Path Alarms -Options @{ id = $Id; delete = 1 }).alarm
}
function Blu-Doorbell()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device
	)
	Blu-Invoke -Device $Device -Path Doorbell -Options @{ play = 1 }
}
function Blu-Reboot()
{
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(HelpMessage='The hostname or IP address of the BluOS device to control')]
		[ValidateNotNullorEmpty()]
		[string] $Device = $Device,
		
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
		Blu-Invoke -Device $Device -Path reboot -Options @{ noheader = 1; yes = 1 } -Method Post -WebApi
	}
}