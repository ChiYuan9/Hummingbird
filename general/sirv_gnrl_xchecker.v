//=====================================================================
//Designer: Yuan Chi
//Date: May 25 2023
//=====================================================================

`ifndef FPGA_SOURCE//{
`ifndef DISABLE_SV_ASSERTION//{
//Synopsys translate_off
module sirv_gnrl_xchecker #(parameter DW = 32)
(
    input [DW-1] i_dat,
    input clk
)

CHECK_THE_X_VALUE:
    assert property (@(posedge clk) ((^(i_dat)) !== 1'bx))
    else $fatal ("\n Error: Oops, detected a X value ! This should never happer. \n");

endmodule
//Synopsys translate_on
`endif//}
`endif//}