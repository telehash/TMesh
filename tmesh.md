<?xml version="1.0" encoding="UTF-8"?>
  <?xml-stylesheet type='text/xsl' href='rfc2629.xslt' ?>

<!DOCTYPE rfc SYSTEM "rfc2629.dtd" [
]>

<rfc ipr="trust200902" docName="draft-miller-tmesh-00" category="info" >

<?rfc toc="yes"?>
<?rfc sortrefs="yes"?>
<?rfc symrefs="yes" ?>

  <front>
    <title abbrev="tmesh">
      Thing Mesh
    </title>
    <author initials="J" surname="Miller" fullname="Jeremie Miller">
      <organization>Filament</organization>
      <address>
        <email>jeremie@jabber.org</email>
      </address>
    </author>


    <date year="2015" month="May" day="15"/>

    <area>General</area>
    <workgroup></workgroup>
    <keyword>Internet-Draft</keyword>
    <abstract>
      <t>
      Low-power devices and long-range radios, PHY/MAC for telehash
      </t>
    </abstract>
  </front>

  <middle>

{:/nomarkdown}

Introduction        {#problems}
============

Low-power devices and long-range radios, PHY/MAC for telehash {{telehash}}

  * high density
  * very low power
  * long range only
  * high lateny only
  * peer aware meshing
  * high interference resiliency
  * dynamic resource optimized (powered/gateway motes become natural leaders)
  * same absolute principles as telehash, no identity on the air

The Need for Standardization   {#need}
----------------------------

Only leaky, centralized, and commercial options.


Basic Protocol Operation   {#ops}
========================

Overview


Protocol Definition
===================

Terminology          {#Terminology}
-----------
In this document, the key words "MUST", "MUST NOT", "REQUIRED",
"SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY",
and "OPTIONAL" are to be interpreted as described in BCP 14, RFC 2119
{{RFC2119}} and indicate requirement levels for compliant STuPiD
implementations.


Foo
----------------------------------------

bar.


Implementation Notes
====================

notes


Security Considerations
=======================

telehash based

{::nomarkdown}

</middle>

<back>

  <references title='Normative References'>

{:/nomarkdown}
![:include:](RFC2119)

{::nomarkdown}

  </references>

  <references title='Informative References'>

{:/nomarkdown}


<reference anchor="telehash"  target="http://telehash.org">
<front>
<title>telehash protocol v3.0</title>
<author fullname="Jeremie Miller" initials="J" surname="Miller">
</author>
<date month='April' day='7' year='2015' />

</front>
</reference>


{::nomarkdown}
  </references>
{:/nomarkdown}

Examples  {#xmp}
========

This appendix provides some examples of the tmesh protocol operation.

~~~~~~~~~~
   Request:


   Response:


{::nomarkdown}

</back>
</rfc>
