/*------------------------------- Info Header ----------------------------------

S/PDIF Transmitter module. Transmits two-channel 24-bit data over consumer-
mode S/PDIF. Based on data taken from the following websites:

 - http://www.minidisc.org/manuals/an22.pdf
 - http://www.epanorama.net/documents/audio/spdif.html
 - https://scanlime.org/2011/04/spdif-digital-audio-on-a-microcontroller/

 Original Author: Nicholas Clark
 Last Modified: Feb-10-2019
-------------------------------------------------------------------------------*/

`default_nettype none
`timescale 1ns/1ps

module spdif_transmit #(
    parameter [6:0] category_code = 7'b0110000,
    parameter [0:0] copy_bit = 1,
    parameter [0:0] L_bit = 0,
    parameter [3:0] sample_freq = 0
)(
    input wire i_clk,
    input wire i_en_2x,
    input wire [23:0] i_ldata,
    input wire [23:0] i_rdata,
    input wire i_drdy,
    output reg o_dreq = 0,
    output wire o_spdif
);

//----------------------------- Local Parameters -----------------------------//

localparam [31:0] channelstatus_init = {
    1'b0, //pro
    1'b0, //audio
    copy_bit,
    3'b000, //preemph
    2'b00, //mode
    category_code,
    L_bit,
    4'b0000, //source
    4'b0000, //channel
    sample_freq,
    2'b00, //accuracy
    2'b00
};

localparam [1:0]
    SELECT_X = 0,
    SELECT_Y = 1,
    SELECT_Z = 2;

localparam [1:0]
    PREAMBLE_X = 8'b11100010,
    PREAMBLE_Y = 8'b11100100,
    PREAMBLE_Z = 8'b11101000;

//------------------------------ Local Variables -----------------------------//

reg [31:0] channelstatus = 0;
reg [7:0] frame_counter = 0;
reg [4:0] subframe_counter = 0;

reg [23:0] ldata_buff = 0;
reg [23:0] rdata_buff = 0;
wire [23:0] output_sample;

reg [7:0] spdif_out = 0;
reg parity = 0;

reg bit_ready = 0;
reg output_bit = 0;
reg preamble_load = 0;
reg [1:0] preamble_select = PREAMBLE_Z;
reg toggle = 0;
reg clear_parity = 0;

//------------------------------- Module Logic -------------------------------//

assign o_spdif = spdif_out[7];

always @(posedge i_clk) if (i_en_2x) begin
    spdif_out <= {spdif_out[6:0], 1'b0};

    if (clear_parity) 
        parity <= 0;

    if (bit_ready) begin
        parity <= parity ^ output_bit;
        spdif_out[7] <= ~spdif_out[7];
        spdif_out[6] <= output_bit ^ ~spdif_out[7];
    end

    if(preamble_load) begin 
        case(preamble_select)
            SELECT_X: spdif_out <= spdif_out[7] ? ~PREAMBLE_X : PREAMBLE_X;
            SELECT_Y: spdif_out <= spdif_out[7] ? ~PREAMBLE_Y : PREAMBLE_Y;
            default:  spdif_out <= spdif_out[7] ? ~PREAMBLE_Z : PREAMBLE_Z;
        endcase
    end
end

assign output_sample = frame_counter[0] ? ldata_buff : rdata_buff;

always @(posedge i_clk) begin
    o_dreq <= 0;
    clear_parity <= 0;

    if(i_drdy) begin
        ldata_buff <= i_ldata;
        rdata_buff <= i_rdata;
    end

    if (i_en_2x) begin
        toggle <= ~toggle;
        preamble_load <= 0;
        bit_ready <= 0;
    end

    if (i_en_2x && toggle) begin
        subframe_counter <= subframe_counter + 1'b1;
        bit_ready <= (subframe_counter >= 4);
        case(subframe_counter)
            0: begin
                preamble_load <= 1;
                o_dreq <= 1;
                if (frame_counter == 0)
                    preamble_select <= SELECT_Z;
                else if (frame_counter[0]) begin
                    preamble_select <= SELECT_Y;
                    o_dreq <= 0;
                end
                else
                    preamble_select <= SELECT_X;
                end
            3: clear_parity <= 1;
            28: output_bit <= 1;
            29: output_bit <= 0;
            30: begin
                    output_bit <= channelstatus[31];
                    channelstatus <= {channelstatus[30:0], 1'b0};
                    frame_counter <= frame_counter + 1'b1;

                    if (frame_counter == 191) begin
                        channelstatus <= channelstatus_init;
                        frame_counter <= 0;
                    end
                end
            31: output_bit <= parity;
       default: output_bit <= output_sample[subframe_counter - 4];
       endcase
    end
end

endmodule
`default_nettype wire

/*--------------------------- Instantiation Template ---------------------------

spdif_transmit #(
    .category_code(category_code),
    .copy_bit(copy_bit),
    .L_bit(L_bit),
    .sample_freq(sample_freq)
) myTx (
    .i_clk(i_clk),
    .i_en_2x(i_en_2x),
    .i_ldata(i_ldata),
    .i_rdata(i_rdata),
    .i_drdy(i_drdy),
    .o_dreq(o_dreq),
    .o_spdif(o_spdif)
);

------------------------------------------------------------------------------*/