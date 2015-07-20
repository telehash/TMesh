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

  * high density - thousands per square mile
  * very low power - years on coin cell batteries
  * wide area - optimized for long-range capable radios
  * high latency - low minimum duty cycle from seconds to minutes
  * peer aware meshing - does not require dedicated coordinator motes
  * high interference resiliency - bi-modal PHY to maximize connectivity in all conditions
  * dynamically resource optimized - powered motes naturally provide more assistance
  * zero metadata broadcast - same absolute privacy and security principles as telehash
  
## The Need for Standards

The existing best choices are all either only partial solutions like 802.15.4, require membership to participate like LoRaWAN, ZigBee, and Z-Wave, or are focused on specific verticals like DASH7 and Wireless M-Bus.

All other options only provide incomplete or indadequate security and privacy, most use only optional AES-128 and often with complicated or fixed provisioning-based key management.  No existing option attempts to protect the mote identity and network metadata from monitoring.

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
* `knock` - a single transmission
* `window` - the period for a knock, 2^22 microseconds (~4.2 seconds)
* `window sequence` - each window will change frequency/channels in a sequence
* `epoch` - one unique set of window sequences, derived from an 8 byte header and 8 random byte footer
* `neighborhood` - the list of known nearby motes
* `z-index` - the self-asserted resource level (priority) from any mote
* `leader` - the highest z-index visible in any mote's neighborhood

## Overview

TMesh is the composite of three distinct layers, the physical radio medium encoding (PHY), the shared management of the spectrum (MAC), and the networking relationships between 2+ motes (Mesh).

Common across all of these is the concept of an `epoch`, which is a generated set of unique window sequences shared between two motes.  A `window` is where one `knock` can occur from one mote to another with a specified PHY unique to that window and epoch.  A `knock` is the transmission of a 64 byte fixed frame of payload, plus any PHY-specific overhead (preamble).

Each epoch is the smallest divisible unit of bandwidth and is only capable of a max throughput of 120 bits per second average, approximately 1 kilobyte per minute. Every mote has at least one receiving epoch and one sending epoch per link to another mote, and will often have multiple epochs with other motes to increase the overall bandwidth available.

The number and types of epochs available depend entirely on the current energy budget, every epoch type has a fixed minimum energy cost for its lifetime.

### PHY

An `epoch` is defined with a unique 16-byte identifier, specifying the exact PHY encoding details and including random bytes that serve as a shared key for that epoch.

The first byte is a fixed `type` that determines the category of PHY encoding technique to use, often these are different modes on transceivers.  The following 1-7 bytes are headers that are specified by each type of encoding, and the remaining 8 bytes are always a unique random seed footer that is typically composed by combining two sources of random bytes in different orders to specify directions (A+B=tx, B+A=rx).

The PHY encoding uses the headers to determine the power, frequency range, spreading, bitrate, error correction usage, etc details on the transmission/reception.  The specific channel frequency hopping and transmission window timing are derived from the full epoch ID and are unique to each epoch.

Regulatory restrictions around channel dwell time may require additional frequency channel changes during one window as determined by each specific PHY implementation.

Transmitted payloads do not need whitening as encrypted packets are by nature DC-free.  They also do not require CRC as all telehash packets have authentication bytes included for integrity verification.

A single fixed 64 byte payload is transmitted during each window in an epoch, this is called a `knock`.  If the un-encrypted payload does not fill the full 64 byte frame the remaining bytes must contain additional data so as to not reveal the actual payload size.

> WIP - determine a standard filler data format that will add additional dynamically sized error correction, explore taking advantage of the fact that the inner and outer bitstreams are encrypted and bias-free (Gaussian distribution divergence?), the last byte should always duplicate the first/length to ensure differentiation between payload/filler

### MAC

There is no mote addressing or other metadata included in the transmitted bytes, including there being no framing outside of the encrypted ciphertext in a knock.  The uniqueness of each epoch's timing and PHY encoding is the only mote addressing mechanism.

Every epoch is a unique individual encrypted session between the two motes, with a shared private key generated from the full epoch ID. All payloads are AES-128 encrypted again before transmission regardless of if they are already encrypted via telehash.

Additional MAC-only packet types are defined for re-synchronizing two motes and enabling a discovery mode for initial pairing.

Each mote should actively make use of multiple epochs to another mote and include more efficient options to optimize the overall energy usage.  Every mote advertises their current energy resource level as a `z-index` as an additional mesh optimization strategy.

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

### Private Hopping Sequence

Most PHY encodings require specific synchronized channel and timing inputs, these are generated from the shared epoch ID via a consistent transformation.

