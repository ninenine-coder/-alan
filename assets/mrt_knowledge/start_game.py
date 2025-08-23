#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
捷運知識王遊戲啟動腳本
"""

import os
import sys
import subprocess
import webbrowser
import time
from pathlib import Path

def check_python_version():
    """檢查 Python 版本"""
    if sys.version_info < (3, 7):
        print("錯誤：需要 Python 3.7 或更高版本")
        return False
    print(f"Python 版本：{sys.version}")
    return True

def install_requirements():
    """安裝必要的依賴"""
    requirements = [
        'flask',
        'sqlite3'  # 通常已包含在 Python 中
    ]
    
    print("檢查並安裝必要的依賴...")
    for package in requirements:
        if package == 'sqlite3':
            try:
                import sqlite3
                print("✓ sqlite3 已可用")
            except ImportError:
                print("✗ sqlite3 不可用")
                return False
        else:
            try:
                __import__(package)
                print(f"✓ {package} 已安裝")
            except ImportError:
                print(f"安裝 {package}...")
                try:
                    subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])
                    print(f"✓ {package} 安裝成功")
                except subprocess.CalledProcessError:
                    print(f"✗ {package} 安裝失敗")
                    return False
    return True

def initialize_database():
    """初始化數據庫"""
    print("初始化數據庫...")
    try:
        import data_init
        data_init.main()
        print("✓ 數據庫初始化成功")
        return True
    except Exception as e:
        print(f"✗ 數據庫初始化失敗：{e}")
        return False

def start_server():
    """啟動 Flask 服務器"""
    print("啟動捷運知識王遊戲服務器...")
    
    # 獲取當前腳本目錄
    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)
    
    # 啟動 Flask 應用
    try:
        from app import app
        print("✓ 服務器啟動成功！")
        print("遊戲地址：http://localhost:5000")
        print("按 Ctrl+C 停止服務器")
        
        # 自動打開瀏覽器
        time.sleep(2)
        webbrowser.open('http://localhost:5000')
        
        # 運行 Flask 應用
        app.run(debug=False, host='0.0.0.0', port=5000)
        
    except Exception as e:
        print(f"✗ 服務器啟動失敗：{e}")
        return False

def main():
    """主函數"""
    print("=" * 50)
    print("🚇 捷運知識王遊戲啟動器")
    print("=" * 50)
    
    # 檢查 Python 版本
    if not check_python_version():
        return
    
    # 安裝依賴
    if not install_requirements():
        print("依賴安裝失敗，請手動安裝必要的包")
        return
    
    # 初始化數據庫
    if not initialize_database():
        print("數據庫初始化失敗")
        return
    
    # 啟動服務器
    start_server()

if __name__ == '__main__':
    main()
