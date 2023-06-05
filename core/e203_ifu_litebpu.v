//=====================================================================
//Designer: Yuan Chi
//Date: 28 May 2023
//Description: The lite_BPU handles very simple branch prediction at IFU
//=====================================================================
`include "e203_defines.v"

module e203_ifu_litebpu
(
    input [`E203_PC_SIZE-1:0] pc,//Current pc

    //The main-decode info
    input dec_jal,
    input dec_jalr,
    input dec_bxx,
    input [`E203_XLEN-1:0] dec_bjp_imm,
    input [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx,

    //The IR index and OITF status to be used for checking dependency
    input oitf_empty,
    input ir_empty,
    input ir_rs1en,
    input jalr_rs1idx_cam_irrdidx,

    //The add op to next-pc adder
    output bpu_wait,
    output prdt_taken,
    output [`E203_PC_SIZE-1:0] prdt_pc_add_op1,
    output [`E203_PC_SIZE-1:0] prdt_pc_add_op2,

    input dec_i_valid,

    //The RS1 to read regfile
    output bpu2rf_rs1_ena,
    input  ir_valid_clr,
    input [`E203_XLEN-1:0] rf2bpu_x1,
    input [`E203_XLEN-1:0] rf2bpu_rs1,

    input clk,
    input rst_n
);
    //The JAL and JALR will always jump, bxx backward is predicted as taken
    assign prdt_taken = dec_jal | dec_jalr | (dec_bxx & dec_bjp_imm[`E203_XLEN - 1]);
    
    //Stop IFU to gererate next pc
    assign bpu_wait = jalr_rs1x1_dep | jalr_rs1xn_dep | rs1xn_rdrf_set;

    //Calculate the first operand of PC adder
    wire prdt_pc_add_op1 = (dec_jal | dec_bxx) ? pc[`E203_PC_SIZE-1:0]
                        : (dec_jalr & dec_jalr_rs1x0) ? `E203_PC_SIZE'h0
                        : (dec_jalr & dec_jalr_rs1x1) ? rf2bpu_x1[`E203_PC_SIZE-1:0]
                        : rf2bpu_rs1[`E203_PC_SIZE-1:0];
    
    //Calculate the second operand of PC adder
    wire prdt_pc_add_op2 = dec_bjp_imm[`E203_PC_SIZE-1:0];


    wire dec_jalr_rs1x0 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'h0);
    wire dec_jalr_rs1x1 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'h1);
    wire dec_jalr_rs1xn = ~dec_jalr_rs1x0 & ~dec_jalr_rs1x1;

    //X1 RAW dependce will appear when OITF is not empty or index of instruction in IR register is x1
    wire jalr_rs1x1_dep = dec_i_valid & dec_jalr & dec_jalr_rs1x1 & (~oitf_empty | jalr_rs1idx_cam_irrdidx);

    //Xn RAW dependce will appear when OITF is not empty or there are instuction in IR register
    wire jalr_rs1xn_dep = dec_i_valid & dec_jalr & dec_jalr_rs1xn & (~oitf_empty | ~ir_empty);

    //If only depend to IR stage, then if IR is under claering, or it doesn't use RS1 index, then we can also treat it as non-dependent
    wire jalr_rs1xn_dep_ir_clr = jalr_rs1xn_dep & oitf_empty & ~ir_empty & (ir_valid_clr | ~ir_rs1en);


    wire rs1xn_rdrf_set = ~rs1xn_rdrf_r & dec_i_valid & dec_jalr & dec_jalr_rs1xn & (~jalr_rs1xn_dep | jalr_rs1xn_dep_ir_clr);
    wire rs1xn_rdrf_clr = rs1xn_rdrf_r;
    wire rs1xn_rdrf_ena = rs1xn_rdrf_set | rs1xn_rdrf_clr;
    wire rs1xn_rdrf_nxt = rs1xn_rdrf_set | ~rs1xn_rdrf_clr;

    wire rs1xn_rdrf_r;
    sirv_gnrl_dfflr #(1) rs1xn_rdrf_dfflrs(rs1xn_rdrf_ena, rs1xn_rdrf_nxt, rs1xn_rdrf_r, clk, rst_n);

    assign bpu2rf_rs1_ena = rs1xn_rdrf_set;
endmodule