The 16 byte epoch ID is first SHA-256 encoded to get a 32 byte digest.  The first 16 bytes of that digest are used as the shared AES-128 `sequence-key` between the motes.  The window sequence number is always used as the IV input.  An AES encrypt is then performed on size 0x00 bytes to derive the unique pad for this window.

The first two bytes of this pad are the channel selection, the 2^16 total possible channels are simply mod'd to the number of usable channels based on the current PHY type.  If there are 50 channels, it would be `channel = ((uint16_t)pad) % 50`.

The next four bytes (32 bits) of this pad are the window microsecond offset timing source.  Each window is up to 2^22 microseconds, but every PHY will have a fixed amount of time it takes to send or receive within that window and that is always subtracted from the total possible microseconds first.  The remaining microsecond offset start times are mod'd to the 32 bit generated source number to get the exact offset for that window.

### Epoch Types

Epoch type table:

| Byte  | Encoding
|-------|---------
| 0x00  | Reserved
| 0x01  | OOK
| 0x02  | (G)FSK
| 0x03  | LoRa
| 0x04  | (O)QPSK

#### OOK

TBD

#### (G)FSK

TBD

#### LoRa

Epoch Header

* byte 1 - transmitting energy mA
* byte 2 - standard frequency range (see table)
* byte 3 - Bw & CodingRate (RegModemConfig 1)
* byte 4 - SpreadingFactor (RegModemConfig 2)
* byte 5-7 - zeros (reserved)

All preambles are set to the minimum size of 6.

LoRa is used in implicit header mode with a fixed size of 64.

Freq Table:

| Region | Low | High | mW (erp) | Reg             | ID   |
|--------|-----|------|----------|-----------------|------|
| US     | 902 | 928  | 100      | FCC part 15.247 | 0x01 |
| EU     | 863 | 870  |          | ETSI EN 300-220 | 0x02 |
| Japan  | 915 | 930  |          | ARIB T-108      | 0x03 |
| China  | 779 | 787  | 10       | SRRC            | 0x04 |

