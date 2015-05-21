% Title = "TMesh - Thing Mesh PHY/MAC Protocol"
% abbrev = "tmesh"
% category = "info"
% docName = "draft-miller-tmesh-00"
% ipr= "trust200902"
% area = "Internet"
% workgroup = ""
% keyword = ["mesh", "protocol", "telehash", "phy"]
%
% date = 2015-05-16T00:00:00Z
%
% [[author]]
% initials="J."
% surname="Miller"
% fullname="Jeremie Miller"
% #role="editor"
% organization = "Filament"
%   [author.address]
%   email = "jeremie@jabber.org"
%   [author.address.postal]
%   city = "Denver"

.# Abstract

A secure PHY/MAC based on [telehash][] designed for low-power sleepy devices.

{mainmatter}

# Introduction

As embedded devices continue to increase in capabilities while falling in cost there is a growing challenge to manage their energy resources for wirelessly networking them together.  While there are many options for short-range 2.4GHz networks such as Bluetooth Smart (BLE), low-power WiFi, Zigbee and 802.15.4 based mesh networks, there are few choices for long-range sub-GHz networking.

TMesh builds on the strong end-to-end encryption and privacy capabilities of [telehash v3] by adding a uniquely matched Physical RF and Media Access Control protocol.

The key attributes of TMesh are:

  * high density - thousands per square mile
  * very low power - years on common batteries
  * wide area - optimized for long-range capable radios
  * high lateny - low duty cycle, 10s of seconds of sleep
  * peer aware meshing - does not require special purpose coordinator motes
  * high interference resiliency - bi-modal PHY to maximize connectivity in all conditions
  * dynamically resource optimized - powered motes naturally provide more assistance
  * no identity on the air - same absolute privacy and security principles as telehash
  
## The Need for Standards

The existing best choices are all either only partial solutions like 802.15.4, require membership to participate like LoRaWAN and ZigBee, or are focused on specific verticals like DASH7 and Wireless M-BUS.

All other options only provide incomplete or indadequate security and privacy, most use only optional AES-128 and often with complicated or fixed provisioning-based key management.  No existing option attempts to protect the mote identity and network metadata from monitoring.


## Telehash Native

By leveraging [telehash][] as the native encryption and mote identity platform, TMesh can start with some strong assumptions:

* each mote will have a unique stable 32-byte identity, the hashname
* two linked motes will have a unique long-lived session id, the routing token
* all payloads will be encrypted ciphertext
* retransmissions and acknowledgements happen at a higher level and are not required in the framing
* motes are members of a private mesh and only communicate with other verified members

## Vocabulary

* `mote` - a single physical transmitting/receiving device
* `knock` - a single transmission
* `window` - the period for a knock
* `window sequence` - each window will change frequency/channels in a sequence
* `epoch` - one entire set of window sequences
* `neighborhood` - the list of known nearby motes
* `z-index` - the self-asserted resource level (priority) from any mote
* `leader` - the highest z-index visible in any mote's neighborhood
* `lost` - when a mote hasn't knocked in one epoch or is reset

## Overview

TMesh is the composite of three distinct layers, the physical radio medium encoding (PHY), the shared management of the spectrum (MAC), and the networking relationships between 2+ motes (Mesh).

Common across all of these is the concept of an `epoch`, which is a fixed period of time of 2^30 microseconds (about 18 minutes).  An epoch is broken into 256 `windows` (about 4.2 seconds each) where one `knock` can occur from one mote to another with a specified PHY unique to that epoch.  A `knock` is the transmission of up to 128 bytes of encrypted payload, plus any PHY-specific overhead.

Every mote has at least one receiving epoch and one sending epoch per link to another mote, and will often have multiple epochs with other motes to increase the bandwidth available from the minimum 1/4 kbps average per epoch.  The number and types of epochs available depend entirely on the current energy budget, every epoch type has a fixed minimum energy cost for its lifetime.

### PHY

An `epoch` is defined with a unique 16-byte identifier, specifying the exact PHY encoding details and including random bytes that act as a unique seed for that epoch.

The first byte is a fixed `type` that determines the category of PHY encoding technique to use, often these are different modes on transceivers.  The following 1-7 bytes are headers that are specified by each type of encoding, and the remaining 8 bytes are always a unique random seed.

