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

> this is a work in progress and under active development, expect significant breaking changes

As embedded devices continue to increase in capabilities while falling in cost there is a growing challenge to manage their energy resources for wirelessly networking them together.  While there are many options for short-range 2.4GHz networks such as Bluetooth Smart (BLE), low-power WiFi, Zigbee and 802.15.4 based mesh networks, there are few choices for long-range sub-GHz mesh networking.

TMesh builds on the strong end-to-end encryption and privacy capabilities of [telehash v3] by adding a uniquely matched secure Physical RF and Media Access Control protocol.

The key attributes of TMesh are:

  * high density - thousands per square kilometer
  * very low power - years on coin cell batteries
  * wide area - optimized for long-range (>1km) capable radios
  * high latency - low minimum duty cycle from seconds to hours
  * peer aware meshing - does not require dedicated coordinator hardware
  * high interference resiliency - bi-modal PHY to maximize connectivity in all conditions
  * dynamically resource optimized - powered motes naturally provide more routing assistance
  * zero metadata broadcast - same absolute privacy and security principles as telehash
  * dynamic spectrum - able to use any specialized private or regionally licensed bands
  
## The Need for Standards

The existing best choices are all either only partial solutions like 802.15.4, require commercial membership to participate like LoRaWAN, ZigBee, and Z-Wave, or are focused on specific verticals like DASH7 and Wireless M-Bus.

All other options only provide incomplete or indadequate security and privacy, most use only optional AES-128 and often with complicated or fixed provisioning-based key management.  No existing option fully protects the mote identity and network metadata from monitoring.

## Telehash Native

By leveraging [telehash][] as the native encryption and mote identity platform, TMesh can start with some strong assumptions:

* each mote will have a unique stable 32-byte identity, the hashname
* two linked motes will have a unique long-lived session id, the routing token
* all payloads will be encrypted ciphertext with forward secrecy
* retransmissions and acknowledgements happen at a higher level and are not required in the framing
* motes are members of a private mesh and only communicate with other verified members
* chunked encoding defines how to serialize variable length packets into fixed transmission frames

## Vocabulary

* `mote` - a single physical transmitting/receiving device
* `medium` - definition of the specific channels/settings the physical transceivers use
* `community` - a network of motes using a common medium to create a large area mesh 
* `neighbors` - nearby reachable motes in the same community
* `z-index` - the self-asserted resource level (priority) from any mote
* `leader` - the highest z-index mote in any set of neighbors
* `knock` - a single transmission
* `window` - the variable period in which a knock is transmitted, 2^16 to 2^32 microseconds (<100ms to >1hr)
* `window sequence` - each window will change frequency/channels in a sequence

## Overview

TMesh is the composite of three distinct layers, the physical radio medium encoding (PHY), the shared management of the spectrum (MAC), and the networking relationships between 2 or more motes (Mesh).

Common across all of these is the concept of an `epoch`, which is a generated set of unique window sequences shared between two motes in one `medium`.  A `window` is where one `knock` can occur from one mote to another unique to that window.  A `knock` is the transmission of a 64 byte fixed frame of payload, plus any medium-specific overhead (preamble).

A community is any set of motes that are using a common medium definition and have enough trust to establish a telehash link for sharing peer motes and act as a router to facilitate larger scale meshing.  Within any community, the motes that can directly communicate over an epoch are called neighbors, and any neighbor that has a higher z-index is always considered the current leader and may have additional responsibilities.

### PHY

A `medium` is a compact 5 byte definition of the exact PHY encoding details required for a radio to operate.  The 5 bytes are always string encoded as 8 base32 characters for ease of use in JSON and configuration storage, an example medium is `azdhpa5r` which is 0x06, 0x46, 0x77, 0x83, 0xb1.

`Byte 0` is the primary `type` that determines if the medium is for a public or private community and the overall category of PHY encoding technique to use.  The first/high bit of `byte 0` determins if the medium is for public communities (bit `0`, values from 0-127) or private communities (bit `1`, values from 128-255).  The other bits in the `type` map directly to different PHY modes on transceivers or different drivers entirely.

`Byte 1` is the maximum energy boost requirements for that medium both for transmission and reception.  While a mote may determine that it can use less energy and optimize it's usage, this byte value sets an upper bar so that a worst case can always be independently estimated.  The energy byte is in two 4-bit parts, the first half for the additional TX energy, and the second half for the additional RX energy.  While different hardware devices will vary on exact mappings of mA to the 1-16 range of values, effort will be made to define general buckets and greater definitions to encourage compatibility for efficiency estimation purposes.