In the US region 0x01 to reach maximum transmit power each window may transmit on a channel for more than 400ms, when that limit is reached a new pseudo-random frequency must be derived from the Epoch and hopped to.  See [App Note](https://www.semtech.com/images/promo/FCC_Part15_regulations_Semtech.pdf).

Notes on ranges:
* [SRRC](http://www.srrccn.org/srrc-approval-new2.htm)
* [Z-Wave](http://image.slidesharecdn.com/smarthometechshort-13304126815608-phpapp01-120228010616-phpapp01/95/smart-home-tech-short-14-728.jpg)
* [Atmel](http://blog.atmel.com/2013/04/23/praise-the-lord-a-new-sub-1ghz-rf-transceiver-supporting-4-major-regional-frequency-bands/)


#### (O)QPSK

TBD

## MAC

### Private Knock Encryption

One epoch is also a private encrypted session between the two motes.  The epoch's 16 bytes are first SHA-256 encoded to get a 32 byte digest.  The second 16 bytes of the digest are used as the AES-128 `knock-key` and the IV is based on adding the current window sequence counter to a given 8 byte random IV-pad.  All knocks transmitted in the first window `0` must always include the 8 byte random IV-pad at the beginning of the payload and it must be re-generated with each repeated transmission.  At no point is the source IV transmitted again in the epoch.

When an epoch is initialized from another source starting from a higher window sequence the shared private IV-pad must be provided. This helps maximize the privacy and uniqueness of every knock between any two motes.

### Payload Types

Since a payload is always encrypted and there are no framing bytes transmitted, the only way to determine different types of payloads is through the context of the epoch itself.

There are currently three different types of epochs defined:

* `SYNC` - used for synchronization signalling
* `INIT` - only used to send initial encrypted handshakes to create a new link
* `LINK` - encrypted telehash packets from an established link

### SYNC Epochs

The synchronization process requires a shared or commonly configured source of epoch IDs or out of band mechanism for exchanging them dynamically.  A `SYNC` epoch only assists with background synchronization and establishment of a unique one-time `INIT` epoch for the handshaking process.

With every sync knock one or more motes may be receiving and transmitting at the same time on the same epoch increasing the risk of interference so they are only used as strictly necessary and as infrequently as possible.

Each sync knock is always set to window sequence 0 so that the PHY is stable since the time of the windowing is not, the payload always includes the prefixed 8 IV bytes. The encrypted payload of 56 bytes contains:

* `0..3` Cipher Sets supported (optional, up to 4 ordered CSIDs)
* `4..7` random seed (4 bytes)
* `8..15` header offer 1 (required)
* `16..23` header offer 2 (optional)
* `24..31` header offer 3 (optional)
* `32..39` header offer 4 (optional)
* `40..47` header offer 5 (optional)
* `48..55` header offer 6 (optional)

When a sync knock has been received and processed, the receiving mote may decide to begin an `INIT` epoch using the received sync knock as the time base for window 0 of that new `INIT` epoch and the ID generated from both a sent and received sync knock.

The 4 Cipher Set IDs are only included when discovery mode is enabled, and are 0xFF bytes in all other sync knocks.

#### Mesh Synchronization Epochs

Every mesh or mote must define and share one or more common `mesh sync headers` that are used to generate the `SYNC` epochs that assist with background synchronization of any disconnected motes.  These headers may be common across an entire mesh, or may be uniquely defined by each mote and exchanged out of band (via a telehash path channel, for instance).

The mesh sync headers (8 bytes) are always combined with the first 8 bytes of each mote's hashname to derive every mote-specific `sync epoch`.

The sync mode takes advantage of the fact that every epoch makes use of a shared medium that is divided into channels, such that every sync epoch will have some overlap with other private link epochs that a mote is transmitting on.  When any mote sends any knock that happens to be on the same channel as one of their sync epoch's (sequence 0), they should then attempt to receive a sync knock exactly one window period after the transmission.

The local leader should attempt to maximize their use of sync epoch overlapping channels to allow for fast resynchronization to them, even to the point of sending arbitrary/random knocks on that channel if nothing has been transmitted recently. When a mote detects that it is disconnected, it should also send regular knocks on the sync epoch channels of nearby known motes.

### INIT Epochs

An `INIT` epoch only follows a `SYNC` and is generated from the information included in it.  The header is from the sync knock and the footer combines the 4 byte seed from the sync knock with 4 bytes determined by the recipient depending on the current context between the motes.  The IV used for this epoch is always carried from the received sync knock.

These are always private to two motes and are used for both transmit and receive between them.  The window sequence always starts at `1` since the epoch is the result of a `SYNC` and the first knock is always an accept knock that signals the acceptance of a new `INIT`.  The accept knock payload depends on the context, when discoverability is enabled it will contain the Cipher Set Key bytes padded with zeros, and during mesh synchronization it will be all 0xFF bytes.

The recipient of the accept knock may then respond with one or more chunk-encoded handshakes over this epoch, which after being processed the recipient of the handshake(s) may respond with handshakes in turn.

Any `LINK` epochs defined in the encrypted handshakes will have the same time base as the `SYNC` and begin and the correct window sequences based on that.

### LINK Epochs

All `LINK` epochs follow a successful `INIT` or are triggered by an out-of-band synchronization, their time base and unique epoch ID is a result of those processes.

The IV base for the epoch is always the first 8 bytes of the corresponding telehash link routing token.  All knocks are chunk-encoded encrypted telehash packets, either sync or async types.

### Discovery Mode

When a new un-linked mote must be introduced directly into a mesh and there is no out-of-band mechanism to bootstrap mote keys and time sync, a special temporary discovery mode may be enabled on any existing mote to assist.  Both motes must have the same shared discovery epoch ID for this process to work.

The discovery epoch ID is used as a `SYNC` for both motes, with each of them transmitting their sync knocks containing offers.  Since they will both be using the same PHY channel if possible they should first listen for a transmission in progress before sending another sync knock to minimize interference.

The discovery sync knocks must always include the CSIDs supported, and the 4 byte seeds included should be randomly generated with every transmission.

Once one sync knock has been both sent and received the mote may then derive a compatible `INIT` epoch and attempt to being that with an accept knock.  These accept knocks must contain the correct Cipher Set Key bytes so that the recipient mote may respond with a valid encrypted handshake.

This functionality should not be enabled/deployed by default, it should only be used when management policy explicitly requires it for special/public use cases or temporary pairing/provisioning setup.


## Mesh

Describe neighborhoods and routers, and routers performing ongoing sync-mode duties.

### z-index

Every mote calculates its own `z-index`, a uint8_t value that represents the resources it has available to assist with the mesh.  It will vary based on the battery level or fixed power, as well as if the mote has greater network access (is an internet bridge) or is well located (based on configuration).

The mote with the highest `z-index` in any neighborhood is known as the `local leader`.

The z-index also serves as a window mask for all of that mote's receiving epoch windows by powers of two.

## Notes

* if a packet chunk is incomplete in one window, prioritize subsequent windows from that mote
* send packet for a mote directly to it, and then fallback to one known neighbor, then to the local leader
* sync mode is when all link state is lost or all epochs expired, local leaders run the sync epochs and may coordinate to minimize
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