The PHY encoding uses the headers to determine the power, channel, spreading, bitrate, etc details on the transmission/reception, and must use the random seed to vary the transmission frequency and specific timing offset of each window in the epoch.

### MAC

There is no mote addressing or other metadata included in the encoded bytes, no framing other than the length of the payload.  The uniqueness of the timing and signalling of each epoch is the mote addressing mechanism.

The epoch 16 bytes are used as an AES-128 key, and the current count of windows since the first sync is used as the IV.  All payloads are encrypted before transmission even if they are already encrypted telehash packets.

Additional MAC-only packet types are defined for exchanging the current set of epochs active between any two motes.  An additional pre-set `lost` mode is defined for bootstrapping two motes from scratch or if they loose sync.

Each mote should actively make use of multiple epochs with more efficient options to optimize the overall energy usage.  Every mote advertises their current energy resource level as a `z-index` as an additional mesh optimization strategy.

### Mesh

There is two mechanisms used for enabling a larger scale mesh network with TMesh, `neighborhoods` (MAC layer) and `routers` (telehash/app layer).

A neighborhood is the automatic sharing of other epochs one mote has active with every other mote it is linked with.  Every mote also supports a simple MAC-level window forwarding service between neighbors to aid with discovery and resiliency.

A router is always the neighbor with the highest z-index, which inherits the responsibility to monitor each neighbor's neighborhood for other routers and establish direct or bridged links with them.  Any mote with a packet for a non-local hashname will send it to their router, whom will send it to the next highest router it is connected to until it reaches the highest in the mesh.  The highest resourced router is responsible for maintaining an index of all available motes/hashnames in the mesh.


 - PHY

> REFACTORING WIP
> just one hard knock per epoch
> soft knock sends 1byte length to start
> always ack any knock in next possible receive window
> resend to next shared neighbor if no ack
> rework the neighbor tracking away from knock type balance
> an epoch is based on number of neighbors, total knocks

> lost mode is handshake only, contains knock + recipient id window + block, then blocks back and forth
> step sequence w/ soft then hard, ack a block at same step to continue that step and that is the epoch, don't go higher than available budget for an epoch
> knocks are only one direction
> use budget to maximize/balance between neighbors/epochs

> epoch seed, id is position in neighborhood, 1 byte
> seed is 8 bytes, contains PHY details and random, is salsa key
> neighborhood contains id, seed, tick
> X tick is input counter to epoch seed window
> salsa20 each packet to recipient
> enc packet first byte is forward flag, epoch id
> instead of chunking, skip or short window to terminate
> neighborhood updates are only salsa'd and a header of >1
> * header contins z byte and epoch id byte
> * body is seed-to, seed-from, z, offset, hashname
> route request is a header len >1 <7 and body of hashname+packet

* energy based, total energy budget per epoch
* remove existing epochs for balance available, use to reach new neighbors or optimize existing
* multiple secondary epochs per hashname when few neighbors to fill budget, only advertise primary to others
* minimum 1 epoch for lowest budget
* each epoch phy has different fixed cost
* epoch windows are 5seconds, epochs are 21 minutes
* tick determines each window's exact start time

> phy is epoch seed
> mac is neighbors/epochs/ticks
> app-level binding to hashnames, not in mac
> forwarded packets can be stacked
> aes-128 not salsa20, iv is epoch counter + window counter
> can send extra ec bytes at end of payload if space and energy and time

* a window is 2^22 microseconds, or about 4.2 seconds
* an epoch is 256 windows, (2^30 microseconds), or about 18 minutes
* each window can contain one knock
* the energy budget determines the number of epochs active, minimum one, maximum is the time budget
* each epoch has a 16-byte seed that determines frequency and position in each window
  * 0 - device (lora)
  * 1 - power & medium
  * 2 - config1
  * 3 - config2
  * 4,5,6,7 - random
  * 8+ random
* each one has a table of energy and time budget

Epoch PHY - LoRa




All radio PHY operations are bi-modal, with a `hard knock` and a `soft knock`.  Each `knock` is a single private transmission from one mote to another using an established telehash link.  The `knock` itself is always in two distinct parts, a single boolean notification followed by a short delay and then the full payload transmission.

The `hard knock` is designed for maximum range and is not optimized for energy efficiency, it is the fallback mode after any `soft knock` has timed out.

