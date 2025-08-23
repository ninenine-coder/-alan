# 🚇 捷運知識王遊戲安裝指南

## 📋 系統要求

- Windows 10 或更高版本
- Python 3.7 或更高版本
- 現代瀏覽器（Chrome、Firefox、Edge）

## 🔧 安裝步驟

### 第一步：安裝 Python

1. **下載 Python**：
   - 訪問 [Python 官網](https://www.python.org/downloads/)
   - 下載最新版本的 Python（建議 3.8 或更高版本）

2. **安裝 Python**：
   - 運行下載的安裝程序
   - **重要**：勾選 "Add Python to PATH" 選項
   - 選擇 "Install Now" 進行安裝

3. **驗證安裝**：
   - 打開命令提示字元（cmd）
   - 輸入：`python --version`
   - 應該顯示 Python 版本號

### 第二步：安裝 Flask

1. **打開命令提示字元**：
   - 按 `Win + R`，輸入 `cmd`，按 Enter

2. **安裝 Flask**：
   ```cmd
   pip install flask
   ```

3. **驗證安裝**：
   ```cmd
   pip show flask
   ```

### 第三步：啟動遊戲

#### 方法一：使用批處理文件（推薦）

1. 雙擊 `start_game.bat` 文件
2. 等待遊戲啟動
3. 瀏覽器會自動打開遊戲頁面

#### 方法二：手動啟動

1. 打開命令提示字元
2. 切換到遊戲目錄：
   ```cmd
   cd "C:\Users\User\-alan\assets\捷運知識王\捷運知識王"
   ```
3. 運行遊戲：
   ```cmd
   python app.py
   ```
4. 在瀏覽器中訪問：`http://localhost:5000`

## 🐛 常見問題

### 問題：'python' 不是內部或外部命令
**解決方案**：
1. 重新安裝 Python，確保勾選 "Add Python to PATH"
2. 或者手動添加 Python 到系統 PATH

### 問題：'pip' 不是內部或外部命令
**解決方案**：
1. 確保 Python 已正確安裝
2. 嘗試使用：`python -m pip install flask`

### 問題：端口 5000 被佔用
**解決方案**：
1. 關閉其他可能使用端口 5000 的程序
2. 或者修改 `app.py` 中的端口號

### 問題：無法訪問遊戲頁面
**解決方案**：
1. 確保服務器已啟動
2. 嘗試訪問：`http://127.0.0.1:5000`
3. 檢查防火牆設置

## 📞 技術支援

如果遇到其他問題：

1. **檢查 Python 安裝**：
   ```cmd
   python --version
   pip --version
   ```

2. **檢查 Flask 安裝**：
   ```cmd
   pip list | findstr flask
   ```

3. **重新安裝依賴**：
   ```cmd
   pip uninstall flask
   pip install flask
   ```

## 🎮 遊戲特色

- 🎯 多種難度等級
- ⏱️ 計時挑戰模式
- 🔥 連擊獎勵系統
- 🏆 排行榜功能
- 📚 詳細題目解析

## 🎉 開始遊戲

完成安裝後，你就可以開始享受捷運知識王遊戲了！

挑戰你的朋友，看看誰是真正的捷運知識王！
