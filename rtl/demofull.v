////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	demofull.v
//
// Project:	Pipelined Wishbone to AXI converter
//
// Purpose:	Demonstrate a formally verified AXI4 core with a (basic)
//		interface.
//
// Performance: This core has been designed for a throughput approaching
//		one beat per clock cycle.  The read channel can achieve this,
//	although it means overlapping reads by a beat.  (One beat for the
//	address, the next beat(s) have the data.)  The write channel can
//	achieve this within a burst, but otherwise requires a minimum of
//	2+AWLEN cycles per transaction of (1+AWLEN) beats.
//	
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2019, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
module demofull #(
	parameter integer C_S_AXI_ID_WIDTH	= 2,
	parameter integer C_S_AXI_DATA_WIDTH	= 32,
	parameter integer C_S_AXI_ADDR_WIDTH	= 6,
	parameter [0:0]	OPT_NARROW_BURST = 1
	) (
		// Users to add ports here

		// A very basic protocol-independent peripheral interface
		// 1. A value will be written any time o_we is true
		// 2. A value will be read any time o_rd is true
		// 3. Such a slave might just as easily be written as:
		//
		//	always @(posedge S_AXI_ACLK)
		//	if (o_we)
		//	begin
		//	    for(k=0; k<C_S_AXI_DATA_WIDTH; k=k+1)
		//	    begin
		//		if (o_wstrb[k])
		//		mem[o_waddr[AW-1:LSB][k*8+:8] <= o_wdata[k*8+:8]
		//	    end
		//	end
		//
		//	always @(posedge S_AXI_ACLK)
		//	if (o_rd)
		//		i_rdata <= mem[o_raddr[AW-1:LSB]];
		//
		// 4. The rule on the input is that i_rdata must be registered,
		//    and that it must only change if o_rd is true.  Violating
		//    this rule will cause this core to violate the AXI
		//    protocol standard, as this value is not registered within
		//    this core
		output	reg					o_we,
		output	reg	[C_S_AXI_ADDR_WIDTH-LSB-1:0]	o_waddr,
		output	reg	[C_S_AXI_DATA_WIDTH-1:0]	o_wdata,
		output	reg	[C_S_AXI_DATA_WIDTH/8-1:0]	o_wstrb,
		//
		output	reg					o_rd,
		output	reg	[C_S_AXI_ADDR_WIDTH-LSB-1:0]	o_raddr,
		input	wire	[C_S_AXI_DATA_WIDTH-1:0]	i_rdata,
		//
		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write Address ID
		input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_AWID,
		// Write address
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Burst length. The burst length gives the exact number of
		// transfers in a burst
		input wire [7 : 0] S_AXI_AWLEN,
		// Burst size. This signal indicates the size of each transfer
		// in the burst
		input wire [2 : 0] S_AXI_AWSIZE,
		// Burst type. The burst type and the size information,
		// determine how the address for each transfer within the burst
		// is calculated.
		input wire [1 : 0] S_AXI_AWBURST,
		// Lock type. Provides additional information about the
		// atomic characteristics of the transfer.
		input wire  S_AXI_AWLOCK,
		// Memory type. This signal indicates how transactions
		// are required to progress through a system.
		input wire [3 : 0] S_AXI_AWCACHE,
		// Protection type. This signal indicates the privilege
		// and security level of the transaction, and whether
		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Quality of Service, QoS identifier sent for each
		// write transaction.
		input wire [3 : 0] S_AXI_AWQOS,
		// Region identifier. Permits a single physical interface
		// on a slave to be used for multiple logical interfaces.
		// Write address valid. This signal indicates that
		// the channel is signaling valid write address and
		// control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that
		// the slave is ready to accept an address and associated
		// control signals.
		output wire  S_AXI_AWREADY,
		// Write Data
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte
		// lanes hold valid data. There is one write strobe
		// bit for each eight bits of the write data bus.
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write last. This signal indicates the last transfer
		// in a write burst.
		input wire  S_AXI_WLAST,
		// Optional User-defined signal in the write data channel.
		// Write valid. This signal indicates that valid write
		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Response ID tag. This signal is the ID tag of the
		// write response.
		output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_BID,
		// Write response. This signal indicates the status
		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Optional User-defined signal in the write response channel.
		// Write response valid. This signal indicates that the
		// channel is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address ID. This signal is the identification
		// tag for the read address group of signals.
		input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_ARID,
		// Read address. This signal indicates the initial
		// address of a read burst transaction.
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Burst length. The burst length gives the exact number of
		// transfers in a burst
		input wire [7 : 0] S_AXI_ARLEN,
		// Burst size. This signal indicates the size of each transfer
		// in the burst
		input wire [2 : 0] S_AXI_ARSIZE,
		// Burst type. The burst type and the size information,
		// determine how the address for each transfer within the
		// burst is calculated.
		input wire [1 : 0] S_AXI_ARBURST,
		// Lock type. Provides additional information about the
		// atomic characteristics of the transfer.
		input wire  S_AXI_ARLOCK,
		// Memory type. This signal indicates how transactions
		// are required to progress through a system.
		input wire [3 : 0] S_AXI_ARCACHE,
		// Protection type. This signal indicates the privilege
		// and security level of the transaction, and whether
		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Quality of Service, QoS identifier sent for each
		// read transaction.
		input wire [3 : 0] S_AXI_ARQOS,
		// Region identifier. Permits a single physical interface
		// on a slave to be used for multiple logical interfaces.
		// Optional User-defined signal in the read address channel.
		// Write address valid. This signal indicates that
		// the channel is signaling valid read address and
		// control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that
		// the slave is ready to accept an address and associated
		// control signals.
		output wire  S_AXI_ARREADY,
		// Read ID tag. This signal is the identification tag
		// for the read data group of signals generated by the slave.
		output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_RID,
		// Read Data
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of
		// the read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read last. This signal indicates the last transfer
		// in a read burst.
		output wire  S_AXI_RLAST,
		// Optional User-defined signal in the read address channel.
		// Read valid. This signal indicates that the channel
		// is signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	localparam	AW = C_S_AXI_ADDR_WIDTH;
	localparam	DW = C_S_AXI_DATA_WIDTH;
	localparam	IW = C_S_AXI_ID_WIDTH;
	localparam	LSB = (C_S_AXI_DATA_WIDTH == 8) ? 0
			: ((C_S_AXI_DATA_WIDTH ==  16) ? 1
			: ((C_S_AXI_DATA_WIDTH ==  32) ? 2
			: ((C_S_AXI_DATA_WIDTH ==  64) ? 3
			: ((C_S_AXI_DATA_WIDTH == 128) ? 4
			: ((C_S_AXI_DATA_WIDTH == 256) ? 5
			: ((C_S_AXI_DATA_WIDTH == 512) ? 6
			: 7))))));

	// Double buffer the write response channel only
	reg	[IW-1 : 0]	r_bid;
	reg			r_bvalid;
	reg	[IW-1 : 0]	axi_bid;
	reg			axi_bvalid;

	reg			axi_awready, axi_wready;
	reg	[AW-1:0]	waddr;
	wire	[AW-1:0]	next_wr_addr;

	reg	[7:0]		wlen;
	reg	[2:0]		wsize;
	reg	[1:0]		wburst;


	wire	[AW-1:0]	next_rd_addr;
	reg	[IW-1:0]	axi_rid;
	reg	[DW-1:0]	axi_rdata;

	initial	axi_awready = 1;
	initial	axi_wready  = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
	begin
		axi_awready  <= 1;
		axi_wready   <= 0;
	end else if (S_AXI_AWVALID && S_AXI_AWREADY)
	begin
		axi_awready <= 0;
		axi_wready <= 1;
		waddr    <= S_AXI_AWADDR;
		wburst   <= S_AXI_AWBURST;
		wsize    <= S_AXI_AWSIZE;
		wlen     <= S_AXI_AWLEN;
	end else if (S_AXI_WVALID && S_AXI_WREADY)
	begin
		waddr <= next_wr_addr;
		axi_awready <= (S_AXI_WLAST)&&(!S_AXI_BVALID || S_AXI_BREADY);
		axi_wready  <= (!S_AXI_WLAST);
	end else if (!S_AXI_AWREADY)
	begin
		if (S_AXI_WREADY)
			axi_awready <= 1'b0;
		else if ((r_bvalid)&&(S_AXI_BVALID&&!S_AXI_BREADY))
			axi_awready <= 1'b0;
		else
			axi_awready <= 1'b1;
	end

	axi_addr #(.AW(AW), .DW(DW))
		get_next_wr_addr(waddr, wsize, wburst, wlen,
			next_wr_addr);

	always @(*)
	begin
		o_we = (S_AXI_WVALID && S_AXI_WREADY);
		o_waddr = waddr[AW-1:LSB];
		o_wdata = S_AXI_WDATA;
		o_wstrb = S_AXI_WSTRB;
	end

	initial	r_bvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		r_bvalid <= 1'b0;
	else if (S_AXI_WVALID && S_AXI_WREADY && S_AXI_WLAST
			&&(S_AXI_BVALID && !S_AXI_BREADY))
		r_bvalid <= 1'b1;
	else if (S_AXI_BREADY)
		r_bvalid <= 1'b0;

	always @(posedge S_AXI_ACLK)
	begin
		if (S_AXI_AWVALID && S_AXI_AWREADY)
			r_bid    <= S_AXI_AWID;

		if (!S_AXI_BVALID || S_AXI_BREADY)
			axi_bid <= r_bid;
	end

	initial	axi_bvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		axi_bvalid <= 0;
	else if (S_AXI_WVALID && S_AXI_WREADY && S_AXI_WLAST)
		axi_bvalid <= 1;
	else if (S_AXI_BVALID && S_AXI_BREADY)
		axi_bvalid <= r_bvalid;

	//
	// Read half
	//
	reg	[7:0]		rlen;
	reg	[2:0]		rsize;
	reg	[1:0]		rburst;
	reg	[IW-1:0]	rid;
	reg			axi_arready, axi_rlast, axi_rvalid;
	reg	[8:0]		axi_rlen;
	reg	[AW-1:0]	raddr;

	initial axi_arready = 1;
	initial axi_rlen    = 0;
	initial axi_rlast   = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		axi_arready <= 1;
	else if (S_AXI_ARVALID && S_AXI_ARREADY)
		axi_arready <= (S_AXI_ARLEN==0)&&(o_rd);
	else if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		if ((!axi_arready)&&(S_AXI_RVALID))
			axi_arready <= (axi_rlen <= 2);
	end

	initial	axi_rlen = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		axi_rlen <= 0;
	else if (S_AXI_ARVALID && S_AXI_ARREADY)
		axi_rlen <= (S_AXI_ARLEN+1)
				+ ((S_AXI_RVALID && !S_AXI_RREADY) ? 1:0);
	else if (S_AXI_RREADY && axi_rlen > 0)
		axi_rlen <= axi_rlen - 1;

	always @(posedge S_AXI_ACLK)
	if (S_AXI_ARVALID && S_AXI_ARREADY)
		raddr <= S_AXI_ARADDR;
	else if (o_rd)
		raddr <= next_rd_addr;

	always @(posedge S_AXI_ACLK)
	if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		if (S_AXI_ARVALID && S_AXI_ARREADY)
			axi_rlast <= (S_AXI_ARLEN == 0);
		else if ((axi_rlen > 0)&&(S_AXI_RVALID))
			axi_rlast <= (axi_rlen == 2);
		else
			axi_rlast <= (axi_rlen == 1);
	end

	always @(posedge S_AXI_ACLK)
	if (S_AXI_ARVALID && S_AXI_ARREADY)
	begin
		rburst   <= S_AXI_ARBURST;
		rsize    <= S_AXI_ARSIZE;
		rlen     <= S_AXI_ARLEN;
		rid      <= S_AXI_ARID;
	end

	always @(posedge S_AXI_ACLK)
	if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		if (S_AXI_ARVALID && S_AXI_ARREADY)
			axi_rid <= S_AXI_ARID;
		else
			axi_rid <= rid;
	end
	
	axi_addr #(.AW(AW), .DW(DW))
		get_next_rd_addr(raddr, rsize, rburst, rlen, next_rd_addr);

	initial	axi_rvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		axi_rvalid <= 0;
	else if (!S_AXI_RVALID || S_AXI_RREADY)
		axi_rvalid <= o_rd;

	always @(*)
	begin
		o_rd = (S_AXI_ARVALID && S_AXI_ARREADY)||(!S_AXI_ARREADY);
		if (S_AXI_RVALID && !S_AXI_RREADY)
			o_rd = 0;
		o_raddr = (S_AXI_ARREADY ? S_AXI_ARADDR[AW-1:LSB] : raddr[AW-1:LSB]);
	end

	always @(*)
		axi_rdata = i_rdata;


	assign	S_AXI_BRESP = 0;
	//
	assign	S_AXI_AWREADY = axi_awready;
	assign	S_AXI_WREADY  = axi_wready;
	assign	S_AXI_BVALID  = axi_bvalid;
	assign	S_AXI_BID     = axi_bid;
	//
	assign	S_AXI_ARREADY = axi_arready;
	assign	S_AXI_RVALID  = axi_rvalid;
	assign	S_AXI_RID     = axi_rid;
	assign	S_AXI_RDATA   = axi_rdata;
	assign	S_AXI_RRESP   = 0;
	assign	S_AXI_RLAST   = axi_rlast;
	//

	// Make Verilator happy
	// Verilator lint_off UNUSED
	wire	[23:0]	unused;
	assign	unused = { S_AXI_AWLOCK, S_AXI_AWCACHE, S_AXI_AWPROT,
			S_AXI_AWQOS,
		S_AXI_ARLOCK, S_AXI_ARCACHE, S_AXI_ARPROT, S_AXI_ARQOS };
	// Verilator lint_on  UNUSED

`ifdef	FORMAL
	localparam	F_LGDEPTH=9;

	wire	[F_LGDEPTH-1:0] f_axi_awr_nbursts,
				f_axi_rd_nbursts,
				f_axi_rd_outstanding;
	wire	[9-1:0]		f_axi_wr_pending;
	wire	[C_S_AXI_ID_WIDTH-1:0]	f_axi_wr_checkid;
	wire				f_axi_wr_ckvalid;
	wire	[F_LGDEPTH-1:0]		f_axi_wrid_nbursts;

	//
	wire	[C_S_AXI_ADDR_WIDTH-1:0] f_axi_wr_addr;
	wire	[7:0]			f_axi_wr_incr;
	wire	[1:0]			f_axi_wr_burst;
	wire	[2:0]			f_axi_wr_size;
	wire	[7:0]			f_axi_wr_len;
	//
	wire	[C_S_AXI_ID_WIDTH-1:0]	f_axi_rd_checkid;
	wire				f_axi_rd_ckvalid;
	wire	[9-1:0]			f_axi_rd_cklen;
	wire	[C_S_AXI_ADDR_WIDTH-1:0] f_axi_rd_ckaddr;
	wire	[7:0]			f_axi_rd_ckincr;
	wire	[1:0]			f_axi_rd_ckburst;
	wire	[2:0]			f_axi_rd_cksize;
	wire	[7:0]			f_axi_rd_ckarlen;
	wire	[F_LGDEPTH-1:0]		f_axi_rdid_nbursts,
					f_axi_rdid_outstanding,
					f_axi_rdid_ckign_nbursts,
					f_axi_rdid_ckign_outstanding;

	reg	f_past_valid;
	initial	f_past_valid = 0;
	always @(posedge S_AXI_ACLK)
		f_past_valid <= 1;

	always @(*)
	if (!f_past_valid)
		assume(!S_AXI_ARESETN);

	faxi_slave	#(
		.F_AXI_MAXSTALL(6),
		.C_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
		.C_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
		.C_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
		.F_LGDEPTH(F_LGDEPTH))
		f_slave(
		.i_clk(S_AXI_ACLK),
		.i_axi_reset_n(S_AXI_ARESETN),
		//
		// Address write channel
		//
		.i_axi_awid(S_AXI_AWID),
		.i_axi_awaddr(S_AXI_AWADDR),
		.i_axi_awlen(S_AXI_AWLEN),
		.i_axi_awsize(S_AXI_AWSIZE),
		.i_axi_awburst(S_AXI_AWBURST),
		.i_axi_awlock(S_AXI_AWLOCK),
		.i_axi_awcache(S_AXI_AWCACHE),
		.i_axi_awprot(S_AXI_AWPROT),
		.i_axi_awqos(S_AXI_AWQOS),
		.i_axi_awvalid(S_AXI_AWVALID),
		.i_axi_awready(S_AXI_AWREADY),
	//
	//
		//
		// Write Data Channel
		//
		// Write Data
		.i_axi_wdata(S_AXI_WDATA),
		.i_axi_wstrb(S_AXI_WSTRB),
		.i_axi_wlast(S_AXI_WLAST),
		.i_axi_wvalid(S_AXI_WVALID),
		.i_axi_wready(S_AXI_WREADY),
	//
	//
		// Response ID tag. This signal is the ID tag of the
		// write response.
		.i_axi_bid(S_AXI_BID),
		.i_axi_bresp(S_AXI_BRESP),
		.i_axi_bvalid(S_AXI_BVALID),
		.i_axi_bready(S_AXI_BREADY),
	//
	//
		//
		// Read address channel
		//
		// Read address ID. This signal is the identification
		// tag for the read address group of signals.
		.i_axi_arid(S_AXI_ARID),
		// Read address. This signal indicates the initial
		// address of a read burst transaction.
		.i_axi_araddr(S_AXI_ARADDR),
		// Burst length. The burst length gives the exact number of
		// transfers in a burst
		.i_axi_arlen(S_AXI_ARLEN),
		// Burst size. This signal indicates the size of each transfer
		// in the burst
		.i_axi_arsize(S_AXI_ARSIZE),
		// Burst type. The burst type and the size information,
		// determine how the address for each transfer within the
		// burst is calculated.
		.i_axi_arburst(S_AXI_ARBURST),
		// Lock type. Provides additional information about the
		// atomic characteristics of the transfer.
		.i_axi_arlock(S_AXI_ARLOCK),
		// Memory type. This signal indicates how transactions
		// are required to progress through a system.
		.i_axi_arcache(S_AXI_ARCACHE),
		// Protection type. This signal indicates the privilege
		// and security level of the transaction, and whether
		// the transaction is a data access or an instruction access.
		.i_axi_arprot(S_AXI_ARPROT),
		// Quality of Service, QoS identifier sent for each
		// read transaction.
		.i_axi_arqos(S_AXI_ARQOS),
		// Write address valid. This signal indicates that
		// the channel is signaling valid read address and
		// control information.
		.i_axi_arvalid(S_AXI_ARVALID),
		// Read address ready. This signal indicates that
		// the slave is ready to accept an address and associated
		// control signals.
		.i_axi_arready(S_AXI_ARREADY),
	//
	//
		//
		// Read data return channel
		//
		// Read ID tag. This signal is the identification tag
		// for the read data group of signals generated by the slave.
		.i_axi_rid(S_AXI_RID),
		// Read Data
		.i_axi_rdata(S_AXI_RDATA),
		// Read response. This signal indicates the status of
		// the read transfer.
		.i_axi_rresp(S_AXI_RRESP),
		// Read last. This signal indicates the last transfer
		// in a read burst.
		.i_axi_rlast(S_AXI_RLAST),
		// Read valid. This signal indicates that the channel
		// is signaling the required read data.
		.i_axi_rvalid(S_AXI_RVALID),
		// Read ready. This signal indicates that the master can
		// accept the read data and response information.
		.i_axi_rready(S_AXI_RREADY),
		//
		// Formal outputs
		//
		.f_axi_awr_nbursts(f_axi_awr_nbursts),
		.f_axi_wr_pending(f_axi_wr_pending),
		.f_axi_rd_nbursts(f_axi_rd_nbursts),
		.f_axi_rd_outstanding(f_axi_rd_outstanding),
		//
		.f_axi_wr_checkid(f_axi_wr_checkid),
		.f_axi_wr_ckvalid(f_axi_wr_ckvalid),
		.f_axi_wrid_nbursts(f_axi_wrid_nbursts),
		.f_axi_wr_addr(f_axi_wr_addr),
		.f_axi_wr_incr(f_axi_wr_incr),
		.f_axi_wr_burst(f_axi_wr_burst),
		.f_axi_wr_size(f_axi_wr_size),
		.f_axi_wr_len(f_axi_wr_len),
		//
		.f_axi_rd_checkid(f_axi_rd_checkid),
		.f_axi_rd_ckvalid(f_axi_rd_ckvalid),
		.f_axi_rd_cklen(f_axi_rd_cklen),
		.f_axi_rd_ckaddr(f_axi_rd_ckaddr),
		.f_axi_rd_ckincr(f_axi_rd_ckincr),
		.f_axi_rd_ckburst(f_axi_rd_ckburst),
		.f_axi_rd_cksize(f_axi_rd_cksize),
		.f_axi_rd_ckarlen(f_axi_rd_ckarlen),
		.f_axi_rdid_nbursts(f_axi_rdid_nbursts),
		.f_axi_rdid_outstanding(f_axi_rdid_outstanding),
		.f_axi_rdid_ckign_nbursts(f_axi_rdid_ckign_nbursts),
		.f_axi_rdid_ckign_outstanding(f_axi_rdid_ckign_outstanding)
	);

	////////////////////////////////////////////////////////////////////////
	//
	// Write induction properties
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	always @(*)
		assert(f_axi_awr_nbursts <= 2);
	always @(*)
	if (f_axi_awr_nbursts == 2)
		assert(S_AXI_BVALID && (r_bvalid || (f_axi_wr_pending>0)));
	else if (f_axi_awr_nbursts == 1)
		assert(S_AXI_BVALID ^ (f_axi_wr_pending>0));
	else
		assert(!S_AXI_BVALID && (f_axi_wr_pending == 0));

	always @(*)
	if (f_axi_wrid_nbursts == 2)
		assert(S_AXI_BVALID
			&& S_AXI_BID == f_axi_wr_checkid
			&& r_bid == f_axi_wr_checkid);
	else if (f_axi_wrid_nbursts == 1)
		assert((S_AXI_BVALID && S_AXI_BID == f_axi_wr_checkid)
			||((r_bvalid || (f_axi_wr_pending>0))
				&& r_bid == f_axi_wr_checkid));
	else
		assert((!S_AXI_BVALID || S_AXI_BID != f_axi_wr_checkid)
			&&(((!r_bvalid)&&(f_axi_wr_pending==0))
				||(r_bid != f_axi_wr_checkid)));

	always @(*)
	if (r_bvalid)
		assert(S_AXI_BVALID);

	always @(*)
	if ((f_axi_wr_pending > 0)||(r_bvalid))
		assert(!S_AXI_AWREADY);
	else
		assert(S_AXI_AWREADY);

	always @(*)
	if (f_axi_wr_pending > 0)
	begin
		assert(f_axi_wr_addr  == waddr);
		assert(f_axi_wr_burst == wburst);
		assert(f_axi_wr_size  == wsize);
		assert(f_axi_wr_len   == wlen);
	end

	always @(*)
	if (S_AXI_AWREADY)
		assert(!S_AXI_WREADY);

	////////////////////////////////////////////////////////////////////////
	//
	// Read induction properties
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	reg	[C_S_AXI_ADDR_WIDTH-1:0]	f_mem_rdaddr, f_next_rd_addr;
	wire	[7:0]				f_next_rd_incr;

	always @(*)
		assert(f_axi_rd_nbursts <= 2);
	always @(*)
		assert(axi_rlen == f_axi_rd_outstanding);
	always @(*)
	if (f_axi_rd_nbursts>0)
		assert(S_AXI_RVALID);

	always @(*)
	if (f_axi_rd_nbursts == 2)
		assert(S_AXI_RLAST);

	always @(*)
	if (f_axi_rdid_nbursts == 2)
	begin
		assert(S_AXI_RVALID && S_AXI_RLAST &&
			(S_AXI_RID == f_axi_rd_checkid));
		assert(axi_rid == f_axi_rd_checkid);
	end else if (f_axi_rdid_nbursts == 1)
	begin
		if (!S_AXI_RLAST)
		begin
			assert(S_AXI_RID == f_axi_rd_checkid);
			assert(f_axi_rdid_outstanding == f_axi_rd_outstanding);
		end else if (S_AXI_RID == f_axi_rd_checkid)
			assert(f_axi_rdid_outstanding == 1);
		else begin
			// S_AXI_RLAST
			//	&& S_AXI_RID != f_axi_rd_checkid
			assert(rid == f_axi_rd_checkid);
			assert(f_axi_rd_outstanding == axi_rlen);
			assert(f_axi_rdid_outstanding == axi_rlen - 1);
		end
	end else if (f_axi_rd_nbursts > 0)
	begin
		assert(axi_rid != f_axi_rd_checkid);
		assert(!S_AXI_RVALID || S_AXI_RID != f_axi_rd_checkid);
	end

	always @(*)
	if (f_axi_rd_nbursts > 0)
		assert(!S_AXI_ARREADY || (S_AXI_RVALID && S_AXI_RLAST));

	always @(*)
	if (f_axi_rd_ckvalid)
		assert(f_axi_rd_outstanding == f_axi_rd_cklen);
	always @(*)
	if (S_AXI_ARREADY)
		assert(f_axi_rd_outstanding <= 1);
	always @(posedge S_AXI_ACLK)
	if (S_AXI_ARREADY && S_AXI_ARVALID)
		f_mem_rdaddr <= S_AXI_ARADDR;
	else if (o_rd)
		f_mem_rdaddr <= raddr;

	faxi_addr #(.AW(C_S_AXI_ADDR_WIDTH))
		get_next_rdaddr(f_mem_rdaddr, rsize,
			rburst, rlen,
			f_next_rd_incr, f_next_rd_addr);

	always @(posedge S_AXI_ACLK)
	if (f_axi_rd_nbursts>0)
		assert(rburst != 2'b11);
	always @(posedge S_AXI_ACLK)
	if (S_AXI_ARESETN && f_axi_rd_ckvalid && f_axi_rdid_ckign_nbursts==0)
	begin
		if (S_AXI_RVALID)
		begin
			assert(f_axi_rd_ckaddr == f_mem_rdaddr);
			assert(!S_AXI_RLAST || f_next_rd_addr == raddr);
		end else if (!S_AXI_RVALID && !S_AXI_ARREADY)
			assert(f_mem_rdaddr == raddr);
		if (rburst == 0)
			assert(f_mem_rdaddr == raddr);

	end

	always @(*)
	if (f_axi_rd_ckvalid)
	begin
		if ((f_axi_rdid_ckign_nbursts == 0)&&(f_axi_rdid_nbursts>1))
		begin
			assert(f_axi_rd_checkid == S_AXI_RID);
			assert(S_AXI_RLAST);
		end else begin
			assert(rlen   == f_axi_rd_ckarlen);
			assert(rburst == f_axi_rd_ckburst);
			assert(rsize  == f_axi_rd_cksize);
			assert(axi_rid    == f_axi_rd_checkid);
		end
	end

	always @(*)
	if (S_AXI_RVALID && S_AXI_RID == f_axi_rd_checkid)
	begin
		if (rid == f_axi_rd_checkid)
		begin
			assert(f_axi_rdid_nbursts == f_axi_rd_nbursts);
			assert(f_axi_rdid_outstanding == f_axi_rd_outstanding);
			if (f_axi_rd_ckvalid)
				assert(f_axi_rd_ckaddr == f_mem_rdaddr);
		end else begin
			assert(f_axi_rdid_nbursts == 1);
			assert(f_axi_rdid_outstanding == 1);
			if (f_axi_rd_ckvalid)
				assert(f_axi_rd_ckaddr == f_mem_rdaddr);
		end
	end

	always @(*)
	if (f_axi_rd_outstanding > 0)
	begin
		if (S_AXI_RVALID && S_AXI_RLAST)
			assert(f_axi_rd_nbursts==2
				|| axi_rlen == f_axi_rd_outstanding);
	end

	always @(*)
	if (f_axi_rd_outstanding == 0)
	begin
		assert(S_AXI_ARREADY);
	end

	always @(posedge S_AXI_ACLK)
	if (f_past_valid && $rose(S_AXI_RLAST))
		assert(S_AXI_ARREADY);

	////////////////////////////////////////////////////////////////////////
	//
	// Contract checking
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	(* anyconst *)	reg	[AW-1:0]	f_const_addr;
	(* anyconst *)	reg	[DW-1:0]	f_const_rvalue;
			reg	[DW-1:0]	f_const_wvalue;

	/*
	initial	f_const_wvalue = 0;
	always @(posedge S_AXI_ACLK)
	if (S_AXI_ARESETN && o_wr && (o_waddr == f_const_addr[AW-1:LSB]))
	begin
		integer	byte_lane;
		for(byte_lane=0; byte_lane<DW/8; byte_lane=byte_lane+1)
		if (o_wstrb[byte_lane])
			f_const_wvalue[byte_lane*8 +: 8] <=
				o_wdata[byte_lane*8 +; 8];
	end
	*/
	(* keep *) reg flag;
	always @(posedge S_AXI_ACLK)
		flag <= o_rd && (o_raddr == f_const_addr[AW-1:LSB]);
	always @(posedge S_AXI_ACLK)
	if (S_AXI_ARESETN
		&& $past(o_rd)
		&& $past(o_raddr == f_const_addr[AW-1:LSB]))
		assume(i_rdata == f_const_rvalue);

	always @(posedge S_AXI_ACLK)
	if (S_AXI_ARESETN && S_AXI_RVALID && f_axi_rd_ckvalid
			&& (f_axi_rd_ckaddr == f_const_addr)
			&& (f_axi_rdid_ckign_outstanding == 0))
		assert(S_AXI_RDATA == f_const_rvalue);

	////////////////////////////////////////////////////////////////////////
	//
	// Cover properties
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	reg	f_wr_cvr_valid;
	initial	f_wr_cvr_valid = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		f_wr_cvr_valid <= 0;
	else if (S_AXI_AWVALID && S_AXI_AWREADY && S_AXI_AWLEN > 4)
		f_wr_cvr_valid <= 1;

	always @(*)
		cover(!S_AXI_BVALID && S_AXI_AWREADY &&
				f_wr_cvr_valid && (f_axi_awr_nbursts == 0));

	reg	f_rd_cvr_valid;
	initial	f_rd_cvr_valid = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		f_rd_cvr_valid <= 0;
	else if (S_AXI_ARVALID && S_AXI_ARREADY && S_AXI_ARLEN > 4)
		f_rd_cvr_valid <= 1;

	always @(*)
		cover(S_AXI_ARREADY && f_rd_cvr_valid && f_axi_rd_nbursts == 0);

	////////////////////////////////////////////////////////////////////////
	//
	// Assumptions necessary to pass a formal check
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	always @(posedge S_AXI_ACLK)
	if (S_AXI_RVALID && !$past(o_rd))
		assume($stable(i_rdata));
`endif
endmodule
