# -*- coding: utf-8 -*-
# app.py
# 負責遊戲邏輯與資料庫互動的優化後端伺服器。

from flask import Flask, jsonify, request, session, g, send_from_directory
import sqlite3
import random
import os
import time

# 專案根目錄
root_dir = os.path.dirname(os.path.abspath(__file__))
# 資料庫檔案路徑
DATABASE = os.path.join(root_dir, 'taipei_metro_quiz.db') # 更改資料庫名稱以避免衝突

# Flask App 初始化
app = Flask(__name__, static_folder=root_dir, static_url_path='')
app.secret_key = 'super_secret_key_for_awesome_mrt_quiz' # 請務必替換為更複雜的密鑰

# 遊戲設定 (可調整)
TOTAL_QUESTIONS_PER_GAME = 10 # 每局遊戲的題目數量
TIME_LIMIT_PER_QUESTION = 10 # 每題作答時間（秒）
FAST_ANSWER_BONUS_THRESHOLD = 5 # 在此時間內答對可獲得加倍分數（秒）

# 確保資料庫在啟動時存在並已初始化
if not os.path.exists(DATABASE):
    print("資料庫檔案不存在，正在執行 data_init.py 來建立...")
    try:
        import data_init
        # 設定 data_init 使用的資料庫路徑
        data_init.DATABASE = DATABASE
        data_init.main()
        print("資料庫初始化完成！")
    except ImportError:
        print("錯誤：找不到 data_init.py，請確保它存在於專案目錄中。")
    except Exception as e:
        print(f"初始化資料庫時發生錯誤：{e}")

def get_db():
    """建立或獲取資料庫連線"""
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE)
        db.row_factory = sqlite3.Row # 讓查詢結果以字典形式返回
    return db

@app.teardown_appcontext
def close_connection(exception):
    """應用程式關閉時自動關閉資料庫連線"""
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

@app.route('/')
def index():
    """提供前端網頁"""
    return send_from_directory(app.static_folder, 'index.html')

def get_question_details(question_id):
    """根據問題 ID 獲取問題詳情及其選項"""
    db = get_db()
    question = db.execute('SELECT question_id, question_text, correct_option_text, difficulty, explanation FROM Questions WHERE question_id = ?', (question_id,)).fetchone()
    if not question:
        return None
    
    # 獲取選項並隨機排序
    options = db.execute('SELECT option_text FROM Options WHERE question_id = ?', (question_id,)).fetchall()
    option_texts = [opt['option_text'] for opt in options]
    random.shuffle(option_texts) # 確保選項每次出現順序不同

    return {
        "id": question['question_id'],
        "text": question['question_text'],
        "difficulty": question['difficulty'],
        "options": option_texts, # 傳回隨機排序後的選項
        "correct_option": question['correct_option_text'],
        "explanation": question['explanation']
    }

@app.route('/api/start_game', methods=['POST'])
def start_game():
    """開始一個新遊戲，根據模式選擇題目數量"""
    mode = request.json.get('mode', 'normal')
    # 根據模式設定題目數量
    if mode == 'time_attack':
        num_questions_for_game = 20
    else: # normal mode
        num_questions_for_game = 10
    
    db = get_db()
    all_question_ids = [row['question_id'] for row in db.execute('SELECT question_id FROM Questions').fetchall()]
    
    # 從所有題目中隨機抽取指定數量，確保不重複
    if len(all_question_ids) < num_questions_for_game:
        return jsonify({"error": "題庫題目不足，無法開始遊戲！"}), 500
        
    question_ids = random.sample(all_question_ids, num_questions_for_game)
    
    # 將遊戲狀態儲存到 session
    session['question_ids'] = question_ids
    session['current_question_index'] = 0
    session['score'] = 0
    session['combo'] = 0
    session['wrong_answers'] = [] # 用於記錄答錯的題目，方便遊戲結束後回顧
    session['mode'] = mode
    
    first_question = get_question_details(question_ids[0])
    session['question_start_time'] = time.time() # 記錄第一題的開始時間

    return jsonify({
        "total_questions": len(question_ids),
        "question": first_question
    })

