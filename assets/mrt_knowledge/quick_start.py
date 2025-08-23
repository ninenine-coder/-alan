#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
捷運知識王遊戲快速啟動腳本
簡化版本，適合初學者使用
"""

import os
import sys
import subprocess
import webbrowser
import time
from pathlib import Path

def main():
    print("🚇 捷運知識王遊戲快速啟動器")
    print("=" * 40)
    
    # 獲取當前腳本目錄
    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)
    
    print("正在檢查環境...")
    
    # 檢查 Python 版本
    try:
        version = sys.version_info
        print(f"✓ Python {version.major}.{version.minor}.{version.micro}")
    except:
        print("✗ 無法檢測 Python 版本")
        return
    
    # 檢查 Flask
    try:
        import flask
        print("✓ Flask 已安裝")
    except ImportError:
        print("正在安裝 Flask...")
        try:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'flask'])
            print("✓ Flask 安裝成功")
        except:
            print("✗ Flask 安裝失敗，請手動安裝：pip install flask")
            return
    
    # 檢查數據庫
    if not os.path.exists('taipei_metro_quiz.db'):
        print("正在初始化數據庫...")
        try:
            import data_init
            data_init.main()
            print("✓ 數據庫初始化成功")
        except Exception as e:
            print(f"✗ 數據庫初始化失敗：{e}")
            return
    
    print("\n🎮 啟動遊戲服務器...")
    print("遊戲地址：http://localhost:5000")
    print("按 Ctrl+C 停止服務器")
    print("-" * 40)
    
    # 延遲一下再打開瀏覽器
    time.sleep(3)
    
    try:
        webbrowser.open('http://localhost:5000')
    except:
        print("無法自動打開瀏覽器，請手動訪問：http://localhost:5000")
    
    # 啟動 Flask 應用
    try:
        from app import app
        app.run(debug=False, host='0.0.0.0', port=5000)
    except Exception as e:
        print(f"✗ 服務器啟動失敗：{e}")
        print("請檢查端口 5000 是否被佔用")

if __name__ == '__main__':
    main()
