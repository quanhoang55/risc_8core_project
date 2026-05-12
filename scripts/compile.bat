@echo off
echo === Bien dich RISC-V 8-Core System ===

:: Chuyển về thư mục root của project
cd /d "%~dp0\.."

:: Xóa các file cũ nếu có
if exist tb\system_test.vvp del /f /q tb\system_test.vvp
if exist tb\system_tb.vcd del /f /q tb\system_tb.vcd

:: Chạy iverilog để biên dịch tất cả mã nguồn RTL và Testbench
iverilog -g2012 -o tb\system_test.vvp -I rtl\core -I rtl\interconnect -I rtl\memory rtl\core\*.v rtl\memory\*.v rtl\interconnect\*.v rtl\top_8core.v tb\system_tb.v

if %ERRORLEVEL% EQU 0 (
    echo Bien dich thanh cong! Dang chay mo phong...
    echo ==================================================
    cd tb
    vvp system_test.vvp
    echo ==================================================
    echo Hoan tat! Ban co the xem file song bang lenh: gtkwave system_tb.vcd
) else (
    echo Bien dich that bai! Hay kiem tra lai ma nguon.
)
pause
