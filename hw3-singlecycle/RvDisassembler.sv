`timescale 1ns / 1ns

/** WARNING: this code was largely written by ChatGPT, and has not been thoroughly tested! */
function automatic string rv_disasm (input bit [31:0] instruction);

    string da_str;
    bit [6:0] opcode   = instruction[6:0];
    bit [4:0] rd       = instruction[11:7];
    bit [2:0] funct3   = instruction[14:12];
    bit [4:0] rs1      = instruction[19:15];
    bit [4:0] rs2      = instruction[24:20];
    bit [6:0] funct7   = instruction[31:25];

    // U type
    bit [19:0] imm_u = instruction[31:12];

    // I type
    bit [11:0] imm_i = instruction[31:20];

    // S type
    bit [11:0] imm_s = {funct7, rd};

    // B type
    bit [12:0] imm_b = {funct7[6], rd[0], funct7[5:0], rd[4:1], 1'b0};

    // J type
    bit [20:0] tmp_j = {instruction[31:12], 1'b0};
    bit [20:0] imm_j = {tmp_j[20], tmp_j[10:1], tmp_j[11], tmp_j[19:12], 1'b0};

    case (opcode)
        // R-type instructions
        7'd51: begin
            if (funct7 == 7'h01) begin
                case (funct3)
                    3'd0: da_str = $sformatf("MUL x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd1: da_str = $sformatf("MULH x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd2: da_str = $sformatf("MULHSU x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd3: da_str = $sformatf("MULHU x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd4: da_str = $sformatf("DIV x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd5: da_str = $sformatf("DIVU x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd6: da_str = $sformatf("REM x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd7: da_str = $sformatf("REMU x%0d, x%0d, x%0d", rd, rs1, rs2);
                    default: da_str = "Unknown M-extension instruction";
                endcase
            end else begin
                case (funct3)
                    3'd0: da_str = $sformatf("ADD x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd1: da_str = $sformatf("SLL x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd2: da_str = $sformatf("SLT x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd3: da_str = $sformatf("SLTU x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd4: da_str = $sformatf("XOR x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd5: da_str = $sformatf("SRL x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd6: da_str = $sformatf("OR x%0d, x%0d, x%0d", rd, rs1, rs2);
                    3'd7: da_str = $sformatf("AND x%0d, x%0d, x%0d", rd, rs1, rs2);
                    default: da_str = "Unknown R-type instruction";
                endcase
            end
        end

        // ALU I-type instructions
        7'd19: begin
            case (funct3)
                3'd0: da_str = $sformatf("ADDI x%0d, x%0d, %0d", rd, rs1, imm_i);
                3'd1: da_str = $sformatf("SLLI x%0d, x%0d, %0d", rd, rs1, imm_i[4:0]);
                3'd2: da_str = $sformatf("SLTI x%0d, x%0d, %0d", rd, rs1, imm_i);
                3'd3: da_str = $sformatf("SLTIU x%0d, x%0d, %0d", rd, rs1, imm_i);
                3'd4: da_str = $sformatf("XORI x%0d, x%0d, %0d", rd, rs1, imm_i);
                3'd5: begin
                    if (funct7[5] == 0)
                        da_str = $sformatf("SRLI x%0d, x%0d, %0d", rd, rs1, imm_i[4:0]);
                    else if (funct7 == 7'b0100000)
                        da_str = $sformatf("SRAI x%0d, x%0d, %0d", rd, rs1, imm_i[4:0]);
                    else
                        da_str = "Unknown I-type instruction";
                end
                3'd6: da_str = $sformatf("ORI x%0d, x%0d, %0d", rd, rs1, imm_i);
                3'd7: da_str = $sformatf("ANDI x%0d, x%0d, %0d", rd, rs1, imm_i);
                default: da_str = "Unknown I-type instruction";
            endcase
        end

        // S-type instructions
        7'd35: begin
            case (funct3)
                3'd0: da_str = $sformatf("SB x%0d, %0d(x%0d)", rs2, imm_s, rs1);
                3'd1: da_str = $sformatf("SH x%0d, %0d(x%0d)", rs2, imm_s, rs1);
                3'd2: da_str = $sformatf("SW x%0d, %0d(x%0d)", rs2, imm_s, rs1);
                default: da_str = "Unknown S-type instruction";
            endcase
        end

        // U-type instructions
        7'd55: da_str = $sformatf("LUI x%0d, 0x%0x", rd, imm_u);
        7'd23: da_str = $sformatf("AUIPC x%0d, 0x%0x", rd, imm_u);

        // J-type instructions
        7'd111: begin
            case (opcode)
                7'b1101111: da_str = $sformatf("JAL x%0d, %0d", rd, imm_j);
                default: da_str = "Unknown J-type instruction";
            endcase
        end

        // B-type instructions
        7'd99: begin
            case (funct3)
                3'd0: da_str = $sformatf("BEQ x%0d, x%0d, %0d", rs1, rs2, imm_b);
                3'd1: da_str = $sformatf("BNE x%0d, x%0d, %0d", rs1, rs2, imm_b);
                // 2,3 they are undefined in RV32
                3'd4: da_str = $sformatf("BLT x%0d, x%0d, %0d", rs1, rs2, imm_b);
                3'd5: da_str = $sformatf("BGE x%0d, x%0d, %0d", rs1, rs2, imm_b);
                3'd6: da_str = $sformatf("BLTU x%0d, x%0d, %0d", rs1, rs2, imm_b);
                3'd7: da_str = $sformatf("BGEU x%0d, x%0d, %0d", rs1, rs2, imm_b);
                default: da_str = "Unknown B-type instruction";
            endcase
        end

        // Load instructions
        7'd3: begin
            case (funct3)
                3'd0: da_str = $sformatf("LB x%0d, %0d(x%0d)", rd, imm_i, rs1);
                3'd1: da_str = $sformatf("LH x%0d, %0d(x%0d)", rd, imm_i, rs1);
                3'd2: da_str = $sformatf("LW x%0d, %0d(x%0d)", rd, imm_i, rs1);
                // 3 is undefined in RV32
                3'd4: da_str = $sformatf("LBU x%0d, %0d(x%0d)", rd, imm_i, rs1);
                3'd5: da_str = $sformatf("LHU x%0d, %0d(x%0d)", rd, imm_i, rs1);
                default: da_str = "Unknown Load instruction";
            endcase
        end

        // JALR instruction
        7'd103: begin
            case (funct3)
                3'b000: da_str = $sformatf("JALR x%0d, x%0d, %0d", rd, rs1, imm_i);
                default: da_str = "Unknown JALR instruction";
            endcase
        end

        // fence instructions
        7'd15: begin
            case (funct3)
                3'b000: da_str = "fence";
                3'b001: begin
                    if (funct7 == 0) da_str = "fence.i";
                    else da_str = "Unknown fence instruction";
                end
                default: da_str = "Unknown fence instruction";
            endcase
        end

        // Environment instructions
        7'd115: begin
            if (instruction[31:7] == 0) begin
                da_str = "ecall";
            end else begin
                da_str = "Unknown environment instruction";
            end
        end
        7'd0: begin
            if (instruction[31:7] == 0) begin
                da_str = "bubble";
            end else begin
                da_str = "Unknown instruction";
            end
        end
        default: da_str = "Unknown instruction";
    endcase

    return da_str;
endfunction
