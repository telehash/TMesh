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
  * high latency - low minimum duty cycle from seconds to minutes
  * peer aware meshing - does not require dedicated coordinator hardware
  * high interference resiliency - bi-modal PHY to maximize connectivity in all conditions
  * dynamically resource optimized - powered motes naturally provide more routing assistance
  * zero metadata broadcast - same absolute privacy and security principles as telehash
  * dynamic spectrum - able to use any specialized private or regionally licensed bands
  
## The Need for Standards

The existing best choices are all either only partial solutions like 802.15.4, require membership to participate like LoRaWAN, ZigBee, and Z-Wave, or are focused on specific verticals like DASH7 and Wireless M-Bus.

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
* `knock` - a single transmission
* `window` - the period for a knock, 2^22 microseconds (~4.2 seconds)
* `window sequence` - each window will change frequency/channels in a sequence
* `epoch` - one unique set of window sequences, derived from a medium and a secret
* `community` - a network of motes using a common medium to create a large area mesh 
* `neighbors` - nearby reachable motes in the same community
* `z-index` - the self-asserted resource level (priority) from any mote
* `leader` - the highest z-index mote in any set of neighbors

## Overview

TMesh is the composite of three distinct layers, the physical radio medium encoding (PHY), the shared management of the spectrum (MAC), and the networking relationships between 2 or more motes (Mesh).

Common across all of these is the concept of an `epoch`, which is a generated set of unique window sequences shared between two motes in one `medium`.  A `window` is where one `knock` can occur from one mote to another unique to that window and epoch.  A `knock` is the transmission of a 64 byte fixed frame of payload, plus any medium-specific overhead (preamble).

Each epoch is the smallest divisible unit of bandwidth and is only capable of a max throughput of 120 bits per second average, approximately 1 kilobyte per minute. Every mote has at least one receiving epoch and one sending epoch per link to another mote, and will typically have multiple epochs with other motes to increase the overall bandwidth capacity and minimize latency.

The number and types of epochs available depend entirely on the current energy budget, every epoch type has a fixed minimum energy cost per window to send/receive based on the medium definition.

A community is any set of motes that are using a common medium definition and have enough trust to establish a telehash link for sharing peer motes and act as a router to facilitate larger scale meshing.  Within any community, the motes that can directly communicate over an epoch are called neighbors, and any neighbor that has a higher z-index is always considered the current leader and may have additional responsibilities.

### PHY

A `medium` is defined by 5 bytes that specify the PHY type and exact encoding details.  The 5 bytes are always string encoded as 8 base32 characters for ease of use in JSON and configuration storage.

The first byte is the primary `type` that determines if the medium is for a public or private community and the overall category of PHY encoding technique to use.  The first/high bit of 0 (byte values from 0-127) is for public communities, and a bit of 1 (values from 128-255) is for private ones.  The other bits in the `type` map directly to different PHY modes on transceivers or different drivers entirely.

Each PHY driver uses the second through fifth medium bytes to determine the power, frequency range, number of channels, spreading, bitrate, error correction usage, regulatory requirements, channel dwell time, etc details on the transmission/reception.  The dynamic channel frequency hopping and transmission window timing are derived from the full epoch and not included in the medium.

Transmitted payloads do not need whitening as encrypted packets are by nature DC-free.  They also do not explicitly require CRC as all telehash packets have authentication bytes included for integrity verification.

A single fixed 64 byte payload is transmitted during each window in an epoch, this is called a `knock`.  If the un-encrypted payload does not fill the full 64 byte frame the remaining bytes must contain additional data so as to not reveal the actual payload size.

> WIP - determine a standard filler data format that will add additional dynamically sized error correction, explore taking advantage of the fact that the inner and outer bitstreams are encrypted and bias-free (Gaussian distribution divergence?), the last byte should always duplicate the first/length to ensure differentiation between payload/filler

### MAC

There is no mote addressing or other metadata included in the transmitted bytes, including there being no framing outside of the encrypted ciphertext in a knock.  The uniqueness of each epoch's timing and PHY encoding is the only mote addressing mechanism.

