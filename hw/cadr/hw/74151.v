/*
 * $Id$
 */

module part_74S151 ( I0, I1, I2, I3, I4, I5, I6, I7,
		     SEL0, SEL1, SEL2, CE_N,
		     Q, Q_N );

  input I0, I1, I2, I3, I4, I5, I6, I7;
  input SEL0, SEL1, SEL2, CE_N;
  output Q, Q_N;

  wire[2:0] d_bar,d_sel;

	not #5
		n0(d_bar[0],SEL0),
		n1(d_bar[1],SEL1),
		n2(d_bar[2],SEL2),
		n3(d_sel[0],d_bar[0]),
		n4(d_sel[1],d_bar[1]),
		n5(d_sel[2],d_bar[2]),
		n6(Q_N,Q),
		n7(str,CE_N);
	and #5
		a0(wa0,I0,d_bar[2],d_bar[1],d_bar[0],str),
		a1(wa1,I1,d_bar[2],d_bar[1],d_sel[0],str),
		a2(wa2,I2,d_bar[2],d_sel[1],d_bar[0],str),
		a3(wa3,I3,d_bar[2],d_sel[1],d_sel[0],str),
		a4(wa4,I4,d_sel[2],d_bar[1],d_bar[0],str),
		a5(wa5,I5,d_sel[2],d_bar[1],d_sel[0],str),
		a6(wa6,I6,d_sel[2],d_sel[1],d_bar[0],str),
		a7(wa7,I7,d_sel[2],d_sel[1],d_sel[0],str);
	nor #5
		nr(Q,wa0,wa1,wa2,wa3,wa4,wa5,wa6,wa7);
endmodule
