# WB2AXIP: A Pipelined Wishbone B4 to AXI4 bridge

Built out of necessity, [this core](rtl/wbm2axisp.v) is designed to provide
a conversion from a [wishbone
bus](http://zipcpu.com/zipcpu/2017/11/07/wb-formal.html) to an AXI bus.
Primarily, the core is designed to connect a
[wishbone bus](http://zipcpu.com/zipcpu/2017/11/07/wb-formal.html),
either 32- or 128-bits wide, to a 128-bit wide AXI bus, which is the natural
width of a DDR3 transaction (with 16-bit lanes).  Hence, if the
Memory Interface Generator DDR3 controller is running at a 4:1 clock rate,
memory clocks to AXI system clocks, then it should be possible to accomplish
one transaction per clock at a sustained or pipelined rate.  This
[bus translator](rtl/wbm2axisp.v) is designed to be able to handle one
transaction per clock (pipelined), although [(due to Xilinx's MIG design)
the delay may be up to 27 clocks](http://opencores.org/project,wbddr3).  (Ouch!)

Since the initial build of the core, I've added the
[WB to AXI lite](rtl/wbm2axilite.v) bridge.  This is also a pipelined bridge,
and like the original one it has also been formally verified.

# AXI to Wishbone conversion

As of 20181228, the project now contains an
[AXI4 lite read channel to wishbone interface](rtl/axilrd2wbsp.v), and also an
[AXI4 lite write channel to wishbone interface](rtl/axilwr2wbsp.v).
A third core, the [AXI-lite to WB core](rtl/axlite2wbsp.v) combines these
two together using a  [Wishbone arbiter](rtl/wbartbiter.v).  All four of these
designs have been *formally verified*, and should be reliable to use.

As of 20190101, [this AXI-lite to WB bridge](rtl/axlite2wbsp.v) has been
FPGA proven.

The full AXI4 protocol, however, is rather complicated--especially when
[compared to WB](http://zipcpu.com/zipcpu/2017/11/07/wb-formal.html).  As a
result, while there is a full-fledged
[AXI4 to Wishbone bridge](rtl/axim2wbsp.v) within this project,
this bridge is still not ready for prime time.  It is designed to
synchronize the write channels, turning AXI read/write requests into pipeline
wishbone requests, maintaining the AXI ID fields, handle burst transactions,
etc. The only problem is ...
this full AXI4 to WB converter _doesn't work_ (yet).  I know this because it
doesn't yet pass formal verification.

If you need an AXI4 to WB capability, consider using this [AXI2AXILITE](rtl/axi2axilite.v)
core to bridge from AXI to AXI-lite, and then [this AXI-lite to WB
bridge](rtl/axlite2wbsp.v) bridge to get to wishbone pipeline.  If you need
WB classic, you can then use [this pipeline to classic
bridge](rtl/wbp2classic.v).

# Wishbone pipeline to WB Classic

There's also a [Wishbone (pipelined, master) to Wishbone
(classic, slave)](rtl/wbp2classic.v) bridge, as well as the reverse
[Wishbone (classic, master) to Wishbone (pipelined, slave)](rtl/wbc2pipeline.v)
bridge.  Both of these have passed their formal tests.  They are accompanied
by a set of formal properties for Wishbone classic, both for
[slaves](bench/formal/fwbc_slave.v) as well as
[masters](bench/formal/fwbc_master.v).

# Formal Verification

Currently, the project contains formal specifications for
[Avalon](bench/formal/fav_slave.v), [Wishbone
(classic)](bench/formal/fwbc_slave.v), [Wishbone
(pipelined)](bench/formal/fwb_slave.v), and
[AXI-lite](bench/formal/faxil_slave.v) buses.  There's also a formal
property specification for an [AXI (full) bus](bench/formal/faxi_slave.v), but
the one in the master branch is known to have issues.  (I actually have a
good set of formal properties for verifying full AXI transactions.)

# Xilinx Cores

The formal properties were first tested on a pair of Xilinx AXI demonstration
cores.  These cores failed formal verification.  You can read about them
on [my blog, at zipcpu.com](https://zipcpu.com), [here for
AXI-lite](http://zipcpu.com/formal/2018/12/28/axilite.html) and
[here for AXI](http://zipcpu.com/formal/2019/05/13/axifull.html).
You can find the Xilinx cores referenced in those articles
[here](bench/formal/xlnxdemo.v) and [here](bench/formal/xlnxfull_2018_3.v) for
reference, for those who wish to repeat or examine my proofs.

# Cross-bars and AXI demonstrators

This repository has since become a repository for all kinds of bus-based
odds and ends in addition to the bus translators mentioned above.  Some of
these odds and ends include crossbar switches and AXI demonstrator cores.

- [WBXBAR](rtl/wbxbar.v) is a fully function N master to M slave Wishbone
  crossbar.  Unlike my typical WB interconnects, this one guarantees that the
  ACK responses won't get crossed, and that misbehaving slave accesses will
  be timed out.  The core also has options for checking for starvation
  (where a master's request is not granted in a particular period of time),
  double-buffering all outputs (i.e. with skid buffers), and forcing idle
  channel values to zero in order to reduce power.

  *This core has been formally verified.*

- [AXILXBAR](rtl/axilxbar.v) is a fully functional, formally verified, `N`
  master to `M` slave AXI-lite crossbar interconnect.  As such, it permits
  `min(N,M)` active channel connections between masters and slaves all at once.
  This core also has options for low power, whereby unused outputs are forced
  to zero, and lingering.  Since the AXI protocol doesn't specify exactly
  when to close a channel, there's an `OPT_LINGER` allowing you to specify
  how many cycles the channel should be idle for in order for the channel
  to be closed.  If the channel is not closed, a clock can be spared when
  reusing it.  Otherwise, two clocks will be required to access a given channel.

  *This core has been formally verified.*

  While I haven't tested Xilinx's interconnect to know, if the quality of
  [their demonstration AXI-lite slave
  core](http://zipcpu.com/formal/2018/12/28/axilite.html) is any
  indication, then this cross-bar should easily outperform anything they have.
  The key unusual feature?  The ability to maintain one transaction per clock
  over an extended period of time across any channel pair.

- [AXILSINGLE](rtl/axilsingle.v) is designed to be a companion to
  [AutoFPGA](https://github.com/ZipCPU/autofpga)'s AXI-lite support.  It's
  purpose is to simplify connectivity logic when supporting multiple AXI-lite
  registers.  This core takes a generic AXI-lite interface, and simplifies
  the interface so that multiple single-register cores can be connected to
  it.  The single-register cores can either be full AXI-lite cores in their
  own respect, subject to simplification rules, or even simplified from that.
  They must never stall the bus, and must always return responses within one
  clock cycle.  The [AXILSINGLE](rtl/axilsingle.v) handles all backpressure
  issues.  If done right, the backpressure logic from the slave core will be
  removed by the synthesis tool, allowing all backpressure logic to be
  condensed into a few shared wires.

  *This core has been formally verified.*

- [AXILDOUBLE](rtl/axildouble.v) is the second AXI-lite companion to
  [AutoFPGA](https://github.com/ZipCPU/autofpga)'s AXI-lite support.  It's
  purpose is to simplify connectivity logic when supporting multiple AXI-lite
  slaves.  This core takes a generic AXI-lite interface, and simplifies
  the interface so that peripherals can be connected to it.  These
  peripherals cores can either be full AXI-lite cores in their own respect,
  subject to simplification rules discussed within, or even simplified from
  that.  They must never stall the bus, and must always return responses
  within one clock cycle.  The [AXILDOUBLE](rtl/axildouble.v) core handles all
  backpressure issues, address selection, and invalid address returns.

  *This core has been formally verified.*

- [AXIXBAR](rtl/axixbar.v) is a fun project to develop a full `NxM`
  configurable cross bar using the full AXI protocol.

  Unique to this (full) AXI core is the ability to have multiple ongoing
  transactions on each of the master-to-slave channels.  Were Xilinx's
  crossbar to do this, it would've broken their [demonstration AXI-full slave
  core](http://zipcpu.com/formal/2019/05/13/axifull.html).

  *This core has been formally verified.*

- [DEMOAXI](rtl/demoaxi.v) is a demonstration AXI-lite slave core with more
  power and capability than Xilinx's demonstration AXI-lite slave core.
  Particular differences include 1) this one passes a formal verification check
  (Xilinx's core has bugs), and 2) this one can handle a maximum throughput of
  one transaction per clock.  (Theirs did at best one transaction every other
  clock period.)  You can read more about this [demonstration AXI-lite slave
  core](rtl/demoaxi.v) on [ZipCPU.com](http://zipcpu.com) in
  [this article](http://zipcpu.com/blog/2019/01/12/demoaxilite.html).

  *This core has been formally verified.*

- [DEMOFULL](rtl/demofull.v) is a fully capable AXI4 demonstration slave core,
  rather than just the AXI-lite protocol.  Well, okay, it doesn't do anything
  with the PROT, QOS, CACHE, and LOCK flags, so perhaps it isn't truly the
  *full* AXI protocol.  Still, it's sufficient for most needs.

  Unlike [Xilinx's demonstration AXI4 slave
  core](http://zipcpu.com/formal/2019/05/13/axifull.html),
  [this one](rtl/demofull.v) can handle 100% loading on both read and write
  channels simultaneously.  That is, it can handle one read and one write beat
  per channel per clock with no stalls between bursts if the environment will
  allow it.

  *This core has been formally verified.*

- [AXISAFETY](rtl/axisafety.v) is a bus fault isolator AXI translator,
  designed to support a connection to a trusted AXI master, and an untrusted
  AXI slave.  Should the slave attempt to return an illegal response, or
  perhaps a response beyond the internal timeouts within the core, then the
  untrusted slave will be "disconnected" from the bus, and a bus error will be
  return for both the errant transaction and any following.

  *This core has been formally verified.*

  [AXISAFETY](rtl/axisafety.v) also has a mode where, once a fault has been
  detected, the slave is reset and allowed to return to the bus infrastructure
  until its next fault.

  *This core has been formally verified.*

- [AXI2AXILITE](rtl/axi2axilite.v) converts incoming AXI4 (full) requests
  for an AXI-lite slave.  This conversion is fully pipelined, and capable of
  sending back to back AXI-lite requests on both channels.

  *This core has been formally verified.*

- [AXIS2MM](rtl/axis2mm.v) converts an incoming stream signal into outgoinng
  AXI (full) requests.  Supports bursting and aborted transactions.  Also
  supports writes to a constant address, and continuous writes to concurrent
  addresses.  This core depends upon all stream addresses being aligned.

  *This core has been formally verified.*

- [AXIMM2S](rtl/aximm2s.v) reads from a given address, and writes it to
  a FIFO buffer and then to an eventual AXI stream.  Read requests are not
  issued unless room already exists in the FIFO, yet for a sufficiently fast
  stream the read requests may maintain 100% bus utilization--but only if
  the rest of the bus does as well.  Supports continuous, fixed address or
  incrementing, and aborted transactions.

  Both this core and the one above it depend upon all stream addresses being
  aligned.

  *This core has been formally verified.*

- AXISINGLE is a (to be written) core that will also be an
  [AutoFPGA](https://github.com/ZipCPU/autofpga) companion core.  Slave's of
  type "SINGLE" (one register, one clock to generate a response) can be ganged
  together using it.  This core will then essentially turn an AXI core into
  an AXI-lite core, with the same interface as [AXILSINGLE](rtl/axilsingle.v) 
  above.  When implemented, it will look very similar to the [AXIDOUBLE](rtl/axidouble.v)
  core mentioned below.

- [AXIDOUBLE](rtl/axidouble.v) is the second AXI4 (full) companion to
  [AutoFPGA](https://github.com/ZipCPU/autofpga)'s AXI4 (full) support.  It's
  purpose is to simplify connectivity logic when supporting multiple AXI4 (full)
  slaves.  This core takes a generic AXI4 (full) interface, and simplifies
  the interface so that peripherals can be connected to it with a minimal amount
  of logic.  These peripherals cores can either be full AXI4 (full) cores in
  their own respect, subject to simplification rules discussed within,
  simplified AXI-lite slave as one might use with
  [AXILDOUBLE](rtl/axildouble.v), or even simpler than that.  Key to this
  simplification is the assumption that the simplified slaves must never stall
  the bus, and that they must always return responses within one clock cycle.
  The [AXIDOUBLE](rtl/axidouble.v) core handles all backpressure issues, ID
  logic, burst logic, address selection, invalid address return and exclusive
  access logic.

  *This core has been formally verified.*


# Commercial Applications

Should you find the [GPLv3 license](doc/gpl-3.0.pdf) insufficient for your
needs, other licenses can be purchased from Gisselquist Technology, LLC.
Likewise the AXI4 (full) properties are both shipped with the [Symbiotic
EDA Suite](https://www.symbioticeda.com/sed-suite), and hosted on gitlab
where they are available to [sponsors](https://www.patreon.com/ZipCPU) of the [ZipCPU
blog](http://zipcpu.com) upon request.

# Thanks

I'd like to thank @wallento for his initial work on a
[Wishbone to AXI converter](https://github.com/wallento/wb2axi), and his
encouragement to improve upon it.  While this isn't a fork of his work, the
[pipelined wishbone to AXI bridge](rtl/wbm2axisp.v) took its initial
motivation from his work.

Many of the rest of these projects have been motivated by the desire to learn
and develop my formal verification skills.
