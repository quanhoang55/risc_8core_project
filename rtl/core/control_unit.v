// =============================================================================
// control_unit.v - Bộ giải mã lệnh RISC-V (RV32I Subset)
//
// Input:  instruction[31:0] - Mã lệnh 32-bit từ Instruction Memory
// Output: Tất cả tín hiệu điều khiển cho ALU, RegFile, Memory, PC
//
// Hỗ trợ: R-type, I-type, S-type, B-type, U-type, J-type
// =============================================================================
`timescale 1ns / 1ps

module control_unit (
    input  wire [31:0] instruction,  // Mã lệnh 32-bit

    // --- Tín hiệu điều khiển ---
    output reg         reg_write,    // Ghi vào Register File?
    output reg         alu_src,      // Nguồn toán hạng B: 0=rs2, 1=immediate
    output reg  [3:0]  alu_control,  // Mã phép toán cho ALU
    output reg         mem_read,     // Là lệnh Load? (LW)
    output reg         mem_write,    // Là lệnh Store? (SW)
    output reg         mem_to_reg,   // Dữ liệu ghi rd: 0=ALU, 1=mem_data
    output reg         branch,       // Là lệnh Branch?
    output reg  [2:0]  branch_type,  // Loại branch: funct3 (BEQ=000, BNE=001, BLT=100, BGE=101)
    output reg         jump,         // Là lệnh JAL/JALR?
    output reg         jalr,         // Là JALR? (jump target = rs1 + imm)
    output reg         lui,          // Là LUI?
    output reg         auipc,        // Là AUIPC?
    output reg         mem_lr,       // Là lệnh Load-Reserved?
    output reg         mem_sc,       // Là lệnh Store-Conditional?
    output reg         mem_amo,      // Là lệnh AMO?
    output reg  [3:0]  amo_op,       // Mã phép toán AMO

    // --- Immediate Generator ---
    output reg  [31:0] imm,          // Giá trị immediate (sign-extended)

    // --- Địa chỉ thanh ghi ---
    output wire [4:0]  rs1_addr,     // Source register 1
    output wire [4:0]  rs2_addr,     // Source register 2
    output wire [4:0]  rd_addr       // Destination register
);

    // =========================================================================
    // Trích xuất các trường từ instruction
    // =========================================================================
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    wire [4:0] funct5 = instruction[31:27];

    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign rd_addr  = instruction[11:7];

    // =========================================================================
    // Opcode definitions (RISC-V standard)
    // =========================================================================
    localparam OP_R_TYPE  = 7'b0110011;  // ADD, SUB, AND, OR, XOR, SLL, SRL, SLT
    localparam OP_I_TYPE  = 7'b0010011;  // ADDI, ANDI, ORI, XORI, SLTI, SLLI, SRLI
    localparam OP_LOAD    = 7'b0000011;  // LW
    localparam OP_STORE   = 7'b0100011;  // SW
    localparam OP_BRANCH  = 7'b1100011;  // BEQ, BNE, BLT, BGE
    localparam OP_JAL     = 7'b1101111;  // JAL
    localparam OP_JALR    = 7'b1100111;  // JALR
    localparam OP_LUI     = 7'b0110111;  // LUI
    localparam OP_AUIPC   = 7'b0010111;  // AUIPC
    localparam OP_AMO     = 7'b0101111;  // AMO (LR, SC, AMO)

    // =========================================================================
    // ALU control codes (khớp với alu.v)
    // =========================================================================
    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_SLL = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_SRL = 4'b0101;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;

    // =========================================================================
    // Immediate Generator
    // Tạo giá trị immediate dựa trên instruction type, sign-extended 32-bit
    // =========================================================================
    always @(*) begin
        case (opcode)
            // I-type: imm[11:0] = instruction[31:20]
            OP_I_TYPE, OP_LOAD, OP_JALR:
                imm = {{20{instruction[31]}}, instruction[31:20]};

            // AMO: Không dùng imm cho tính địa chỉ (imm = 0), rs1 chứa địa chỉ
            OP_AMO:
                imm = 32'd0;

            // S-type: imm[11:0] = {instruction[31:25], instruction[11:7]}
            OP_STORE:
                imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

            // B-type: imm[12:1] = {[31], [7], [30:25], [11:8]}
            OP_BRANCH:
                imm = {{19{instruction[31]}}, instruction[31], instruction[7],
                        instruction[30:25], instruction[11:8], 1'b0};

            // U-type: imm[31:12] = instruction[31:12]
            OP_LUI, OP_AUIPC:
                imm = {instruction[31:12], 12'b0};

            // J-type: imm[20:1] = {[31], [19:12], [20], [30:21]}
            OP_JAL:
                imm = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                        instruction[20], instruction[30:21], 1'b0};

            default:
                imm = 32'd0;
        endcase
    end

    // =========================================================================
    // Main Decoder: opcode → control signals
    // =========================================================================
    always @(*) begin
        // Mặc định: tất cả tắt
        reg_write   = 1'b0;
        alu_src     = 1'b0;
        alu_control = ALU_ADD;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;
        branch      = 1'b0;
        branch_type = 3'b000;
        jump        = 1'b0;
        jalr        = 1'b0;
        lui         = 1'b0;
        auipc       = 1'b0;
        mem_lr      = 1'b0;
        mem_sc      = 1'b0;
        mem_amo     = 1'b0;
        amo_op      = 4'd0;

        case (opcode)
            // =================================================================
            // R-type: ADD, SUB, AND, OR, XOR, SLL, SRL, SLT
            // =================================================================
            OP_R_TYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;  // Toán hạng B = rs2

                case (funct3)
                    3'b000: alu_control = (funct7[5]) ? ALU_SUB : ALU_ADD; // ADD/SUB
                    3'b001: alu_control = ALU_SLL;  // SLL
                    3'b010: alu_control = ALU_SLT;  // SLT
                    3'b100: alu_control = ALU_XOR;  // XOR
                    3'b101: alu_control = ALU_SRL;  // SRL
                    3'b110: alu_control = ALU_OR;   // OR
                    3'b111: alu_control = ALU_AND;  // AND
                    default: alu_control = ALU_ADD;
                endcase
            end

            // =================================================================
            // I-type ALU: ADDI, ANDI, ORI, XORI, SLTI, SLLI, SRLI
            // =================================================================
            OP_I_TYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;  // Toán hạng B = immediate

                case (funct3)
                    3'b000: alu_control = ALU_ADD;  // ADDI
                    3'b001: alu_control = ALU_SLL;  // SLLI
                    3'b010: alu_control = ALU_SLT;  // SLTI
                    3'b100: alu_control = ALU_XOR;  // XORI
                    3'b101: alu_control = ALU_SRL;  // SRLI
                    3'b110: alu_control = ALU_OR;   // ORI
                    3'b111: alu_control = ALU_AND;  // ANDI
                    default: alu_control = ALU_ADD;
                endcase
            end

            // =================================================================
            // Load: LW (rd = mem[rs1 + imm])
            // =================================================================
            OP_LOAD: begin
                reg_write   = 1'b1;
                alu_src     = 1'b1;   // ALU tính địa chỉ: rs1 + imm
                alu_control = ALU_ADD;
                mem_read    = 1'b1;
                mem_to_reg  = 1'b1;   // Ghi mem data vào rd
            end

            // =================================================================
            // Store: SW (mem[rs1 + imm] = rs2)
            // =================================================================
            OP_STORE: begin
                alu_src     = 1'b1;   // ALU tính địa chỉ: rs1 + imm
                alu_control = ALU_ADD;
                mem_write   = 1'b1;
            end

            // =================================================================
            // Branch: BEQ, BNE, BLT, BGE
            // =================================================================
            OP_BRANCH: begin
                alu_src     = 1'b0;
                alu_control = ALU_SUB;  // So sánh bằng phép trừ
                branch      = 1'b1;
                branch_type = funct3;   // 000=BEQ, 001=BNE, 100=BLT, 101=BGE
            end

            // =================================================================
            // JAL: rd = PC+4, PC = PC + imm
            // =================================================================
            OP_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
            end

            // =================================================================
            // JALR: rd = PC+4, PC = (rs1 + imm) & ~1
            // =================================================================
            OP_JALR: begin
                reg_write   = 1'b1;
                alu_src     = 1'b1;
                alu_control = ALU_ADD;
                jump        = 1'b1;
                jalr        = 1'b1;
            end

            // =================================================================
            // LUI: rd = imm << 12 (đã shift trong immediate generator)
            // =================================================================
            OP_LUI: begin
                reg_write = 1'b1;
                lui       = 1'b1;
            end

            // =================================================================
            // AUIPC: rd = PC + (imm << 12)
            // =================================================================
            OP_AUIPC: begin
                reg_write = 1'b1;
                auipc     = 1'b1;
            end

            // =================================================================
            // Atomic (A-Extension): LR, SC, AMO
            // =================================================================
            OP_AMO: begin
                alu_src     = 1'b1;   // ALU tính địa chỉ: rs1 + 0 (imm = 0)
                alu_control = ALU_ADD;
                
                case (funct5)
                    5'b00010: begin // LR.W
                        mem_lr    = 1'b1;
                        reg_write = 1'b1;
                    end
                    5'b00011: begin // SC.W
                        mem_sc    = 1'b1;
                        reg_write = 1'b1; // Kết quả SC (0 hoặc 1) ghi vào rd
                    end
                    default: begin  // Các lệnh AMO khác
                        mem_amo   = 1'b1;
                        reg_write = 1'b1; // Giá trị cũ ghi vào rd
                        // Map funct5 sang amo_op cho bus_ctrl
                        case (funct5)
                            5'b00001: amo_op = 4'd0; // AMO_SWAP
                            5'b00000: amo_op = 4'd1; // AMO_ADD
                            5'b01100: amo_op = 4'd2; // AMO_AND
                            5'b01010: amo_op = 4'd3; // AMO_OR
                            5'b00100: amo_op = 4'd4; // AMO_XOR
                            5'b10100: amo_op = 4'd5; // AMO_MAX
                            5'b11100: amo_op = 4'd6; // AMO_MAXU
                            5'b10000: amo_op = 4'd7; // AMO_MIN
                            5'b11000: amo_op = 4'd8; // AMO_MINU
                            default:  amo_op = 4'd0;
                        endcase
                    end
                endcase
            end

            default: ; // NOP (tất cả outputs đã mặc định = 0)
        endcase
    end

endmodule