The `soft knock` is designed to take advantage of a transceiver's most efficient modes and capabilities, always minimizing the energy required to transmit.

Transmitted payloads do not need whitening as encrypted packets are inherently DC-free.  They also do not need CRC as all packets have authentication bytes included.
 
Channel frequency definitions are unique to each link and derived from the link's routing token.  The `window sequence` for each knock will do one full rotation per `epoch`, where at least one knock was required from each mote during for it to be valid and start over.

There are multiple `knock encoders` defined that specify how each knock is actually transmitted via RF depending on the transceiver hardware's capabilities.  These range from highly compatible ones such as ASK, commonly available ones like GFSK, and more advanced/vendor-specific ones such as LoRa.  A mote advertises the encoders it supports as a telehash path.

Each encoder also specifies the knock `window` length, which is 2x the minimum amount of time for a transceiver to transition between transmit and receive and determines the maximum allowable oscillator drift between epochs.

## Overview - MAC

To operate as a mesh network, each mote maintains a list of its radio neighbors and shares that list with each of them for discovery.  This list is called a mote's `neighborhood` and contains mostly soft-knock neighbors with a few hard-knock only neighbors to maximize connectivity.

Every mote calculates its own `z-index`, a uint8_t value that represents the resources it has available to assist with the mesh.  It will vary based on the battery level or fixed power, as well as if the mote has greater network access (is an internet bridge) or is well located (based on configuration).

The mote with the highest `z-index` in any neighborhood is known as the `local leader`.


# Protocol Definition

## Terminology
In this document, the key words "MUST", "MUST NOT", "REQUIRED",
"SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY",
and "OPTIONAL" are to be interpreted as described in BCP 14, [RFC 2119]
and indicate requirement levels for compliant TMesh implementations.


## Notes

* try to keep soft/hard neighbor lists minimum but reliable, quiesce shrinks size of each
* send packet for a mote directly to it, and then fallback to one known neighbor, then to the local leader
* any hard knock handshake must also be repeated as a soft knock
* lost mode is when all link state is lost or all epochs expired, local leaders must help by sending handshake knocks on a common encoder-defined channel for them to resync
  * begin listening for any hard knock handshakes, generate link id and sync to it then handshake there
  * if sleepy, only listen on the lost schedule
  * local leaders are required to hard knock per epoch on the lost schedule
* resource based routing, highest resource gets undelivered packets
* highest leader for the whole mesh is responsible for mapping the full mesh, collecting undelivered’s and re-routing them
* natural pooling around local resources, neighborhoods
* when you know a link's neighbors you can calculate their knock windows and detect an unused one to transmit in instead of waiting for yours

## Link Windows

* link ids determine window sequence pattern
* step through each bit of the id
  * derive unique soft/hard knock parameters
  * derive time until next window (variable)
  * each pass through the full id is called an `epoch`
* a confirmed knock over any link is a sync, know the current bit the sender is on for all their links
* can use a neighbors window if no soft knock is detected
* sleepy motes calculate the epoch peak density across all their neighbors and only wake then
  * knocks are only tried twice outside of that peak, and once again inside
* calculate neighbor windows to detect conflicts and avoid overlapping

## Flow

1. mote must be initially paired to another
  * handshakes
  * z-index priority set
  * link established
  * link id created (routing token and z-index byte?)
1. existing mote informs mesh of new link
  * sends to mesh leader for overall routing
  * if link is a neighbor, updates other neighbors
1. existing mote shares mesh to new mote
  * sends its neighborhood
  * sends the mesh top leader list
1. new mote attempts to reach neighbors to establish links
1. build/maintain neighborhood list of X soft and Y hard knock
1. each mote sends its neighborhood to each neighbor after it's changed since the last epoch
1. a neighbor is only considered lost after it has not responded to a full epoch



# Implementation Notes


# Security Considerations


# References

<reference anchor="telehash"  target="http://telehash.org">
<front>
<title>telehash protocol v3.0</title>
<author fullname="Jeremie Miller" initials="J" surname="Miller">
</author>
<date month='April' day='7' year='2015' />

</front>
</reference>

{backmatter}

# Examples

This appendix provides some examples of the tmesh protocol operation.

```
   Request:


   Response:

```

[telehash]: http://telehash.org
