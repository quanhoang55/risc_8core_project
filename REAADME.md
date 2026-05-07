### RISC 8 core CPU SIMULATOR:

* **Member:**
  - Hoang Anh Quan, 202418969
  - ...
  - ...
  - ...

* **Project Tree**
risc_8core_project/
├── rtl/                        # All your Verilog source code
│   ├── core/                   # The internal logic of ONE core
│   │   ├── alu.v               # Arithmetic Logic Unit
│   │   ├── reg_file.v          # 32 Register array
│   │   ├── control_unit.v      # Opcode decoder
│   │   ├── pc_logic.v          # Program Counter logic
│   │   └── risc_core.v         # Core Top (connects ALU/Reg/Control)
│   ├── memory/                 # Memory components
│   │   ├── instr_mem.v         # ROM (holds your program code)
│   │   └── data_mem.v          # RAM (shared by all 8 cores)
│   ├── interconnect/           # The "Glue"
│   │   ├── arbiter.v           # Decides which core talks to RAM
│   │   └── bus_ctrl.v          # Manages address/data routing
│   └── top_8core.v             # THE MAIN FILE (Instantiates 8 cores)
├── tb/                         # Testbenches
│   ├── core_tb.v               # Test one core by itself
│   └── system_tb.v             # THE FINAL TEST (Runs all 8 cores)
├── software/                   # Your "Program" files
│   ├── program.asm             # Your RISC assembly code
│   └── program.hex             # The hex file loaded into instr_mem.v
├── scripts/                    # Tools to make life easier
│   └── compile.sh              # Command to run your simulator (Icarus/Vivado)
└── README.md                   # How to run the project
