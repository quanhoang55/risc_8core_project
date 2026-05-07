### RISC 8 core CPU SIMULATOR:

* **Member:**
  - Hoang Anh Quan, 202418969
  - ...
  - ...
  - Bui Thi Mai Linh, 

* **Project Tree**
risc_8core_project/
├── rtl/                        # All Verilog HDL source files
│   ├── core/                   # Internal logic for ONE CPU core
│   │   ├── alu.v               # Arithmetic Logic Unit
│   │   ├── reg_file.v          # Register File (32 registers)
│   │   ├── control_unit.v      # Instruction decoder / control signals
│   │   ├── pc_logic.v          # Program Counter update logic
│   │   └── risc_core.v         # Single-core top module
│   │
│   ├── memory/                 # Memory modules
│   │   ├── instr_mem.v         # Instruction ROM
│   │   └── data_mem.v          # Shared Data RAM
│   │
│   ├── interconnect/           # Communication infrastructure
│   │   ├── arbiter.v           # RAM access arbitration
│   │   └── bus_ctrl.v          # Address/data routing logic
│   │
│   └── top_8core.v             # Top-level system (instantiates 8 cores)
│
├── tb/                         # Testbenches
│   ├── core_tb.v               # Unit test for a single core
│   └── system_tb.v             # Full 8-core system simulation
│
├── software/                   # CPU programs
│   ├── program.asm             # Assembly source code
│   └── program.hex             # Machine code loaded into instruction memory
│
├── scripts/                    # Utility scripts
│   └── compile.sh              # Simulation compile/run script
│
└── README.md                   # Project documentation
