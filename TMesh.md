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
* retransmissions and acknowledgements happen at a higher level and are not required
* motes are members of a private mesh and only communicate with other verified members

## Basic Operation - PHY

All radio PHY operations are bi-modal, with a `hard knock` and a `soft knock`.  Each `knock` is a single private transmission from one mote to another using an established telehash link session between them.

The `hard knock` is designed for maximum compatibility across any type of hardware transceiver and is not optimized for energy efficiency, it is the fallback mode after multiple `soft knock` failures.

The `soft knock` is designed to take advantage of a transceivers most efficient modes and capabilities, multiple `soft knock` specifications exist, one for each major transceiver.

Transmitted payloads do not need whitening as encrypted packets are inherently DC-free.  They also do not need CRC as all packets have authentication bytes included.
 

## Basic Operation - MAC

* trusted peers only, administration/provisioning adds/removes
* each mote has a list of RF neighbors that it learns/discovers/shares, a neighborhood
* share their resource level, local leader is who has the most
* concept of soft and hard `knocks`, for optimal spectrum energy usage vs. highest compatible range
* discoverable mode for provisioning only, beacon's its key with a hard knock
* link is unique to each pair, every link is a unique rotating PHY pattern
* soft knock (lowest power best settings, LoRa) and then hard knock (highest power worst settings, FSK)
* each mote keep X soft knock neighbors and Y hard knock neighbors
* a knock is purely boolean, when one is received it means start listening in that mode
* try to keep soft/hard lists minimum but reliable, quiesce shrinks size of each
* send packet for a mote directly to it, and then fallback to one known neighbor, then to the local leader
* lost mode when all link state is lost, local leaders must help beacon for them to resync
* resource based routing, highest resource gets undelivered packets
* highest leader for the whole mesh is responsible for mapping the full mesh, collecting undelivered’s and re-routing them
* natural pooling around local resources, neighborhoods
* when you know a link's neighbors you can calculate their knock windows and use one instead of waiting for yours
* soft knock is short and LNA/expensive for recipient, hard knock is long and cheaper for recipient


# Protocol Definition

## Terminology
In this document, the key words "MUST", "MUST NOT", "REQUIRED",
"SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY",
and "OPTIONAL" are to be interpreted as described in BCP 14, [RFC 2119]
and indicate requirement levels for compliant TMesh implementations.



## Link Windows

* link ids determine window pattern
* step through each bit of the id
  * derive unique soft/hard knock parameters
  * derive time until next window
  * each pass through the full id is called an `epoch`
* a confirmed knock over any link is a sync, know the current bit the sender is on for all their links
* can use a neighbors window if no soft knock is detected, send hard knock
* sleepy motes calculate the epoch peak density across all their neighbors and only wake then
  * knocks are only tried twice outside of that peak, and once again inside

## Knocks

* preamble/sync is derived from link id and window bit
* only identifies the window, not the sender
* payload is the sender's link id or a new link request
* immediately knock back w/ the same data as a continue/ready
* if no soft knock back, immediately hard knock the same
* after knock-knock, same preamble and packet payload
* knock to continue any more packets
* sleep after no more
* if busy until next transmit window, always skip it
* never transmit into the next receive window
* requires no application logic/lookups/parsing
* requires no spectral detection

## Flow

1. mote must be initially paired to another
  * handshakes
  * z-index priority set
  * link established
  * link id created (routing token and z-index byte)
1. existing mote informs mesh of new link
  * sends to mesh leader for overall routing
  * if link is a neighbor, updates other neighbors
1. existing mote shares mesh to new mote
  * sends its neighbors
  * sends the mesh top leader list
1. new mote attempts to reach neighbors to establish links
1. build/maintain neighborhood list of X soft and Y hard knock
1. each mote sends its neighborhood to each neighbor after it's changed since the last epoch
1. a neighbor is only considered lost after it has not responded to a full epoch

## Lost

* after any power reset (loss of link state), or after a full epoch of no responses to any knocks
* begin listening for any hard knocks, detect link id and sync to it then handshake there
* if sleepy, only listen on the lost schedule
* local leaders are required to hard knock per epoch on the lost schedule


# Implementation Notes

notes


# Security Considerations

telehash based

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
