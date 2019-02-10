`timescale 1ns / 1ps
`default_nettype none

module spdif_tx_testbench;

reg i_clk = 0;
reg i_en_2x = 0;
reg [23:0] i_ldata = 0;
reg [23:0] i_rdata = 0;
reg i_drdy = 0;

wire o_dreq;
wire o_spdif;
reg [0:0] spdif_read = 0;

always @(posedge i_clk) if (i_en_2x) begin
    spdif_read = 1'bz;
    #0.1;
    spdif_read = o_spdif;
end

initial #5 forever #5 i_clk = ~i_clk;

initial forever begin
    @(posedge i_clk);
    @(posedge i_clk);
    @(posedge i_clk);
    @(posedge i_clk);
    i_en_2x <= 1;
    @(posedge i_clk);
    i_en_2x <= 0;
end

initial begin
    repeat(4) @(posedge i_clk);
    repeat(2) @(posedge o_dreq);
    i_ldata <= 24'b1000_0000_0000_0000_0000_0000;
    i_rdata <= 24'b0000_0000_0000_0000_0000_0001;
    i_drdy <= 1;
    @(posedge i_clk);
    i_drdy <= 0;

    @(posedge o_dreq);
    i_ldata <= 24'b0100_0000_0000_0000_0000_0000;
    i_rdata <= 24'b0000_0000_0000_0000_0000_0010;
    i_drdy <= 1;
    @(posedge i_clk);
    i_drdy <= 0;

    @(posedge o_dreq);
    i_ldata <= 24'b0000_0000_0000_0000_0000_0001;
    i_rdata <= 24'b1000_0000_0000_0000_0000_0000;
    i_drdy <= 1;
    @(posedge i_clk);
    i_drdy <= 0;

    @(posedge o_dreq);
    i_ldata <= 24'b0000_0000_0000_0000_0000_0010;
    i_rdata <= 24'b0100_0000_0000_0000_0000_0000;
    i_drdy <= 1;
    @(posedge i_clk);
    i_drdy <= 0;

end

spdif_transmit #(
    .copy_bit(1'b1),
    .L_bit(1'b0),
    .sample_freq(4'b0001)
) myTx (
    .i_clk(i_clk),
    .i_en_2x(i_en_2x),
    .i_ldata(i_ldata),
    .i_rdata(i_rdata),
    .i_drdy(i_drdy),
    .o_dreq(o_dreq),
    .o_spdif(o_spdif)
);

endmodule
`default_nettype wire