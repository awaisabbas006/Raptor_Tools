/* Generated by Yosys 0.18+10 (git sha1 daf9624a5, gcc 11.2.0 -fPIC -Os) */

module serdes_design(clk, fast_clk, cdr_core_clk, reset, dpa_rst, D, pll_lock, clk_out, Q, dpa_lock, dpa_error, delay_tap_value);
  input D;
  output Q;
  input cdr_core_clk;
  input clk;
  output clk_out;
  output [5:0] delay_tap_value;
  output dpa_error;
  output dpa_lock;
  input dpa_rst;
  input fast_clk;
  input pll_lock;
  input reset;
  wire _00_;
  (* keep = 32'h00000001 *)
  wire _01_;
  (* keep = 32'h00000001 *)
  wire _02_;
  (* keep = 32'h00000001 *)
  wire _03_;
  wire _04_;
  (* unused_bits = "0 1 2 3 4" *)
  wire [4:0] _05_;
  (* unused_bits = "0 1 2 3 4" *)
  wire [4:0] _06_;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:13" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:13" *)
  wire D;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:16" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:16" *)
  wire Q;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:10" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:10" *)
  wire cdr_core_clk;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:26" *)
  (* unused_bits = "0" *)
  wire channel_bond_sync_out;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:8" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:8" *)
  wire clk;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:15" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:15" *)
  wire clk_out;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:73" *)
  wire clk_out1;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:101" *)
  wire clk_out2;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:17" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:17" *)
  wire [5:0] delay_tap_value;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:77" *)
  wire delay_tap_value_1;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:103" *)
  wire delay_tap_value_2;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:24" *)
  (* unused_bits = "0 1 2 3" *)
  wire [3:0] des_data;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:19" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:19" *)
  wire dpa_error;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:18" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:18" *)
  wire dpa_lock;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:12" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:12" *)
  wire dpa_rst;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:9" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:9" *)
  wire fast_clk;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:76" *)
  wire load_data;
  (* keep = 32'h00000001 *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:26" *)
  wire loaded;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:14" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:14" *)
  wire pll_lock;
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:11" *)
  (* src = "/nfs_scratch/zafar/FPGA_PRIMITIVE_TEST_CASE/SERDES_DESIGN/serdes_design.sv:11" *)
  wire reset;
  (* module_not_derived = 32'h00000001 *)
  (* src = "/nfs_eda_sw/softwares/Raptor/instl_dir/06_23_2023_09_15_01/bin/../share/yosys/rapidsilicon/genesis3/ffs_map.v:80.11-80.65" *)
  dffre _07_ (
    .C(clk),
    .D(_04_),
    .E(_00_),
    .Q(loaded),
    .R(1'h1)
  );
  \$lut  #(
    .LUT(4'he),
    .WIDTH(32'h00000002)
  ) _08_ (
    .A({ load_data, reset }),
    .Y(_00_)
  );
  \$lut  #(
    .LUT(4'h8),
    .WIDTH(32'h00000002)
  ) _09_ (
    .A({ delay_tap_value_2, delay_tap_value_1 }),
    .Y(delay_tap_value[0])
  );
  \$lut  #(
    .LUT(4'h8),
    .WIDTH(32'h00000002)
  ) _10_ (
    .A({ clk_out2, clk_out1 }),
    .Y(clk_out)
  );
  \$lut  #(
    .LUT(2'h1),
    .WIDTH(32'h00000001)
  ) _11_ (
    .A(reset),
    .Y(_04_)
  );
  I_SERDES #(
    .DATA_RATE("SDR"),
    .DELAY(6'h00),
    .DPA_MODE("NONE"),
    .WIDTH(1'h0)
  ) u_iserdes (
    .BITSLIP_ADJ(1'h0),
    .CDR_CORE_CLK(cdr_core_clk),
    .CLK_IN(clk),
    .CLK_OUT(clk_out1),
    .D(D),
    .DATA_VALID(load_data),
    .DLY_ADJ(1'h0),
    .DLY_INCDEC(1'h0),
    .DLY_LOAD(1'h1),
    .DLY_TAP_VALUE({ _06_, delay_tap_value_1 }),
    .DPA_ERROR(dpa_error),
    .DPA_LOCK(dpa_lock),
    .DPA_RST(dpa_rst),
    .EN(1'h1),
    .FAST_PHASE_CLK({ fast_clk, fast_clk, fast_clk, fast_clk }),
    .FIFO_RST(reset),
    .PLL_FAST_CLK(fast_clk),
    .PLL_LOCK(pll_lock),
    .Q(des_data),
    .RST(reset)
  );
  O_SERDES #(
    .CLOCK_PHASE(8'h00),
    .DATA_RATE("SDR"),
    .DELAY(6'h00),
    .WIDTH(1'h0)
  ) u_oserdes (
    .CHANNEL_BOND_SYNC_IN(1'h0),
    .CHANNEL_BOND_SYNC_OUT(channel_bond_sync_out),
    .CLK_EN(1'h1),
    .CLK_IN(clk),
    .CLK_OUT(clk_out2),
    .D(4'h0),
    .DLY_ADJ(1'h0),
    .DLY_INCDEC(1'h0),
    .DLY_LOAD(1'h0),
    .DLY_TAP_VALUE({ _05_, delay_tap_value_2 }),
    .FAST_PHASE_CLK({ fast_clk, fast_clk, fast_clk, fast_clk }),
    .LOAD_WORD(loaded),
    .OE(1'h1),
    .PLL_FAST_CLK(fast_clk),
    .PLL_LOCK(pll_lock),
    .Q(Q),
    .RST(reset)
  );
  assign _01_ = loaded;
  assign _02_ = loaded;
  assign _03_ = loaded;
  assign delay_tap_value[5:1] = 5'h00;
endmodule