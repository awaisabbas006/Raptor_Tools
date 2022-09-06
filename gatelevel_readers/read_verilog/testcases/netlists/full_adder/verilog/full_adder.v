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
  assign _02_ = 8'hca >> { b, 1'h1, a };
  assign _05_ = 2'h1 >> a;
  assign _01_ = 8'hca >> { b, _05_, 1'h1 };
  assign _03_ = 8'hca >> { _02_, 1'h1, cin };
  assign _00_ = 8'hca >> { _01_, _04_, cin };
  assign sum = 8'hca >> { _00_, _03_, 1'h0 };
  assign _06_ = 2'h1 >> _01_;
  assign _04_ = 8'hca >> { _02_, _07_, 1'h1 };
  assign cout = 8'hca >> { _04_, _06_, 1'h1 };
  assign _07_ = 2'h1 >> cin;
endmodule