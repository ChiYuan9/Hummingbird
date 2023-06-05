//=====================================================================
//Designer: Yuan Chi
//Date: 30 May 2023
//Description: This ifetch module generates next PC and bus request
//=====================================================================

`include "e203_defines.v"

module e203_ifu_ifetch
(
    output [`E203_PC_SIZE-1:0] inspect_pc,

    input[`E203_PC_SIZE-1:0] pc_rtvec, // PC value after reset

    //////////////////////////////////////////////////////////////
    //Fetch Interface to memory system, internal protocol
    //Ifetch REQ channel
    output ifu_req_valid,   //Handshake valid
    input ifu_req_ready,    //Handshake ready

    output  [`E203_PC_SIZE-1:0] ifu_req_pc, //Fetch PC
    output  ifu_req_seq,    //This request is a sequential instruction fetch 
    output  ifu_req_seq_rv32,   //This request is incremented 32bits fetch
    output  [`E203_PC_SIZE-1:0] ifu_req_last_pc,    //The last accessed PC address

    //Ifetch REP channel
    input   ifu_rsp_valid,  //Response valid
    output  ifu_rsp_ready,  //Response ready
    input   ifu_rsp_err,    //Response error

    input   [`E203_INSTR_SIZE-1:0] ifu_rsp_instr,   //Response instruction
    //////////////////////////////////////////////////////////////
    //The IR stage to EXU interface
    output  [`E203_INSTR_SIZE-1:0] ifu_o_ir,    //The instruction register
    output  [`E203_PC_SIZE-1:0] ifu_o_pc    //The PC register along with
    output ifu_o_pc_vld,
    output  [`E203_RFIDX_WIDTH-1:0] ifu_o_rs1idx,
    output  [`E203_RFIDX_WIDTH-1:0] ifu_o_rs2idx,
    output  ifu_o_prdt_taken,   //The Bxx is predicted as taken
    output  ifu_o_misalgn,  //The fetch misalign 
    output  ifu_o_buserr,   //The fetch bus error
    output  ifu_o_muldiv_b2b,   //The mul/div back2back case
    output  ifu_o_valid,    //Handshake signals with EXU stage
    input   ifu_o_ready,

    output  pipe_flush_ack,
    input   pipe_flush_req,
    input   [`E203_PC_SIZE-1:0] pipe_flush_add_op1,  
    input   [`E203_PC_SIZE-1:0] pipe_flush_add_op2,
    `ifdef E203_TIMING_BOOST//}
    input   [`E203_PC_SIZE-1:0] pipe_flush_pc,  
    `endif//}

    input   ifu_halt_req,
    output  ifu_halt_ack,

    input   oitf_empty,
    input   [`E203_XLEN-1:0] rf2ifu_x1,
    input   [`E203_XLEN-1:0] rf2ifu_rs1,
    input   dec2ifu_rslen,
    input   dec2ifu_rden,
    input   [`E203_RFIDX_WIDTH-1:0] dec2ifu_rdidx,
    input   dec2ifu_mulhsu,
    input   dec2ifu_rem,
    input   dec2ifu_divu,
    input   dec2ifu_remu,

    input clk,
    input rst_n
);

    wire ifu_req_hsked = (ifu_req_valid & ifu_req_ready);
    wire ifu_rsp_hsked = (ifu_rsp_valid & ifu_rsp_ready);
    wire ifu_ir_o_hsked = (ifu_o_valid & ifu_o_ready);
    wire pipe_flush_hsked = pipe_flush_req & pipe_flush_ack;

    // The rst_flag is the synced version of rst_n
    // The rst_flag will be clear when rst_n is de-asserted
    wire reset_flag_r;
    sirv_gnrl_dffrs #(1) reset_flag_dffrs (1'b0, reset_flag_r, clk, rst_n); //reset_flag_r changes to 1 after reset

    // The reset_req valid is set when Currently reset_flag is asserting
    // The reset_req valid is clear when Currently reset_req is asserting and Currently the flush can be accepted by IFU
    wire reset_req_r;
    wire reset_req_set = (~reset_req_r) & reset_flag_r;
    wire reset_req_clr = reset_req_r & ifu_req_hsked;

    wire reset_req_ena = reset_req_set | reset_req_clr;
    wire reset_req_nxt = reset_req_set | (~reset_req_clr);
    sirv_gnrl_dfflr #(1) reset_req_dfflr(reset_req_ena, reset_req_nxt, reset_req_r, clk, rst_n);
    wire ifu_reset_req = reset_req_r;

    //////////////////////////////////////////////////////////////
    // The halt ack generation

    wire halt_ack_set;
    wire halt_ack_clr;
    wire halt_ack_ena;
    wire halt_ack_r;
    wire halt_ack_nxt;

    // The halt_ack will set when 
    // 1) Currently halt_req is asserting 
    // 2) Currently halt_ack is not asserting
    // 3) CUrrently the ifetch REQ channel is ready, means there is no oustanding transactions
    wire ifu_no_outs;
    assign halt_ack_set = ifu_halt_req & ~halt_ack_r & ifu_no_outs;
    // The halt_ack_r valid is cleared when 
    // 1) Currently halt_ack is asserting
    // 2) Currently halt_req is de-asserting
    assign halt_ack_clr = halt_ack_r & ~ifu_halt_req;

    assign halt_ack_ena = halt_ack_set | halt_ack_clr;
    assign halt_ack_nxt = halt_ack_set | ~halt_ack_clr;

    sirv_gnrl_dfflr #(1) halt_ack_dfflr (halt_ack_ena, halt_ack_nxt, halt_ack_r, clk, rst_n);

    assign ifu_halt_ack = halt_ack_r;

    //////////////////////////////////////////////////////////////
    // The flush ack signal generation
    // Ideally the flush is acked when the ifetch interface is ready or there is response valid
    // But to cut the comb loop between EXU and IFU, we always accept the flush, when it is not really ackowledged
    // Even there is a delayed flush pending there, we still can accept new flush request

    assign pip_flush_ack = 1'b1;
    wire dly_flush_set;
    wire dly_flush_clr;
    wire dly_flush_ena;
    wire dly_flush_nxt;
    wire dly_flush_r;
    // The dly_flush will be set when there is a flush request is coming, but the ifu is not ready to accept new fetch request
    assign dly_flush_set = pipe_flush_req & ~ifu_req_hsked;
    // The dly_flush_r valid is cleared when the delayed flush is issued
    assign dly_flush_clr = dly_flush_r & ifu_req_hsked;
    assign dly_flush_ena = dly_flush_set | dly_flush_clr;
    assign dly_flush_nxt = dly_flush_set | ~dly_flush_clr;
    sirv_gnrl_dfflr #(1) dly_flush_dfflr (dly_flush_ena, dly_flush_nxt, dly_flush_r, clk, rst_n);
    wire dly_pipe_flush_req = dly_flush_r;
    wire pipe_flush_req_real = pipe_flush_req | dly_pipe_flush_req;

    //////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////
    // The IR register to be used in EXU for decoding
    wire ir_valid_set;
    wire ir_valid_clr;
    wire ir_valid_ena;
    wire ir_valid_r;
    wire ir_valid_nxt;

    wire ir_pc_vld_set;
    wire ir_pc_vld_clr;
    wire ir_pc_vld_ena;
    wire ir_pc_vld_r;
    wire ir_pc_vld_nxt;

    // The ir valid is set when there is new instruction fetched and no flush
    wire ifu_rsp_need_replay;
    wire pc_newpend_r;
    wire ifu_ir_i_ready;
    
    assign ir_valid_set = ifu_rsp_hsked & ~pipe_flush_req_real & ~ifu_rsp_need_replay;
    assign ir_pc_vld_set = pc_newpend_r & ifu_ir_i_ready & ~pipe_flush_req_real & ifu_rsp_need_replay;
    
    //The ir valid is cleared when it is accepted by EXU stage or the flush happening
    assign ir_valid_clr = ifu_ir_o_hsked | (pipe_flush_hsked & ir_valid_r);
    assign ir_pc_vld_clr = ir_valid_clr;

    assign ir_valid_ena = ir_valid_set | ir_valid_clr;
    assign ir_valid_nxt = ir_valid_set | ~ir_valid_clr;
    



    

endmodule