Every epoch is a unique individual encrypted session between the two motes, with a shared secret key derived directly from the medium and other sources, and nonce based on the current window sequence. All payloads are encrypted with the [ChaCha20 cipher](http://cr.yp.to/chacha.html) before transmission regardless of if they are already encrypted via telehash.

Each mote should actively make use of multiple epochs to another mote and regularly include more efficient options to optimize the overall energy usage.  Every mote advertises their current energy resource level as a `z-index` as an additional mesh optimization strategy.

### Mesh

There is two mechanisms used for enabling a larger scale mesh network with TMesh, `communities` (MAC layer) and `routers` (telehash/app layer).

A `community` is defined by motes using a shared medium and the automatic sharing of other neighboring motes that it has active epochs with in that medium.  Each neighbor mote hashname is listed along with time offset, last activity, z-index, and the signal strength.  A mote may be part of more than one community but does not share neighbor mote information outside of each one.

The `leader` is always the neighbor with the highest z-index reachable directly, the mote with the most resources. The leader inherits the responsibility to monitor each neighbor's neighbors for other leaders and establish direct or bridged links with them.  

Any mote attempting to connect to a non-local hashname will use their leader as the telehash router and send it a peer request, whom will forward it to the next highest leader it is connected to until it reaches the highest in the community.  That highest resourced leader is responsible for maintaining an index of the available motes in the community.

Any mote that can provide reliable bridged connectivity to another network (wifi, ethernet, etc) should have a higher z-index and may also forward the peer request to additional telehash router(s) in the mesh via those networks.

# Protocol Definition

## Terminology
In this document, the key words "MUST", "MUST NOT", "REQUIRED",
"SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY",
and "OPTIONAL" are to be interpreted as described in BCP 14, [RFC 2119]
and indicate requirement levels for compliant TMesh implementations.


## PHY

* 8 bytes are encrypted
  * 4 for microsecond offset of next window, mask for speed
  * 4 for channel seed
  * output is used as nonce for next encryption

* 4 byte sequence
* 4 byte ūs ago
* z, exponent is mask
  * must be confirmed to change mask
  * z sent in handshake
* rssi
* nonce + secret
  * 8 byte zero pad, 4 for next ūs (then masked), 4 for channel

* frame has first byte for to/from
  * bit 1 is to/from
  * bit 2 is full or tail, if tail byte 2 is length
  * bit 3-8 is neighbor slot to/from

* private pairing unsync'd will look for seq x (first xmit), first packet must always be handshake and only one chunk until another rx'd
* private comm name is private
* pairing ping uses zeros nonce, base nonce is decipher'd, hashed, first 8 bytes, next window uses new nonce

* handshake sends z, lower of two is used for first channel packet window
* handshake at is used as nonce source
* public re-does secret based on hashnames

* secrets always hash(comm)+hash(medium)+hash(hn0)+hash(hn1)
* public beacons hashname using zero'd hn0/hn1 and nonce
  * first 32 are potential hn
  * once sent/received, reset secret, use last one as ping to derive nonce and time base for sync
* sync is 64 random bytes, cipher'd using zero nonce, first 8 decipher'd are then new base nonce
  * set base nonce, calc seq 0, begin handshakes
  * last handshake is time base for first window
  * reset nonce to be chacha(at,last nonce,secret)

* neighborhood map sends each nonce + offset + z
* to change z, must re-handshake
* each window is a tx/rx, the microsecond offset even/odd determins polarity of hashnames, match=tx




### Private Hopping Sequence

Most PHY encodings require specific synchronized channel and timing inputs, these are generated from the epoch's 32 byte secret via a consistent transformation.

An eight byte null/zero pad is encrypted with the current epoch secret/nonce for each window and the ciphertext result is used for channel selection and window timing.

The first two bytes of the ciphertext result is used for channel selection as a network order unsigned short integer.  The 2^16 total possible channels are simply mod'd to the number of usable channels based on the current medium.  If there are 50 channels, it would be `channel = ((uint16_t)pad) % 50`.

The next four bytes (32 bits) are used as the window microsecond offset timing source as a network order unsigned long integer.  Each window is up to 2^22 microseconds, but every medium will have a fixed amount of time it takes to send or receive within that window and that is first subtracted from the total possible microseconds.  The remaining microsecond offset start times are mod'd to get the exact offset for that window.

### Medium Types

Medium `type` byte table:


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

#### OOK

> TBD

#### (G)FSK

> TBD

#### LoRa

Epoch Header

* byte 2 - transmitting energy mA
* byte 3 - standard frequency range (see table)
* byte 4 - Bw & CodingRate (RegModemConfig 1)
* byte 5 - SpreadingFactor (RegModemConfig 2)

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

A unique 32 byte secret must be derived for every epoch and include the medium definition. The 32 bytes are the binary digest output of multiple SHA-256 calculations of source data from the community and hashnames.  The first digest is generated from the medium (5 bytes), that output is combined with the community name (string) for a second digest.

For public communities this second digest is the secret for the `PING` epoch that is shared and known by all members.  For private communities it is combined with a member's hashname (32 bytes) for a final digest that is the secret for the `PING` epoch unique to each member.  With direct communities the other member's hashname is also combined and a final (fourth) digest is the secret unique to that community and pair of members.

The nonce input is always the epoch's current window sequence encoded as a network order unsigned double integer (`uint64_t`) 8 bytes.  This provides an additional guarantee against replay or delay attacks as the ciphertext is invalid outside of a window.

### Epochs

While all epochs are the same construct of a medium, secret, window sequence, and tx/rx knocks, the context in how they're used may vary:

* `PING` - used as a timing source signal, only sequence 0
* `ECHO` - a response to a PING, is the one-time creation seed of a `PAIR`, only sequence 1
* `PAIR` - only used to send initial handshakes to establish a new link
* `LINK` - encrypted telehash channel packets for an established link

#### PING

A `PING` epoch is only used as a transmission timing signal on window sequence `0`. The payload is not used to send/receive any content and is only deciphered as a source to generate an `ECHO`.

When two motes have a shared secret to create this type of epoch they can then use available energy to listen for a `PING` knock at any time on the given channel for sequence `0`.  When detected, the relevant `ECHO` can be generated and sent/received in the next window relative to the `PING` knock.

#### ECHO

An `ECHO` epoch is the one-time response to a detected `PING` knock and only exists to assist with the establishment of ephemeral `PAIR` epochs for the handshaking process.

The secret for an `ECHO` epoch is derived from the medium and the deciphered payload of the `PING`.  For public communities the payload of a transmitted `PING` must be used as another source, whereas in a private community the receiving mote's hashname is the additional source to generate the secret.

The single `ECHO` knock is always set to window sequence `1` relative to the received `PING` at sequence `0`.

The payload is a pair of new ephemeral `PAIR` secrets, one for tx and one for rx.

#### PAIR

A pair of temporary `PAIR` epochs follow an `ECHO` and are only used to send/receive chunk-encoded handshakes to establish a telehash link.

Once the link is established the corresponding `LINK` epochs for the given community and hashnames are initialized using the same time base as the original `PING` and begin at the correct window sequences based on that.

#### LINK 

All `LINK` epochs follow a successful `PAIR` or are triggered by an out-of-band synchronization, their secret, medium, and time base are a result of those processes.

All `LINK` knocks are chunk-encoded encrypted telehash channel packets without the routing token prefixed.


## Mesh

### z-index

Every mote calculates its own `z-index`, a uint8_t value that represents the resources it has available to assist with the mesh.  It will vary based on the battery level or fixed power, as well as if the mote has greater network access (is an internet bridge) or is well located (based on configuration).

The z-index also serves as a window mask for all of that mote's receiving epoch windows by powers of two (128+ is all windows, 64-127 is half the windows, etc). This enables motes to greatly reduce the time required waking and listening for low power and high latency applications.

### Neighbors

Each mote should share enough detail about its active neighbors with every neighbor so that a neighborhood map can be maintained.  This includes the relative sync time of each community epoch such that a neighbor can predict when a mote will be listening or may be transmitting to another nearby mote.

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
