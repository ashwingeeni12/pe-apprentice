`ifndef PE_V
`define PE_V

`timescale 1ns/1ps

module pe #(
  parameter  QI = 8,
  parameter  QF = 8,
  localparam DW = QI + QF
)(
  input  logic                 clk,
  input  logic                 rst,

  // north
  input  logic signed [DW-1:0] pe_psum_in,
  input  logic signed [DW-1:0] pe_weight_in,
  input  logic                 pe_accept_w_in,

  // west
  input  logic signed [DW-1:0] pe_input_in,
  input  logic                 pe_valid_in,
  input  logic                 pe_switch_in,
  input  logic                 pe_enabled,

  // south
  output logic signed [DW-1:0] pe_psum_out,
  output logic signed [DW-1:0] pe_weight_out,

  // east
  output logic signed [DW-1:0] pe_input_out,
  output logic                 pe_valid_out,
  output logic                 pe_switch_out
);

  // Weight storage

  logic signed [DW-1:0] weight_bg;
  logic signed [DW-1:0] weight_active;
  logic signed [DW-1:0] weight_fg;      // holds weight_active between switches

  // MAC

  logic signed [DW-1:0] mult_out;
  logic signed [DW-1:0] mac_out;

  fxp_mul #(QI,QF) u_mul (pe_input_in, weight_active, mult_out, );
  fxp_add #(QI,QF) u_add (mult_out,    pe_psum_in,    mac_out,  );

  // weight promotion

  always_comb begin
    if ( pe_enabled && pe_switch_in )
      weight_active = weight_bg;
    else
      weight_active = weight_fg;
  end

  always_ff @( posedge clk or posedge rst ) begin
    if ( rst )
      weight_fg <= '0;
    else
      weight_fg <= weight_active;
  end

  // weight staging

  always_ff @( posedge clk or posedge rst ) begin
    if ( rst )
      weight_bg <= '0;
    else if ( pe_enabled && pe_accept_w_in )
      weight_bg <= pe_weight_in;
    else
      weight_bg <= weight_bg;
  end

  // streaming datapath

  always_ff @( posedge clk or posedge rst ) begin
    if ( rst ) begin
      pe_psum_out   <= '0;
      pe_weight_out <= '0;
      pe_input_out  <= '0;
      pe_valid_out  <= 1'b0;
      pe_switch_out <= 1'b0;
    end
    else if ( !pe_enabled ) begin
      pe_psum_out   <= '0;
      pe_weight_out <= '0;
      pe_input_out  <= '0;
      pe_valid_out  <= 1'b0;
      pe_switch_out <= 1'b0;
    end
    else begin
      pe_psum_out   <= pe_valid_in    ? mac_out      : '0;
      pe_weight_out <= pe_accept_w_in ? pe_weight_in : '0;
      pe_input_out  <= pe_valid_in    ? pe_input_in  : '0;
      pe_valid_out  <= pe_valid_in;
      pe_switch_out <= pe_switch_in;
    end
  end

endmodule

`endif
