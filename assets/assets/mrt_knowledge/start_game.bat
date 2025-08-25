@echo off
chcp 65001 >nul
echo ================================================
echo 🚇 捷運知識王遊戲啟動器
echo ================================================
echo.

echo 正在檢查 Python 環境...
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo ❌ 錯誤：未找到 Python
    echo.
    echo 📋 請按照以下步驟安裝 Python：
    echo 1. 訪問 https://www.python.org/downloads/
    echo 2. 下載並安裝 Python 3.7 或更高版本
    echo 3. 安裝時請勾選 "Add Python to PATH"
    echo.
    echo 📖 詳細安裝說明請查看 INSTALL_GUIDE.md
    echo.
    pause
    exit /b 1
)

echo ✅ Python 環境檢查通過
echo.
echo 🎮 正在啟動捷運知識王遊戲...
echo.

REM 切換到遊戲目錄
cd /d "%~dp0"

REM 嘗試使用快速啟動腳本
echo 嘗試快速啟動...
python quick_start.py >nul 2>&1
if errorlevel 1 (
    echo 快速啟動失敗，嘗試標準啟動...
    python start_game.py
)

echo.
echo 遊戲已關閉
pause
