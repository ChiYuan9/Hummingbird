//=====================================================================
//Designer: Yuan Chi
//Date: 28 May 2023
//Description: The mini-decode module decode the instruction in IFU
//=====================================================================

`include "e203_defines.v"

module e203_ifu_minidec
(
    input [`E203_INSTR_SIZE-1:0] instr, // E203_INSTR_SIZE = the length of instruction
    
    output dec_rs1en,
    output dec_rs2en,
    output[`E203_RFIDX_WIDTH-1:0] dec_rs1idx,   // E203_RFIDX_WIDTH = the length of regfile index
    output[`E203_RFIDX_WIDTH-1:0] dec_rs2idx,

    output dec_mulhsu,
    output dec_mul,
    output dec_div,
    output dec_rem,
    output dec_divu,
    output dec_remu,

    output dec_rv32,    // showing the instruction is 16bits or 32bits
    output dec_bjp,     // showing the instruction is normal or branch
    output dec_jal,     // showing the instruction is jal or not
    output dec_jalr,    // showing the instruction is jalr or not
    output dec_bxx,     // showing the instruction is bxx(BEQ or BNE etc.)
    output [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx,
    output [`E203_XLEN-1:0] dec_bjp_imm // E203_XLEN = the length of imm in branch instruction
);

e203_exu_decode u_e203_exu_decode
(
    .i_instr(instr),
    .i_pc(`E203_PC_SIZE'b0),    // zero unrelevent signals
    .i_predt_taken(1'b0),
    .i_muldiv_b2b(1'b0),

    .i_misalgn(1'b0),
    .i_buserr(1'b0),
    
    .dbg_mode(1'b0),

    .dec_misalgn(), //dangling unrelevent signals
    .dec_buserr(),
    .dec_ilegl(),

    .dec_mulhsu(dec_mulhsu),
    .dec_mul(dec_mul),
    .dec_div(dec_div),
    .dec_rem(dec_rem),
    .dec_divu(dec_divu),
    .dec_remu(dec_remu),

    .dec_rv32(dec_rv32),
    .dec_bjp(dec_bjp),
    .dec_jal(dec_jal),
    .dec_jalr(dec_jalr),
    .dec_bxx(dec_bxx),

    .dec_jalr_rs1idx(dec_jalr_rs1idx),
    .dec_bjp_imm(dec_bjp_imm)
);

endmodule