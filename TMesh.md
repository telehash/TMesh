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
* chunked encoding is used to serialize variable length packets into fixed transmission frames

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

Transmitted payloads do not need whitening as encrypted packets are by nature DC-free.  They also do not need CRC as all telehash packets have authentication bytes included.

### MAC

There is no mote addressing or other metadata included in the encoded bytes, no framing other than the length of the payload.  The uniqueness of the timing and signalling of each epoch is the mote addressing mechanism.

The epoch 16 bytes are used as an AES-128 key, and the current count of windows since the first sync is used as the IV.  All payloads are encrypted before transmission even if they are already encrypted telehash packets.

Additional MAC-only packet types are defined for exchanging the current set of epochs active between any two motes.  An additional pre-set `lost` mode is defined for bootstrapping two motes from scratch or if they loose sync.

Each mote should actively make use of multiple epochs with more efficient options to optimize the overall energy usage.  Every mote advertises their current energy resource level as a `z-index` as an additional mesh optimization strategy.

### Mesh

There is two mechanisms used for enabling a larger scale mesh network with TMesh, `neighborhoods` (MAC layer) and `routers` (telehash/app layer).

A neighborhood is the automatic sharing of other epochs one mote has active with every other mote it is linked with.  Every mote also supports a simple MAC-level window sequential forwarding service between neighbors to aid with discovery and resiliency.  The neighborhood map shared from each mote includes a unique addressible epoch id, the epoch, microsecond offset, and signal strength.

A router is always the neighbor with the highest z-index, which inherits the responsibility to monitor each neighbor's neighborhood for other routers and establish direct or bridged links with them.  Any mote with a packet for a non-local hashname will send it to their router, whom will send it to the next highest router it is connected to until it reaches the highest in the mesh.  The highest resourced router is responsible for maintaining an index of all available motes/hashnames in the mesh.


# Protocol Definition

## Terminology
In this document, the key words "MUST", "MUST NOT", "REQUIRED",
"SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY",
and "OPTIONAL" are to be interpreted as described in BCP 14, [RFC 2119]
and indicate requirement levels for compliant TMesh implementations.


## PHY

Epoch type table:

| Byte  | Encoding
|-------|---------
| 0x00  | Reserved
| 0x01  | OOK
| 0x02  | (G)FSK
| 0x03  | LoRa

### OOK

TBD

### (G)FSK

TBD

### LoRa

Epoch Header

* byte 1 - dB power level & frequency band selector (915, 868, 433, etc)
* byte 2 - Bw & CodingRate (RegModemConfig 1)
* byte 3 - SpreadingFactor (RegModemConfig 2)
* byte 4-7 - random

All preambles are set to the minimum size of 6.

LoRa is used in implicit header mode, which requires a knock to be in two individual transmissions: a 1-byte transmission of the knock length, a wait for it to be received/processed, then the 0-128 byte payload transmission.

## MAC

### Lost Mode

Each PHY documents a sequence of lost-mode epoch headers, only encodes a handshake with the recipient hashname being the random bytes of the epoch id.   Each fixed header in the lost sequence is an individual transmission window, with the current offset being the sequence id, which repeat once the sequence is complete.

The sequence should include a variety of different epoch types, focusing on long range, boosted, and more interference resistant modes, as well as some lower power ones for when the energy budget is low.  When possible it should be specifically optimized such that the lost recipient may switch between multiple epochs within one window to maximize the lost recovery time.

## Mesh

Describe neighborhoods and routers, and routers performing ongoing lost-mode duties.

### z-index

Every mote calculates its own `z-index`, a uint8_t value that represents the resources it has available to assist with the mesh.  It will vary based on the battery level or fixed power, as well as if the mote has greater network access (is an internet bridge) or is well located (based on configuration).

The mote with the highest `z-index` in any neighborhood is known as the `local leader`.

## Notes

* send packet for a mote directly to it, and then fallback to one known neighbor, then to the local leader
* lost mode is when all link state is lost or all epochs expired, local leaders must help by sending handshake knocks on a common encoder-defined channel for them to resync
  * begin listening for any hard knock handshakes, generate link id and sync to it then handshake there
  * if sleepy, only listen on the lost schedule
  * local leaders are required to hard knock per epoch on the lost schedule
* resource based routing, highest resource gets undelivered packets
* highest leader for the whole mesh is responsible for mapping the full mesh, collecting undelivered’s and re-routing them
* natural pooling around local resources, neighborhoods
* when you know a link's neighbors you can calculate their knock windows and detect possible overlaps to optimize for interference


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
