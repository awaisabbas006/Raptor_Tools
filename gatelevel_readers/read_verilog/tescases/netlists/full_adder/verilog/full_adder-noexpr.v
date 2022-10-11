/* Generated by Yosys 0.17+76 (git sha1 035496b50, gcc 9.1.0 -fPIC -Os) */

(* top =  1  *)
(* src = "./rtl/full_adder/full_adder.v:1.1-10.10" *)
module full_adder(a, b, cin, sum, cout);
  wire _00_;
  wire _01_;
  wire _02_;
  wire _03_;
  wire _04_;
  wire _05_;
  wire _06_;
  wire _07_;
  (* src = "./rtl/full_adder/full_adder.v:3.7-3.8" *)
  input a;
  wire a;
  (* src = "./rtl/full_adder/full_adder.v:3.9-3.10" *)
  input b;
  wire b;
  (* src = "./rtl/full_adder/full_adder.v:3.11-3.14" *)
  input cin;
  wire cin;
  (* src = "./rtl/full_adder/full_adder.v:4.12-4.16" *)
  output cout;
  wire cout;
  (* src = "./rtl/full_adder/full_adder.v:4.8-4.11" *)
  output sum;
  wire sum;
  \$lut  #(
    .LUT(8'hca),
    .WIDTH(32'd3)
  ) _08_ (
    .A({ b, 1'h1, a }),
    .Y(_02_)
  );
  \$lut  #(
    .LUT(2'h1),
    .WIDTH(32'd1)
  ) _09_ (
    .A(a),
    .Y(_05_)
  );
  \$lut  #(
    .LUT(8'hca),
    .WIDTH(32'd3)
  ) _10_ (
    .A({ b, _05_, 1'h1 }),
    .Y(_01_)
  );
  \$lut  #(
    .LUT(8'hca),
    .WIDTH(32'd3)
  ) _11_ (
    .A({ _02_, 1'h1, cin }),
    .Y(_03_)
  );
  \$lut  #(
    .LUT(8'hca),
    .WIDTH(32'd3)
  ) _12_ (
    .A({ _01_, _04_, cin }),
    .Y(_00_)
  );
  \$lut  #(
    .LUT(8'hca),
    .WIDTH(32'd3)
  ) _13_ (
    .A({ _00_, _03_, 1'h0 }),
    .Y(sum)
  );
  \$lut  #(
    .LUT(2'h1),
    .WIDTH(32'd1)
  ) _14_ (
    .A(_01_),
    .Y(_06_)
  );
  \$lut  #(
    .LUT(8'hca),
    .WIDTH(32'd3)
  ) _15_ (
    .A({ _02_, _07_, 1'h1 }),
    .Y(_04_)
  );
  \$lut  #(
    .LUT(8'hca),
    .WIDTH(32'd3)
  ) _16_ (
    .A({ _04_, _06_, 1'h1 }),
    .Y(cout)
  );
  \$lut  #(
    .LUT(2'h1),
    .WIDTH(32'd1)
  ) _17_ (
    .A(cin),
    .Y(_07_)
  );
endmodule