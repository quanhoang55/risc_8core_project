@echo off
echo ==================================================
echo [TinyTeX] Dang chay latexmk o che do WATCH...
echo PDF se tu dong cap nhat moi khi ban luu file .tex.
echo Nhan Ctrl+C de dung lai.
echo ==================================================

latexmk -pvc -pdf -interaction=nonstopmode main.tex
