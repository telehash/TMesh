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
* `neighborhood` - the list of known nearby motes
* `z-index` - the self-asserted resource level (priority) from any mote
* `leader` - the highest z-index visible in any mote's neighborhood

## Overview

TMesh is the composite of three distinct layers, the physical radio medium encoding (PHY), the shared management of the spectrum (MAC), and the networking relationships between 2+ motes (Mesh).

Common across all of these is the concept of an `epoch`, which is a generated set of unique window sequences shared between two motes in one `medium`.  A `window` is where one `knock` can occur from one mote to another unique to that window and epoch.  A `knock` is the transmission of a 64 byte fixed frame of payload, plus any medium-specific overhead (preamble).

Each epoch is the smallest divisible unit of bandwidth and is only capable of a max throughput of 120 bits per second average, approximately 1 kilobyte per minute. Every mote has at least one receiving epoch and one sending epoch per link to another mote, and will typically have multiple epochs with other motes to increase the overall bandwidth capacity and minimize latency.

The number and types of epochs available depend entirely on the current energy budget, every epoch type has a fixed minimum energy cost per window to send/receive based on the medium settings.

### PHY

A `medium` is defined with 6 bytes that specify the type and exact PHY encoding details.  The 6 bytes are often encoded as 10 base32 characters for ease of use in JSON and configuration storage.

The first byte is a fixed `type` that determines the category of PHY encoding technique to use, often these are different modes on transceivers or different drivers entirely.

Each PHY driver uses the second through fifth medium bytes to determine the power, frequency range, number of channels, spreading, bitrate, error correction usage, regulatory requirements, channel dwell time, etc details on the transmission/reception.  The actual channel frequency hopping and transmission window timing are derived from the full epoch and not included in the medium.

The last (6th) byte is a fixed `divider` that lowers the density of available windows in an epoch.  This enables two motes to greatly reduce the time required waking and listening for low power and high latency applications. (format TBD)

Transmitted payloads do not need whitening as encrypted packets are by nature DC-free.  They also do not explicitly require CRC as all telehash packets have authentication bytes included for integrity verification.

A single fixed 64 byte payload is transmitted during each window in an epoch, this is called a `knock`.  If the un-encrypted payload does not fill the full 64 byte frame the remaining bytes must contain additional data so as to not reveal the actual payload size.

> WIP - determine a standard filler data format that will add additional dynamically sized error correction, explore taking advantage of the fact that the inner and outer bitstreams are encrypted and bias-free (Gaussian distribution divergence?), the last byte should always duplicate the first/length to ensure differentiation between payload/filler

### MAC

There is no mote addressing or other metadata included in the transmitted bytes, including there being no framing outside of the encrypted ciphertext in a knock.  The uniqueness of each epoch's timing and PHY encoding is the only mote addressing mechanism.