Each PHY driver uses the remaining medium `bytes 2, 3, and 4` to determine the power, frequency range, number of channels, spreading, bitrate, error correction usage, regulatory requirements, channel dwell time, etc details on the transmission/reception.  The dynamic channel frequency hopping and transmission window timing are derived dynamically and not included in the medium.

Transmitted payloads do not generally need whitening as encrypted packets are by nature DC-free.  They also do not explicitly require CRC as all telehash packets have authentication bytes included for integrity verification.

A single fixed 64 byte payload can be transmitted during each window in a sequence, this is called a `knock`.  If the un-encrypted payload does not fill the full 64 byte frame the remaining bytes must contain additional data so as to not reveal the actual payload size.

> WIP - determine a standard filler data format that will add additional dynamically sized error correction, explore taking advantage of the fact that the inner and outer bitstreams are encrypted and bias-free (Gaussian distribution divergence?)

### MAC

There is no mote addressing or other metadata included in the transmitted bytes, including there being no framing outside of the encrypted ciphertext in a knock.  The uniqueness of each epoch's timing and PHY encoding is the only mote addressing mechanism.

Every window sequence is a unique individual encrypted session between the two motes in one community using a randomly rotating nonce and a shared secret key derived directly from the medium, community name, and hashnames. All payloads are encrypted with the [ChaCha20 cipher](http://cr.yp.to/chacha.html) before transmission regardless of if they are already encrypted via telehash.

Each mote should actively make use of multiple communities to another mote and regularly include more efficient mediums to optimize the overall energy usage.  Every mote advertises their current energy resource level as a `z-index` byte value as an additional mesh optimization strategy.

### Mesh

There is two mechanisms used for enabling a larger scale mesh network with TMesh, `communities` (MAC layer) and `routers` (telehash/app layer).

A `community` is defined by motes using a shared medium and the automatic sharing of other neighboring motes that it has active windows with in that medium.  Each neighbor mote hashname is listed along with time offset, last activity, z-index, and the signal strength.  A mote may be part of more than one community but does not share neighbor mote information outside of each one.

The `leader` is always the neighbor with the highest z-index reachable directly, this is the mote advertising that it has the most resources available. The leader inherits the responsibility to monitor each neighbor's neighbors for other leaders and establish direct or bridged links with them.

Any mote attempting to connect to a non-local hashname will use their leader as the telehash router and send it a peer request, whom will forward it to the next highest leader it is connected to until it reaches the highest in the community.  That highest resourced leader is responsible for maintaining an index of the available motes in the community.  Additional routing strategies should be employed by a mesh to optimize the most efficient routes and only rely on the leaders as a fallback or bootstrapping mechanism.

Any mote that can provide reliable bridged connectivity to another network (wifi, ethernet, etc) should advertise a higher z-index and may also forward any telehash peer request to additional telehash router(s) in the mesh via those networks.

# Protocol Definition

## Terminology
In this document, the key words "MUST", "MUST NOT", "REQUIRED",
"SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY",
and "OPTIONAL" are to be interpreted as described in BCP 14, [RFC 2119]
and indicate requirement levels for compliant TMesh implementations.


## PHY


### Private Hopping Sequence

Most PHY transceivers require specific synchronized channel and timing inputs, in TMesh these are randomized based on the MAC encryption layer, using the unique secret and nonce for each pair of motes and current window with ChaCha20.

The first four bytes (32 bits) of the current nonce are used to determine the window microsecond offset timing as a network order unsigned long integer.  Each window is from 2^16 to 2^32 microseconds, the 32-bit random offset is scaled by the current z-index into the possible range of values.

The current channel is determined by a private two byte value that is rotated identically to the nonce when two motes are in sync. While any two motes are synchronizing by sending PING knocks the channel must remain stable and not be rotated.  The two channel bytes are the seed for channel selection as a network order unsigned short integer.  The 2^16 total possible channels are simply mod'd to the number of usable channels based on the current medium.  If there are 50 channels, it would be `channel = seed % 50`.


### Medium Types

Medium `type byte` (0) table:


| Bit 7      | Community
|------------|---------
| 0b0xxxxxxx | Public
| 0b1xxxxxxx | Private

| Bits 6-0   | Encoding
|------------|---------
| 0bx0000000 | Reserved
| 0bx0000001 | OOK
| 0bx0000010 | (G)FSK
| 0bx0000011 | LoRa
| 0bx0000100 | (O)QPSK

The `energy byte` (1) table:

> Work In Progress

| Bits 7-4   | Max TX mA
|------------|---------
| 0bx0000000 | 1
| 0bx0000001 | 4
| 0bx0000010 | 8
| 0bx0000011 | 16
| 0bx0000100 | 32

| Bits 7-4   | Max RX mA
|------------|---------
| 0bx0000000 | 1
| 0bx0000001 | 2
| 0bx0000010 | 4
| 0bx0000011 | 8
| 0bx0000100 | 16

...

#### OOK

> TBD

#### (G)FSK

> TBD

#### LoRa

Epoch Header

* byte 2 - standard frequency range (see table)
* byte 3 - Bw & CodingRate (RegModemConfig 1)
* byte 4 - SpreadingFactor (RegModemConfig 2)

All preambles are set to the minimum size of 6.

LoRa is used in implicit header mode with a fixed size of 64.

Freq Table:

| Region | Low | High | mW (erp) | Reg             | ID   |
|--------|-----|------|----------|-----------------|------|
| US     | 902 | 928  | 100      | FCC part 15.247 | 0x01 |
| EU     | 863 | 870  |          | ETSI EN 300-220 | 0x02 |
| Japan  | 915 | 930  |          | ARIB T-108      | 0x03 |
| China  | 779 | 787  | 10       | SRRC            | 0x04 |

In the US region 0x01 to reach maximum transmit power each window may not transmit on a channel for more than 400ms, when that limit is reached a new channel must be derived from the epoch (TBD) and hopped to.  See [App Note](https://www.semtech.com/images/promo/FCC_Part15_regulations_Semtech.pdf).

Notes on ranges:
* [SRRC](http://www.srrccn.org/srrc-approval-new2.htm)
* [Z-Wave](http://image.slidesharecdn.com/smarthometechshort-13304126815608-phpapp01-120228010616-phpapp01/95/smart-home-tech-short-14-728.jpg)
* [Atmel](http://blog.atmel.com/2013/04/23/praise-the-lord-a-new-sub-1ghz-rf-transceiver-supporting-4-major-regional-frequency-bands/)


#### (O)QPSK

> TBD

## MAC

### Encrypted Knock Payload

A unique 32 byte secret is derived for every pair of motes in any community. The 32 bytes are the binary digest output of multiple SHA-256 calculations of source data from the community and hashnames.  The first digest is generated from the medium (5 bytes), that output is combined with the community name (string) for a second digest, and then with the mote hashnames in binary ascending sorted order.

The 8-byte nonce is initially randomly generated and then rotated for every window using ChaCha20 identically to the knock payload.

The secret and current nonce are then used to encode/decode the chipertext of each knock with ChaCha20.

### Frame Payload

Each knock transfers a fixed 64 byte ciphertext frame between two motes.  Once the frame is deciphered it consists of one leading flag byte and 63 payload bytes.  The payload bytes are based on the simple telehash chunking pattern, where any packet is sent as a sequence of chunks of fixed size until the final remainder bytes which terminate a given packet and trigger processing.

The flag byte format is:

* bit 0 is the forwarding request, 1 = forward the frame, 0 = process it
* bit 1 is the payload format, 1 = full 63 bytes are the next chunk, 0 = the payload is the end of a complete packet and the following byte is the remainder length (from 0 to 62)
* bit 2-7 is a position number <64 that specifies the forwarding neighbor based on their list position in the most recent neighborhood map exchanged

When receiving a forwarded frame the position number is 1 or greater, a position of 0 means the frame is direct and not forwarded.

### WIP




* secrets always hash(comm)+hash(medium)+hash(hn0)+hash(hn1)
* public ping beacons hashname using zero'd hn0/hn1 and nonce
  * includes potential hn
  * once sent/received generate window based on hashnames, use last one as ping to derive nonce and time base for sync
* sync is 64 random bytes, cipher'd using zero nonce, first 4 decipher'd are then new nonce
  * set base nonce, calc seq 0, begin handshakes
* ping frame first 4 bytes are from current nonce
  * when public and exchanging handshakes, postpone other public pings
* ping tx only w/ a nonce that has rx window next
  * if rx'd w/ matching nonce, remove ping flag and let channels go
  * only reset nonce based on channel scheduled ones

* neighborhood map sends each nonce + offset + z
* each window is a tx/rx, the microsecond offset even/odd determins polarity of hashnames, match=tx

## Mesh

### z-index

Every mote calculates its own `z-index`, a uint8_t value that represents the resources it has available to assist with the mesh.  It will vary based on the battery level or fixed power, as well as if the mote has greater network access (is an internet bridge) or is well located (based on configuration).

The z-index also serves as a window mask for all of that mote's receiving window sizes. This enables motes to greatly reduce the time required waking and listening for low power and high latency applications.

The first 4 bits is the window mask, and the second 4 bits are the energy resource level.

The initial/default z-index value is determined by the medium as a fixed value to ensure every community can bootstrap uniformly.  It is then updated dynamically by any mote in the neighborhood channel by sending the desired z-index value along with a _future_ nonce at which it will become active.  This ensures that any two motes will stay in sync given the time scaling factor in the z-index.


### Neighbors

Each mote should share enough detail about its active neighbors with every neighbor so that a neighborhood map can be maintained.  This includes the relative sync time of each mote such that a neighbor can predict when a mote will be listening or may be transmitting to another nearby mote.

Neighborhood:

* 8 byte nonce
* 4 byte microseconds ago last knock
* 1 byte z index
* 1 byte rssi

### Communities

> Describe communities and routing in more detail, and routers performing ongoing sync-mode duties.

A community is defined as a single medium and a string name, both of which must be known to join that community.  They are the primary mechanism to manage and organize motes based on available spectrum and energy, where each community is bound to a single medium with predictable energy usage and available capacity.

Any mesh may make use of multiple communities to optimize the overall availability and reliability, but different communities are not a trust or secure grouping mechanism, the medium and name are not considered secrets.

#### Private Community

A private community is not visible to any non-member, other than randomly timed knock transmissions on random channels there is no decodeable signals detectable to any third party, it is a dark mesh network that can only be joined via out of band coordination and explicit mesh membership trust.

In order for any mote to join a private community it must first have at a minimum the community name, the hashname of one or more of the current leaders of that community, and the medium on which it is operating.

It must also have either it's own hashname independently added as a trusted member to the leader(s), or have a handshake that will verify its mesh membership and be accepted by a leader.

The three sources of a hashname (32 bytes), the medium (5 bytes), and community name (string) are combined in that order and the SHA-256 digest is generated as the secret for the `PING` epoch. and listen for a knock in that epoch. This takes advantage of the fact that the community medium is divided into the same set of channels, such that every `PING` epoch will have some overlap with other community epochs that a mote is transmitting on.  When any mote sends any knock that happens to be on the same channel as one of their `PING` epoch's (sequence 0), they should then attempt to receive an `ECHO` knock exactly one window period after the transmission.

The local leader should attempt to maximize their use of their own `PING` epoch overlapping channels to allow for fast resynchronization to them, even to the point of sending arbitrary/random knocks on that channel if nothing has been transmitted recently and continuously listening for any other knocks there if resources are available. When a mote detects that it is disconnected from the private community it should also send regular knocks on the sync epoch channels of last-known nearby motes.

#### Public Community

A public community is inherently visibile to any mote and should only be used for well-known or shared open services where the existince of the motes in the community is not private.  Any third party will be able to monitor participation in a public community, so they should be used minimally and only with ephemeral generated hashnames when possible.  

The public community is defined only by the common medium and name, where the secret is the SHA-256 digest of the medium (5 bytes) and the name string.  These are the inputs to create a `PING` epoch that a joining mote must both listen for and repeatedly transmit knocks on until an `ECHO` is received.  Since they will both be using the same medium channel, if possible a mote should first listen for a transmission in progress before sending another knock to minimize interference.

The `PING` knocks must always have a random 64 byte payload so that even if the secret is known, it is not possible for a third party to determine if the knock was a `PING` or not.

Once one `PING` knock has been both sent and received the mote may then derive an `ECHO` epoch and send a knock on it and listen for other `ECHO` knocks.

Upon receiving any `ECHO` knock the mote should immediately create the `PAIR` epochs and begin sending/receiving a single _unencrypted_ handshake to bootstrap, and then encrypted handshakes until a `LINK` epoch is established for the public community.

This functionality should not be enabled/deployed by default, it should only be used when management policy explicitly requires it for special/public use cases or temporary pairing/provisioning setup.


### Optimizations

Since a community includes the automated sharing the time offsets of neighbors, any mote can then calculate keep-out channels/timing of other motes based on their shared community epochs and optimize the overall medium usage.  In this way, the community epochs act as a higher QoS path between motes, but reduce the privacy of transmissions by informing the neighbors of the windows.



# Implementation Notes

* if a packet chunk is incomplete in one window, prioritize subsequent windows from that mote
* prioritize different communities based on their energy performance, test more efficient ones dynamically

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