@app.route('/api/submit_answer', methods=['POST'])
def submit_answer():
    """提交答案並獲取下一題，實作多樣化計分機制"""
    data = request.json
    selected_option = data.get('answer') # 玩家選擇的答案文本
    
    question_ids = session.get('question_ids', [])
    current_idx = session.get('current_question_index', 0)

    # 檢查是否已無題目或索引超出範圍
    if current_idx >= len(question_ids):
        return jsonify({"game_over": True, "score": session.get('score', 0)})

    current_question_id = question_ids[current_idx]
    question_details = get_question_details(current_question_id)
    
    start_time = session.get('question_start_time', 0)
    time_taken = time.time() - start_time
    
    is_correct = False
    feedback_text = ""
    points_earned = 0
    
    # 判斷是否逾時
    if time_taken > TIME_LIMIT_PER_QUESTION:
        feedback_text = "時間到！答題逾時了。"
        session['combo'] = 0 # 逾時也重置連擊
    elif selected_option == question_details['correct_option']:
        is_correct = True
        session['combo'] = session.get('combo', 0) + 1 # 連擊數增加
        
        # 根據難度設定基礎分數
        base_points = {'簡單': 100, '中等': 150, '困難': 200}.get(question_details['difficulty'], 100)
        
        # 限時獎勵：在指定時間內答對，分數加倍
        time_bonus = base_points if time_taken <= FAST_ANSWER_BONUS_THRESHOLD else 0
        
        # 連擊獎勵：連擊數越高，額外分數越多
        combo_bonus = (session['combo'] - 1) * 50 # 例如：連擊1次獎勵0，連擊2次獎勵50，連擊3次獎勵100
        
        points_earned = base_points + time_bonus + combo_bonus
        session['score'] = session.get('score', 0) + points_earned
        
        feedback_text = f"答對了！ +{points_earned}分"
        if session['combo'] > 1:
            feedback_text += f" 🔥 連擊 x{session['combo']}！"
    else:
        feedback_text = "答錯了，再接再厲！"
        session['combo'] = 0 # 答錯重置連擊
        # 記錄答錯的題目資訊
        session['wrong_answers'].append({
            "question": question_details['text'],
            "selected_answer": selected_option,
            "correct_answer": question_details['correct_option'],
            "explanation": question_details['explanation']
        })

    # 更新當前題目索引
    session['current_question_index'] += 1
    next_idx = session.get('current_question_index')
    
    game_over = next_idx >= len(question_ids)
    next_question = None

    if not game_over:
        next_question = get_question_details(question_ids[next_idx])
        session['question_start_time'] = time.time() # 更新下一題的開始時間
    else:
        # 遊戲結束時，將最終分數存入排行榜
        db = get_db()
        player_name = f"玩家_{random.randint(1000, 9999)}" # 匿名玩家名稱
        db.execute('INSERT INTO Leaderboard (name, score) VALUES (?, ?)', (player_name, session.get('score', 0)))
        db.commit()

    return jsonify({
        "is_correct": is_correct,
        "feedback": feedback_text,
        "correct_answer": question_details['correct_option'],
        "score": session.get('score', 0),
        "combo": session.get('combo', 0),
        "game_over": game_over,
        "next_question": next_question,
        "points_earned": points_earned # 回傳本次答題獲得的分數
    })

@app.route('/api/get_wrong_answers', methods=['GET'])
def get_wrong_answers():
    """獲取遊戲結束後答錯的題目列表"""
    return jsonify(session.get('wrong_answers', []))

@app.route('/api/get_leaderboard', methods=['GET'])
def get_leaderboard():
    """獲取排行榜資料"""
    db = get_db()
    # 按照分數降序排列，只取前 10 名
    leaderboard = db.execute('SELECT name, score FROM Leaderboard ORDER BY score DESC LIMIT 10').fetchall()
    return jsonify([dict(row) for row in leaderboard]) # 將結果轉換為字典列表

if __name__ == '__main__':
    # 在本機測試時，啟動時即運行 data_init 確保資料庫存在
    app.run(debug=True, port=5000)