Every epoch is a unique individual encrypted session between the two motes, with a shared secret key derived directly from the medium and other sources, and nonce based on the current window sequence. All payloads are encrypted with the [ChaCha20 cipher](http://cr.yp.to/chacha.html) before transmission regardless of if they are already encrypted via telehash.

Each mote should actively make use of multiple epochs to another mote and include more efficient options to optimize the overall energy usage.  Every mote advertises their current energy resource level as a `z-index` as an additional mesh optimization strategy.

### Mesh

There is two mechanisms used for enabling a larger scale mesh network with TMesh, `neighborhoods` (MAC layer) and `routers` (telehash/app layer).

A `neighborhood` is the automatic sharing of other motes that it has active epochs with.  Each neighbor mote is listed along with all of the mediums in use, last activity, and the signal strength for each medium.

A `router` is always the neighbor with the highest z-index, which inherits the responsibility to monitor each neighbor's neighborhood for other routers and establish direct or bridged links with them.  Any mote with a packet for a non-local hashname will send it to their router, whom will send it to the next highest router it is connected to until it reaches the highest in the mesh.  The highest resourced router is responsible for maintaining an index of all available motes/hashnames in the mesh.


# Protocol Definition

## Terminology
In this document, the key words "MUST", "MUST NOT", "REQUIRED",
"SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY",
and "OPTIONAL" are to be interpreted as described in BCP 14, [RFC 2119]
and indicate requirement levels for compliant TMesh implementations.


## PHY


### Private Hopping Sequence

Most PHY encodings require specific synchronized channel and timing inputs, these are generated from the epoch's 32 byte secret via a consistent transformation.

An eight byte null/zero pad is encrypted with the current epoch secret/nonce for each window and the ciphertext result is used for channel selection and window timing.

The first two bytes of the ciphertext result is used for channel selection as a network order unsigned short integer.  The 2^16 total possible channels are simply mod'd to the number of usable channels based on the current medium.  If there are 50 channels, it would be `channel = ((uint16_t)pad) % 50`.

The next four bytes (32 bits) are used as the window microsecond offset timing source as a network order unsigned long integer.  Each window is up to 2^22 microseconds, but every medium will have a fixed amount of time it takes to send or receive within that window and that is first subtracted from the total possible microseconds.  The remaining microsecond offset start times are mod'd to get the exact offset for that window.

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

A unique 32 byte secret must be derived for every epoch and include the medium definition.  The additional sources for the secret depend on the context in which the epoch is used, and may range from a fixed value (for discovery), shared value (for sync), or ephemeral value (link routing tokens).  The 32 bytes are typically the binary digest output of a SHA-256 calculation of the combined sources.

The nonce input is always the epoch's current window sequence encoded as a network order unsigned double integer (`uint64_t`) 8 bytes.

### Epoch Types

There are currently five different types of epochs defined:

* `PING` - only for ad-hoc discovery mode
* `SYNC` - only for synchronization signals
* `BASE` - only used for one-time creation of an `INIT`
* `INIT` - only used to send initial handshakes to establish a new link
* `LINK` - encrypted telehash packets for an established link

### PING (discovery)

When a new un-linked mote must be introduced directly into a mesh and there is no out-of-band mechanism to bootstrap mote keys and time sync, a special temporary discovery mode may be enabled on any existing mote to assist.  Both motes must have the same discovery medium and secret for this process to work.

The discovery epoch is used as a `PING` for both motes, with each of them transmitting their ping knocks containing offers.  Since they will both be using the same PHY channel, if possible they should first listen for a transmission in progress before sending another offer to minimize interference.

The discovery ping knocks must always have a random 64 byte payload.  It is also always set to window sequence 0 so that the PHY is stable since the time of the windowing is not.

Once one ping knock has been both sent and received the mote may then derive a compatible `BASE` epoch and send a knock on it or listen for other base knocks.

Upon receiving any `BASE` knock the mote should immediately create the pair of `INIT` epochs and begin sending/receiving unencrypted handshakes until a `LINK` epoch is established.

This functionality should not be enabled/deployed by default, it should only be used when management policy explicitly requires it for special/public use cases or temporary pairing/provisioning setup.

### SYNC Epochs

The synchronization process requires a shared or commonly configured source of sync mediums or out of band mechanism for exchanging them dynamically.  A `SYNC` epoch only assists with background synchronization and establishment of a unique one-time `BASE` epoch and pair of `INIT` epochs for the handshaking process.

The secret for a sync epoch is typically derived from the medium and the mote's hashname as sources so that any mote in the mesh can look for sync knocks.

Each sync knock is always set to window sequence 0 so that the PHY is stable since the time of the windowing is not.

The sync mode takes advantage of the fact that every epoch makes use of a shared medium that is divided into channels, such that every sync epoch will have some overlap with other private link epochs that a mote is transmitting on.  When any mote sends any knock that happens to be on the same channel as one of their sync epoch's (sequence 0), they should then attempt to receive a `BASE` knock exactly one window period after the transmission.

The local leader should attempt to maximize their use of sync epoch overlapping channels to allow for fast resynchronization to them, even to the point of sending arbitrary/random knocks on that channel if nothing has been transmitted recently. When a mote detects that it is disconnected, it should also send regular knocks on the sync epoch channels of nearby known motes.

### BASE Epochs

An `BASE` epoch only follows a `SYNC` (same secret) or `PING` (secret derived from sent/received ping knock payloads) and has a payload of a pair of new ephemeral `INIT` secrets, one for tx and one for rx.

### INIT Epochs

A pair of temporary `INIT` epochs only follow a `BASE` and are only used to send/receive chunk-encoded handshakes to establish one or more new `LINK` epochs.

Any `LINK` epochs defined in the encrypted handshakes will have the same time base as the `SYNC` and begin and the correct window sequences based on that.

### LINK Epochs

All `LINK` epochs follow a successful `INIT` or are triggered by an out-of-band synchronization, their time base and unique epoch ID is a result of those processes.

The secret for the epoch is always derived from the corresponding telehash link routing token.  All knocks are chunk-encoded encrypted telehash packets.


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
* when you know a link's neighbors you can use their mediums active to estimate congestion/energy requirements


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
