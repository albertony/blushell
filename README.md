# BluShell

Unofficial PowerShell wrapper of the BluOS Web/REST API, served by Bluesound multi-room music devices. The main objective for now is to have a test bench for exploring the features of the API, not an extremely robust and efficient interface.

Bluesound is an award-winning wireless hi-res sound system (https://www.bluesound.com/).

BluOS is an advanced operating system and music management software (https://nadelectronics.com/bluos/).

Note that several of the services integrated into BluOS, such as Tidal, have their
own APIs that can be used directly instead of (or in addition to) via the integrated
API in BluOS. For Tidal, see [tidalshell](https://github.com/albertony/tidalshell) - my PowerShell wrapper for the Tidal API.

## Disclaimer

Most of the information here was found by reverse engineering the BluOS Controller desktop application.
Since then an official API documentation has been published on [bluesound.com/downloads](https://www.bluesound.com/downloads/).
Until I can make time for a complete review there may be discrepancies. More about [sources](#sources) at the end.

# BluOS API

The BluOS devices serve a REST API on port number 11000. Most operations can be performed
with HTTP Get requests, some very few require HTTP Post. Responses are XML.

On port 80 there is a basic web user interface, and some operations must be done with
HTTP requests to this service instead of the REST service.

When describing the details below, all operations are HTTP Get requests against the
REST API unless specifically stated otherwise.

## Playback

### /Play

Without parameters it will resume playback from the current position of the play queue or the latest stream.

Optional parameter `id` can be set to a positive integer identifying the item number in the play queue to start playback from.

Optional parameter `seek` can be set to a integer representing number of seconds into the current track to start playback from.

Optional parameter `url` can be set directly to a stream url to play. This can
be any streamable media url, such as an mp3 file, or it can be an "internal"
url identifier used in BluOS, e.g. `Capture:bluez:bluetooth` or `Tidal​:radio:track/43781115` (the latter from the trackstationid attribute
of /Songs response from Tidal service).

The [response](Samples/Play.xml) indicates the resulting state, which is also reported by /Status. On success the state should be `play`.

**Additional notes regarding url playback**

Playing a custom stream url can also be done via the TuneIn service, by adding it as a "Custom Station". Then the stream url will be saved and can be added as a favorite, assigned to a preset etc. This is actually the only officially supported method for 
playing custom streams: "TuneIn Custom Stations replaces the option in BluOS 1.20.x and
earlier versions to enter a custom URL in the Configure Player Menu." (https://support1.bluesound.com/hc/en-us/articles/217463777-Save-an-Internet-Stream-as-a-Custom-Station-in-TuneIn)

In addition to the REST API method for playing url, the Web interface also has
support for it. On http://<device_address>/playurl there is an interactive input form
for entering an url, and it can be triggered programmatically by sending a HTTP Post
request with parameter `url` containing the stream URL.

### /Pause

Without parameters it will suspend playback at the current position, if it is currently playing.

The [response](Samples/Pause.xml) indicates the resulting state, which is also reported by /Status. On success the state should be `pause`.

Optional parameter `toggle` can be set to integer value 1 to toggle between play and pause states. The response indicates the resulting state, which is also reported by /Status. On success the state could be either [`play`](Samples/Pause_Toggle1.xml) or [`pause`](Samples/Pause_Toggle2.xml).

### /Stop

Stop playback. The official app seem to only supports play and pause as interactive 
operations, not stop. When device is activated from "vacation mode" it is in the
stopped state.

The [response](Samples/Stop.xml) indicates the resulting state, which is also reported by /Status. On success the state should be `stop`.

### /Skip

Moves playback to the next item in the current play queue, wrapping around to
first when currently at the last item. The [response](Samples/Skip.xml) contains
the `id` value of the moved to item.

### /Back

Moves playback to the previous item in the current play queue, wrapping around
to last when currently at the first item. The [response](Samples/Back.xml) contains
the `id` value of the moved to item.

### /Repeat

Without parameters the [response](Samples/Repeat.xml) returns the `id` of the current play queue and the current
state of the repeat option. Value is an integer with the following meaning:
* `0` means repeat entire playqueue
* `1` means repeat current track
* `2` means no repeat

Optional parameter `state` can be specified to modify, with an integer value
indicating the repeat mode to set. The [response](Samples/Repeat_modify.xml) indicates
the resulting state.

The current state can be retrieved from the /Status request as well.

### /Shuffle

Without parameters this does *not* (just) return the current state, but it turns shuffle off! To get the current state without modifying one must fetch it from the /Status request.

The [response](Samples/Shuffle.xml) contains the `id` of the current play queue,
and the current state of the repeat option (although the current state may not be
included when shuffle is off). Value is an integer with the following meaning:
* `0` means off
* `1` means on

Optional parameter `state` can be specified to modify, with an integer value
indicating the repeat mode to set. The [response](Samples/Shuffle_modify.xml)
indicates the resulting state.

### /Volume

Without parameters the [response](Samples/Volume.xml) informs about the current
setting. Mainly current volume level in percent, but also the level in dB unit,
and information about configured volume offset in dB, and if muted.

Optional parameter `level` can be specified to set a new volume level, with an
integer value between 0 and 100 specifying the volume to set in percent (within
the configured available volume range for the player). ~~The
[response](Samples/Volume_modify-OLD.xml) when modifying does only contain the changed
setting in percent, not in dB unit as when just requesting the current value.~~
The volume can also be set in dB scale to a value within the configured available volume
range for the player (default -90 - 0 dB) with parameter `abs_db`, alternatively with
parameter `db` and a relative value as a positive or negative number (typical value 2)
which works similar to classical volume up/down buttons. Mute can also be controlled
using parameter `mute`.

Note that to control the volume for player groups as a whole, you will have to send the
request to the main player device and also include the parameter `tell_slaves` set to
value `1`. This does not apply to fixed groups, called zone in /SyncStatus response,
where any volume change applies to the entire group.

The current volume in percent (`volume`) and dB (`db`, previously `outlevel`) can be
retrieved from the /SyncStatus request as well, and in percent also from the /Status
request.

### /Playlist

Without parameters the [response](Samples/Playlist.xml) describes the current play queue.
It is identified by a `name` and `id`, and a list of entries (`song`) with
increasing `id` starting from 0. The entry ids are referenced in the response from
the /Skip and /Prev requests. The playlist id is also referenced from
other requests working on the play queue, and it seems to be an integer
that is incremented whenever the playlist is changed.

Optional parameters `start` and/or `end` can be specified to return
an excerpt of the play queue. The values refer to `id` of playlist
entries, zero indexed, and the specified end is inclusive (`start=0&end=0`
will give a single, the first, item).

### /Clear

Empties the current play queue, and returns the same [response](Samples/Clear.xml)
as a request to /Playlist would do: An empty `playlist` element but
an incremented `id`.

### /Save

Saves the current play queue as a new playlist. Required parameter `name`
specifies the playlist name.
Response on success contains an element `saved`, with a sub-element `entries`
containing the number of items in the saved playlist.

### /Add

Adding items to the current playqueue, and optionally start playback.

Optional argument `service` indicates where the item is located.

Optional argument `playlist`, `file`, `albumid`, `artistid`, etc identifies the item.

Optional argument `where` can be specified to indicate where in the queue
to add the new items. Possible values are `next`, `last`, `nextAlbum`, etc.

Optional argument `playnow` can be set to value 1 to trigger playback.

**TODO: More details needed!**

## Player groups

BluOS supports grouping players in different modes:

* Multi-player group
* Stereo pair
* Home theater group

In the official app there are two main roads to creating a group:

* Quick create multi-player group from the player drawer, either
by clicking `+` symbol on players to add to current player's group,
or by clicking the "Group all" button. These will always be multi-
player groups, and they will get an auto-generated name as a
combination of the individual names of the players.
* Fixed groups menu, where you can select any of the supported
group modes, get help configuring them (e.g. pick which one is left
and which is right in a stereo pair, by playing a sound on each of them),
and also give the group a custom name.

### /AddSlave

A device can be added to a group by specifying the device address
in parameter `slave`. It seems to support alternative parameter
`slaves` where multiple devices can be specified at once, probably
comma-separated, but have not had a chance to test this.

Optional parameter `port` (or `ports`) can be specified if any
of the devices use a non-standard port number (other than the
default 11000).

Optional parameter `group` can be specified to give the group a name,
by default it will be generated from the names of the devices.

This will set up a multi-player group. To set up a stereo pair
one must also specify parameters `channelMode` and `slaveChannelMode`,
one of them with value `left` and the other one with value `right`.
(Multi-player group have implicit value `default` for both
`channelMode` and `slaveChannelMode`).

TODO: How to set up Home theater group?

The [response](Samples/AddSlave.xml) contains the address and port numbers
of slaves added.

### /RemoveSlave

Removes a device from a group, and the entire when there are only
one device in it. Required parameter `slave` or `slaves`, and
optional parameter `port` or `ports`.

The [response](Samples/RemoveSlave.xml) contains the SyncStatus.

## Navigation

### /Services

This seem to return a more or less complete description of the navigation
paths of all supported services in the user interface. A lot of API
details can be found by inspecting this!

TODO: More details...

### /Browse

This can be used to browse the content of configured services (Tidal, Qobuz, TuneIn, etc). The first call gets a list of menu items with 'browse keys' which can be used in subsequent calls. Provided search keys can be used to search the service that is being browsed.

Samples:

 [/Browse](Samples/Browse.xml)

[/Browse?key=Qobuz:](Samples/Browse-key.xml)

[/Browse?key=Qobuz:Search&q=miles](Samples/Browse-search.xml)

### /Presets

Returns list of all current presets. Players such as Bluesound Flex
have physical buttons for 5 presets, but the API supports configuring
up to 40 different presets that can be triggered with the /Preset
request (see below).

Sample [response](Samples/Presets.xml).

### /Preset

Activates a preset (starts playback), identified by parameter `id`.

Sample [response for playlist preset](Samples/Preset_playlist.xml)
and [radio preset](Samples/Preset_radio.xml).

### /SetPreset

Without parameters it lists existing presets, identical to /Presets.

To modify a preset the preset number must be specified in parameter `id`.
If no other parameters are specified it will remove any existing presets with that identifier.
To set a new preset the service must be specified in parameter `service` (e.g. `Capture`, or `Tidal`),
and the BluOS specific reference must be specified in parameter `encoded_url` (for example for the
preset to switch active source to Bluetooth, the url is "Capture:bluez:bluetooth"). A preset name
must be specified in parameter `name`. Then there is an option to include a volume level, so that
activating the preset also changes the volume, then the parameter `volume` must specify the volume in percent.
There is also a parameter `image`.

In all variants the [response](Samples/Presets.xml) is the list of current presets, as also returned by /Presets.

### /Playlists

Returns available playlists. Note /Playlist (without ending s) is similar,
but not directly related as it returns the current play queue.

Without parameters it returns local device playlists, as if parameter `service`
is set to `LocalMusic`. Playlists from other services can be listed by setting
parameter `service`, e.g. to `Tidal`.

Sample [response](Samples/Playlists.xml) for the default service (`LocalMusic`),
and [response](Samples/Playlists_Tidal.xml) for service=Tidal.

At least for Tidal, the default is to return your personal playlists. Other
compiled playlists can be retrieved by adding various parameters:
* `category` : `new`, `recommended`, `local`, `FAVOURITES`
* `genre` : `Local`, `Pop`, `Rock`, etc (genreid of items returned by /Genres).
* `mood` : `relax`, `party`, `workout`, etc (genreid of items returned by /Genres with `category=moods`)

Playlists can be created by /Save, /AddToPlaylist etc..

TODO...

### /AddToPlaylist

Create (or modify) playlists.

Parameter `name` must be set with the name to save it as.
Parameter `service` identifies where to save the playlist, e.g. `LocalMusic` to save it on the device.
Parameters `sourceService` and `songid` identifies the item to add to the playlist.

TODO...

### /RadioBrowse

Sample [default response](Samples/RadioBrowse.xml),
[service=Capture response ](Samples/RadioBrowse_service_Capture.xml),
[service=TuneIn response](Samples/RadioBrowse_service_TuneIn.xml).

TODO...

### /RadioPresets

Sample [default response](Samples/RadioPresets.xml),
[service=TuneIn](Samples/RadioPresets_TuneIn.xml).

TODO...

### /RadioAddPreset

TODO...

### /RadioDeletePreset

TODO...

### /Genres

Lists the generes supported by a given service, default is the local player
but parameter `service` can be specified to see genres from other services
(such as Tidal).

Other service-specific parameters may be supported, e.g. Tidal supports
`category=moods` to get the categories of special "mood" playlists.

Sample [default response](Samples/Genres.xml),
[service=Tidal response](Samples/Genres_Tidal.xml).

### /Artists, /Albums and /Songs

For Tidal navigation the parameter `service` must be set to `Tidal`.
In addition one need to specify one or more parameters for navigating
into the structure, similar to /Playlists:
* `category` : `new`, `rising`, `recommended`, `top`, `local`, `FAVOURITES`
* `genre` : `Local`, `Pop`, `Rock`, etc (genreid of items returned by /Genres).

For /Songs one can specify attribute `playlistid` to list all songs
in a specified playlist, or `albumid` to list all songs in an album.

### /Search

To perform a generic search, specify parameter `expr` with the search string as value. It will search local music by default, but to search other services add parameter `service` (e.g. service=Tidal). The response contains search results, groupd on artist, album and song.

Sample [default response](Samples/Search_Tidal_expr_Bon.xml),
[service=Tidal response](Samples/Search_expr_Bon.xml).

Another way of searching is through /Browse (see above).

### /RadioSearch

To search for radio stations, using a similar syntax as /Search: Parameter `expr` with the search string, and `service` to identify the service - here TuneIn is the default service.

Sample [response](Samples/RadioSearch_expr_Bon.xml).

### /Artwork

Redirects to the image file representing an item, such as an artist, album, song,
radio station. Parameter identifies the item, either `songid`, `albumid`, `artistid`
or `playlistid`.

Sample [response](Samples/Artwork.xml).

### /Info
Gets a html page with a description of an artist, album or song.

Sample: [/Info?service=Qobuz&service=Qobuz&artistid=574073](Samples/Info.html)

## Configuration

## /Name

HTTP Post request with parameter `set` with the new name as the value will set the
name of the player - the "room name".

### /Status

Gives the current status of the player. This is called frequently by the offical
applications to keep it up to date with any changes from other controllers.

Two optional parameters, `timeout`, which can be set to an integer value
which defines number of seconds, and `etag`, which is an
[HTTP entity tag](https://en.wikipedia.org/wiki/HTTP_ETag), are
used for 'long polling', keeping the request open until the responsive is different from the previous response (using the etag for comparison) or until the timeout has been reached. /SyncStatus should be polled if only the name, volume and grouping status of a player is of interest. /Status should be polled if current playback status is needed. The official desktop client application sends these requests regularly (every few seconds).

(The official desktop client does not send "If-None-Match" headers, which is normally used in Etag concurrency control Tidal does, it is implemented in [tidalshell](https://github.com/albertony/tidalshell)).


Sample [response](Samples/Status.xml),
[response when stopped](Samples/Status_Stopped.xml),
[response when paused](Samples/Status_Paused.xml),
[response when playing](Samples/Status_Playing.xml).

### /SyncStatus

Used in combination with /Status to keep multiple controllers synchronized.

Sample [response](Samples/SyncStatus.xml).

TODO: Have not yet dug into exactly how the synchronization mechanism works..

### /Settings

Similar to /Services, this gives seem to return a more or less complete
description of the navigation paths of settings in the user interface.
A lot of API details can be found by inspecting this!

Adding parameter `expand` with value 1 adds more details.

TODO: More details...

### /Version

Returns the BluOS version number? However as of BluOS version 4.8.7 it returns version number 4.8.6...

TODO: More details...

### /ui

Web API endpoint /ui has some internal information in different sub paths.

Endpoint /ui/Home with parameter `playnum` set to a player number value, e.g. `1`,
gives details similar to /Settings.

Endpoint ui/reportServiceDuration with parameter `playnum` set to a player number value, e.g. `1`,

TODO: More details...

### /Sleep

Sets the sleep timer, each request will cycle through the supported settings: 15, 30, 45, 60, 90 minutes, and off. Response is the new setting in number of minutes, or empty if it is off. Current value can be found from /Status.

### /Alarms

Without parameters the [response](Samples/Alarms.xml) lists all existing alarm definitions. 
Parameter `tz` can be set specify time zone, value is string containing the "Olson"
[time zone name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

Alarms can be created by setting various parameters:
* `hour` : Hour of day as an integer.
* `minute` : Minutes of the hour as an integer.
* `days` : Repetition, specified as string with 7 binary values representing weekdays (SMTWTFS), "00000000" means no repetition, "1010000" means sundays and tuesdays.
* `duration` : Timeout in minutes before the alarm turns off automatically, 0 means never. Official application supports between 15 minutes and 2 hours.
* `source` : The alarm sound.
* `volume` : The alarm sound volume, in percent.
* `fadeIn` : If the alarm sound should fade in, value is 0 or 1.
* `image` : TODO...
* `url` : TODO...
* `enable`: Value is 1. Official application does not support enabling/disabling alarms, so not sure what this is for, if we can set it to value 0? TODO...
* `tz` : The timezone name.

Reponse from creating alarms is the same as /Alarms; listing all current alarms.

Alarms can be modified by including parameter `id` identifying the alarm entry, and then any of the above parameters that should be modified. Response is same as /Alarms; listing all current alarms.

Alarms can be deleted by including parameter `id` identifying the alarm entry and then parameter `delete` with value 1. Response is same as /Alarms; listing all current alarms.

### /audiomodes

Without parameters the [response](Samples/audiomodes.xml) indicates the current
value of all "audio mode" related settings. EDIT: Tested 21.04.2021 and did no longer
get current values, but changes chan still be performed as described next.

NOTE: The audio options vary depending on the model of the BluOS Player,
see the following [article](https://support.bluos.net/hc/en-us/articles/360036429314-Adjusting-Audio-Settings).

Changes must be performed using an HTTP Post request (not a Get request like most other operations on the REST API),
and with parameters specifying the new value of any settings to change:
* `bluetoothAutoplay`, integer value:
  * `0` means manual
  * `1` means automatic
  * `2` means guest
  * `3` means off
* `channelMode`
  * `default` (means mono output on a mono speaker like Flex, otherwise probably stereo output?)
  * `left`
  * `right`
  * `mono` (guessing this is a value for setting mono output on a stereo speaker?)
* `volumeLimits`
  * Value is the decibel integer range separated by comma, e.g.`-90,0`.
* `volume`
* `volMin`
* `volMax`
* `volMinDefault`
* `volMaxDefault`
* `volMinLimit`
* `volMaxLimit`
* `volRamp`
* `volRampDefault`
* `mqaDisable`
* `crossover`
* `canFixVolume`
* `replayGainMode`
  * `none`
  * `track`
  * `album`
  * `smart`
* `captureLatency`
* `captureAutoplay`

### /alsa_setting

A post request with parameter `reset` set to value `1` will reset all audio settings to defaults.

### /captures

Endpoint captures with parameters `playnum`, `device` and `action`.

TODO...

### /update

TODO...

### /UpdateDNS

TODO...

### /ledbrightness

Adjusting the LED brightness setting is possible via the Web API, not the REST API.
It is achieved by sending an HTTP Post request with parameter `brightness` with
string value which is one of:
* `default`
* `dim`
* `off`

### /ShowIRCodes

Lists current IR remote configuration?

TODO...

### /LastScanCode

IR remote related?

TODO...

### /Doorbell

Get request with parameter `play` set to integer 1 plays doorbell chimes.

### /reboot

Rebooting the player device is possible via the Web API, not the REST API. Using the basic
web interface, http://<device_address>/reboot will give you an interactive user interface
with buttons Yes and No (parameter `noheader=1` can be added for an even more minimalistic
and stand-alone web interface, without the navigation menu on top). An HTTP Post request
with parameter `yes` will trigger the actual reboot.

### /diag

The Web interface supplies an internal diagnostics log in text format, which can
be retrieved with an HTTP Get request with parameter `print` set to integer 1 (http://<device_address>/diag?print=1). Here you can dig into a huge amount of technical details,
including details from the linux operating system (process list, mount points, logs).

# Sources

The starting point was a [thread](https://helpdesk.bluesound.com/discussions/viewtopic.php?f=4&t=2293&sid=e011c0bdf3ede3ea1aeb057de63c1da8) on the official Bluesound forum. I also looked at the [Python Bluesound API](https://github.com/venjum/bluesound) by @venjum, which have implemented many of the basic features mentioned in the thread.

## Reverse engineering
Most of the information is from my own investigations, mainly by reverse engineering what the
[BluOS Controller desktop application](https://www.bluesound.com/downloads/) is doing.
My main tool for reverse engineering APIs is [Telerik Fiddler](https://www.telerik.com/fiddler).
In this case the official desktop client application is based on Electron (Chromium), and then it
is possible to open up the built-in developer tools using "secret" shortcut Ctrl+Shift+E (or Ctrl+E+V),
which is also very useful.

You could also use [Wireshark](https://www.wireshark.org).

## Official API documentation
Since this was written an official API documentation has been published on [bluesound.com/downloads](https://www.bluesound.com/downloads/), as a downloadable PDF. The official documentation is incomplete.

There are also different plugins for integrating into specific home automation systems.