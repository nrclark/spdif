// http://www.minidisc.org/manuals/an22.pdf
// http://www.epanorama.net/documents/audio/spdif.html
// https://scanlime.org/2011/04/spdif-digital-audio-on-a-microcontroller/

module spidif_transmit #(
    parameter [6:0] category_code = 7'b0110000,
    parameter [0:0] copy_bit = 1,
    parameter [0:0] l_bit = 0,
    parameter [3:0] sample_freq = 0
)(
    input wire i_clk,
    input wire i_en_2x,
    input wire [23:0] i_ldata,
    input wire [23:0] i_rdata,
    input wire i_drdy,
    output wire o_spidif
);

wire [31:0] channelstatus_init = {
    1'b0, //pro
    1'b0, //audio
    copy_bit,
    3'b000, //preemph
    2'b00, //mode
    category_code,
    l_bit,
    4'b0000, //source
    4'b0000, //channel
    sample_freq,
    2'b00, //accuracy
    2'b00
};

reg [31:0] channelstatus = 0;
reg [7:0] frame_counter = 0;
reg [5:0] subframe_counter = 0;

reg [23:0] ldata_buff = 0;
reg [23:0] rdata_buff = 0;
wire [23:0] output_sample;

reg [7:0] spidif_out;
reg parity = 0;

localparam [1:0]
    PREAMBLE_X = 0,
    PREAMBLE_Y = 1,
    PREAMBLE_Z = 2;

assign o_spidif = spidif_out[7];
reg bit_ready = 0;
reg output_bit = 0;
reg preamble_load = 0;
reg [1:0] preamble_select = PREAMBLE_Z;

always @(posedge i_clk) begin
    if (i_en_2x) begin
        spidif_out <= {spidif_out[6:0], 1'b0};
    end

    if (bit_ready) begin
        spidif_out[7] <= ~spidif_out[7];
        spidif_out[6] <= output_bit ^ ~spidif_out[7];
    end

    if(preamble_load) begin
        case(preamble_select)
            PREAMBLE_X: spidif_out <= 8'b11100010;
            PREAMBLE_Y: spidif_out <= 8'b11100100;
            default:    spidif_out <= 8'b11101000;
        endcase
    end
end

assign output_sample = frame_counter[0] ? ldata_buff : rdata_buff;

always @(posedge i_clk) begin
    preamble_load <= 0;
    bit_ready <= 0;

    if(i_drdy) begin
        ldata_buff <= i_ldata;
        rdata_buff <= i_rdata;
        subframe_counter <= 0;
    end

    if (i_en_2x && (bit_ready == 0)) begin
        subframe_counter <= subframe_counter + 1'b1;
        bit_ready <= 1;
        case(subframe_counter)
             0: begin
                    preamble_load <= 1;
                    if (frame_counter == 0)
                        preamble_select <= PREAMBLE_Z;
                    else if (frame_counter[0])
                        preamble_select <= PREAMBLE_Y;
                    else
                        preamble_select <= PREAMBLE_X;
                end
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
