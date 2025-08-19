document.addEventListener('DOMContentLoaded', () => {
    // --- DOM 元素獲取 ---
    const startScreen = document.getElementById('start-screen');
    const gameScreen = document.getElementById('game-screen');
    const endScreen = document.getElementById('end-screen');
    const trainContainer = document.getElementById('train-container'); // 捷運列車動畫容器

    const startGameBtn = document.getElementById('start-game-btn');
    const restartBtn = document.getElementById('restart-btn');
    const reviewBtn = document.getElementById('review-wrong-answers-btn');
    const leaderboardBtn = document.getElementById('show-leaderboard-btn');

    const questionCounter = document.getElementById('question-counter');
    const scoreDisplay = document.getElementById('score-display');
    const timerBar = document.getElementById('timer-bar');
    const questionText = document.getElementById('question-text');
    const optionsContainer = document.getElementById('options-container');
    const feedbackDisplay = document.getElementById('feedback-display');
    const finalScore = document.getElementById('final-score');
    const comboDisplay = document.getElementById('combo-display'); // 連擊顯示

    // 新增：分數彈出動畫和結束稱號的 DOM 元素
    const scorePopup = document.getElementById('score-popup'); 
    const endScreenTitle = document.getElementById('end-screen-title'); 

    // 音效元素
    const backgroundMusic = document.getElementById('background-music');
    const gameStartSound = document.getElementById('game-start-sound'); // 根據 HTML 中的 ID 修正
    const correctSound = document.getElementById('correct-sound');
    const incorrectSound = document.getElementById('incorrect-sound');

    const reviewModal = document.getElementById('review-modal');
    const closeReviewBtn = document.getElementById('close-review-modal-btn');
    const wrongAnswersList = document.getElementById('wrong-answers-list');

    const leaderboardModal = document.getElementById('leaderboard-modal');
    const closeLeaderboardBtn = document.getElementById('close-leaderboard-modal-btn');
    const leaderboardList = document.getElementById('leaderboard-list');

    // --- 遊戲狀態變數 ---
    let state = {
        totalQuestions: 0,
        currentQuestionNum: 0,
        score: 0,
        combo: 0,
        currentQuestionDetails: null // 儲存當前問題的詳細資訊，包括正確答案
    };
    let timerInterval;
    const TIME_LIMIT = 10; // 每題作答時間（秒）
    let isAnswering = false; // 防止重複點擊答案

    // --- 瀏覽器自動播放限制處理與音訊初始化 ---
    // 追蹤音訊是否已由使用者互動解鎖
    let audioUnlocked = false;

    // 建立一個「音訊內容解鎖」函數
    function unlockAudioContext() {
        if (audioUnlocked) return; // 如果已經解鎖，就不用再執行
        
        // 嘗試播放一個非常短的無聲片段來「喚醒」瀏覽器的音訊功能
        if (backgroundMusic) {
            const promise = backgroundMusic.play();
            if (promise !== undefined) {
                promise.then(_ => {
                    backgroundMusic.pause(); // 喚醒後立刻暫停，等待我們真正需要時再播放
                    backgroundMusic.currentTime = 0;
                    console.log("音訊已由使用者互動解鎖！");
                    audioUnlocked = true;
                }).catch(error => {
                    console.error("音訊解鎖失敗:", error);
                });
            }
        }
    }
    
    // 監聽整個頁面的第一次點擊事件，用來解鎖音訊
    document.body.addEventListener('click', unlockAudioContext, { once: true });

    // 頁面載入後，就讓背景音樂準備好並嘗試播放
    function startInitialMusic() {
        if (backgroundMusic) {
            backgroundMusic.volume = 0.2; // 調整背景音樂音量為 20%
            backgroundMusic.play().catch(e => {
                console.log("瀏覽器阻擋了初始自動播放。等待使用者點擊...");
            });
        }
        // 確保答題音效音量為 100%
        if (correctSound) correctSound.volume = 1.0;
        if (incorrectSound) incorrectSound.volume = 1.0;
        if (gameStartSound) gameStartSound.volume = 1.0;
    }
    startInitialMusic(); // 載入時就嘗試播放

    // --- 輔助函數 ---

    // API 呼叫通用函數
    async function apiCall(endpoint, options = {}) {
        try {
            const response = await fetch(endpoint, options);
            if (!response.ok) {
                const errorData = await response.json().catch(() => ({ error: 'Server response format error' }));
                throw new Error(`HTTP error! status: ${response.status}, message: ${errorData.error}`);
            }
            return await response.json();
        } catch (error) {
            console.error(`API call to ${endpoint} failed:`, error);
            feedbackDisplay.textContent = '連線錯誤，請稍後再試。';
            feedbackDisplay.className = 'text-center font-bold text-2xl mt-6 min-h-[40px] text-red-500';
            // 可以考慮在錯誤時自動回到開始畫面或顯示錯誤訊息
            setTimeout(() => {
                switchScreen('start');
                feedbackDisplay.textContent = ''; // 清除錯誤訊息
            }, 3000);
            return null;
        }
    }

    // 遊戲開始邏輯
    async function startGame() {
        // 預設為 'normal' 模式，因為 HTML 中沒有模式選擇按鈕
        const data = await apiCall('/api/start_game', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ mode: 'normal' }) // 預設為一般模式
        });

        if (!data) return; // API 呼叫失敗則返回

        state = {
            totalQuestions: data.total_questions,
            currentQuestionNum: 1, // 從第一題開始
            score: 0,
            combo: 0,
            currentQuestionDetails: data.question // 儲存第一題的詳細資訊
        };

        updateScore(state.score); // 更新分數顯示
        switchScreen('game'); // 切換到遊戲畫面
        displayQuestion(state.currentQuestionDetails); // 顯示第一題

        // 播放遊戲開始音效並暫停背景音樂
        if (gameStartSound) {
            gameStartSound.play().catch(e => console.error("遊戲開始音效播放失敗:", e));
        }
        if (backgroundMusic) {
            backgroundMusic.pause();
            backgroundMusic.currentTime = 0; // 重置背景音樂到開頭
        }
    }

    // 顯示問題
    function displayQuestion(question) {
        state.currentQuestionDetails = question; // 更新當前問題詳情
        isAnswering = false; // 允許玩家再次作答
        clearFeedback(); // 清除上一題的回饋訊息
        
        // 在顯示新問題時，確保列車動畫是顯示的
        if (trainContainer) {
            trainContainer.style.display = 'block';
        }

        // 更新題號和問題文字
        questionCounter.textContent = `第 ${state.currentQuestionNum} / ${state.totalQuestions} 題`;
        questionText.textContent = question.text;

        // 清空舊選項並生成新選項
        optionsContainer.innerHTML = '';
        question.options.forEach(option => {
            const button = document.createElement('button');
            button.textContent = option;
            button.className = 'p-4 rounded-xl font-bold text-lg option-btn w-full';
            button.onclick = () => handleAnswer(option, button);
            optionsContainer.appendChild(button);
        });

        startTimer(); // 啟動計時器
    }

    // 處理玩家答案
    async function handleAnswer(selectedAnswer, clickedButton) {
        if (isAnswering) return; // 防止重複點擊
        isAnswering = true; // 設為正在處理答案

        clearInterval(timerInterval); // 停止計時器
        timerBar.style.width = '0%'; // 重置計時條
        timerBar.style.background = 'linear-gradient(90deg, #22c55e, #a3e635)'; // 重置計時條顏色

        disableOptions(); // 禁用所有選項按鈕
        
        // 無論答對或答錯，在提交答案後立即隱藏列車動畫
        if (trainContainer) {
            trainContainer.style.display = 'none';
        }

        const scoreBefore = state.score; // 記錄答題前的分數
        const result = await apiCall('/api/submit_answer', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ answer: selectedAnswer })
        });

        if (!result) {
            // API 呼叫失敗已在 apiCall 內部處理，這裡直接返回
            return;
        }

        const scoreAfter = result.score;
        const pointsEarned = scoreAfter - scoreBefore; // 計算本次得分
        if (pointsEarned > 0) {
            showScorePopup(`+${pointsEarned}`); // 顯示分數彈出動畫
        }

        updateScore(result.score); // 更新分數顯示
        updateCombo(result.combo); // 更新連擊顯示
        showFeedback(result, clickedButton); // 顯示答題回饋

        // 延遲 2 秒後進入下一題或結束遊戲
        setTimeout(() => {
            if (result.game_over) {
                endGame();
            } else {
                state.currentQuestionNum++; // 題號遞增
                displayQuestion(result.next_question); // 顯示下一題
            }
        }, 2000); // 2秒延遲
    }

    // 遊戲結束邏輯
    function endGame() {
        finalScore.textContent = state.score;
        setEndGameTitle(state.score); // 根據分數設定結束稱號
        switchScreen('end'); // 切換到結束畫面

        // 遊戲結束時重新播放背景音樂
        if (backgroundMusic) {
            backgroundMusic.currentTime = 0; // 將音樂倒回開頭再播放
            backgroundMusic.play().catch(e => console.error("結束時背景音樂播放失敗:", e));
        }
    }

    // 畫面切換函數
    function switchScreen(screen) {
        startScreen.classList.add('hidden');
        gameScreen.classList.add('hidden');
        endScreen.classList.add('hidden');
        trainContainer.classList.add('hidden'); // 預設隱藏火車動畫

        const activeScreen = document.getElementById(`${screen}-screen`);
        activeScreen.classList.remove('hidden', 'animate-fadeIn');
        void activeScreen.offsetWidth; // 觸發重繪以重新應用動畫
        activeScreen.classList.add('animate-fadeIn');

        // 遊戲中或結束畫面顯示火車動畫 (此處邏輯已由 displayQuestion 和 handleAnswer 接管)
        // if (screen === 'game' || screen === 'end') { 
        //     trainContainer.classList.remove('hidden');
        // }
    }

    // 更新分數顯示
    function updateScore(newScore) {
        state.score = newScore;
        scoreDisplay.textContent = `分數: ${newScore}`;
    }

    // 顯示答題回饋
    function showFeedback(result, clickedButton) {
        feedbackDisplay.textContent = result.feedback;
        if (result.is_correct) {
            if (clickedButton) clickedButton.classList.add('correct'); // 玩家點擊的按鈕
            feedbackDisplay.className = 'text-center font-bold text-2xl mt-6 min-h-[40px] text-green-500';
            correctSound.play().catch(e => console.error("正確音效播放失敗:", e)); // 播放正確音效
        } else {
            if (clickedButton) clickedButton.classList.add('incorrect'); // 玩家點擊的按鈕
            feedbackDisplay.className = 'text-center font-bold text-2xl mt-6 min-h-[40px] text-red-500';
            // 標示正確答案
            Array.from(optionsContainer.children).forEach(btn => {
                if (btn.textContent === result.correct_answer) {
                    btn.classList.add('correct'); // 正確答案按鈕標示綠色
                }
            });
            incorrectSound.play().catch(e => console.error("錯誤音效播放失敗:", e)); // 播放錯誤音效
        }
    }

    // 清除回饋訊息和按鈕樣式
    function clearFeedback() {
        feedbackDisplay.textContent = '';
        feedbackDisplay.className = 'text-center font-bold text-2xl mt-6 min-h-[40px]';
        Array.from(optionsContainer.children).forEach(btn => {
            btn.classList.remove('correct', 'incorrect');
            btn.disabled = false; // 啟用所有按鈕
        });
    }

    // 禁用所有選項按鈕
    function disableOptions() {
        Array.from(optionsContainer.children).forEach(btn => btn.disabled = true);
    }

    // 更新連擊顯示
    function updateCombo(comboCount) {
        if (comboCount > 1) {
            comboDisplay.textContent = `🔥 x${comboCount}`;
            comboDisplay.classList.add('show');
            setTimeout(() => {
                comboDisplay.classList.remove('show');
            }, 1000); // 1秒後隱藏連擊顯示
        } else {
            comboDisplay.classList.remove('show'); // 如果連擊歸零，確保隱藏
        }
    }

    // 啟動計時器
    function startTimer() {
        clearInterval(timerInterval);
        let timeLeft = TIME_LIMIT;
        timerBar.style.width = '100%'; // 初始寬度設為100%

        timerInterval = setInterval(() => {
            timeLeft -= 0.1; // 每0.1秒更新一次，使動畫更流暢
            const percent = (timeLeft / TIME_LIMIT) * 100;
            timerBar.style.width = `${Math.max(0, percent)}%`; // 確保不小於0

            // 根據剩餘時間改變計時條顏色
            if (timeLeft <= 3) {
                timerBar.style.background = 'linear-gradient(90deg, #ef4444, #f87171)'; // 紅色
            } else if (timeLeft <= 6) {
                timerBar.style.background = 'linear-gradient(90deg, #f59e0b, #fcd34d)'; // 黃色
            } else {
                timerBar.style.background = 'linear-gradient(90deg, #22c55e, #a3e635)'; // 綠色
            }

            if (timeLeft <= 0) {
                clearInterval(timerInterval);
                handleAnswer(null, null); // 時間到，提交空答案（表示未作答）
            }
        }, 100); // 每100毫秒更新
    }

    // 顯示分數彈出動畫
    function showScorePopup(text) {
        if (scorePopup) {
            scorePopup.textContent = text;
            scorePopup.style.animation = 'none';
            void scorePopup.offsetWidth; // 強制瀏覽器重繪
            scorePopup.style.animation = 'fade-up-out 1.5s ease-out';
        }
    }

    // 根據分數設定結束稱號 (已調整分數門檻)
    function setEndGameTitle(score) {
        let title = "再接再厲！"; // 預設稱號
        if (score >= 4500) {
            title = "捷運天王！";
        } else if (score >= 3000) {
            title = "捷運達人";
        } else if (score >= 1500) {
            title = "捷運熟手";
        } else if (score > 0) { // 只要有分數就至少是菜鳥
            title = "捷運菜鳥";
        }
        if (endScreenTitle) {
            endScreenTitle.textContent = title;
        }
    }

    // 顯示錯題回顧模態視窗
    async function showReviewModal() {
        wrongAnswersList.innerHTML = '<p class="text-center text-gray-500">正在載入錯題紀錄...</p>';
        reviewModal.style.display = 'flex';
        const wrongAnswers = await apiCall('/api/get_wrong_answers');
        if (!wrongAnswers) {
            wrongAnswersList.innerHTML = '<p class="text-center text-red-500">無法載入錯題紀錄，請稍後再試。</p>';
            return;
        }
        wrongAnswersList.innerHTML = '';
        if (wrongAnswers.length > 0) {
            wrongAnswers.forEach((item, index) => {
                const div = document.createElement('div');
                div.className = 'p-4 bg-red-50 rounded-lg border-l-4 border-red-500';
                div.innerHTML = `
                    <p class="font-bold text-gray-800">${index + 1}. ${item.question}</p>
                    <p class="text-green-700 mt-2"><b><span class="bg-green-200 px-2 py-1 rounded">正確答案</span></b> ${item.correct_answer}</p>
                    <p class="text-gray-600 mt-2"><b><span class="bg-gray-200 px-2 py-1 rounded">詳解</span></b> ${item.explanation || '暫無詳解'}</p>
                `;
                wrongAnswersList.appendChild(div);
            });
        } else {
            wrongAnswersList.innerHTML = '<p class="text-center text-gray-500">太棒了！您沒有答錯任何題目！</p>';
        }
    }

    // 顯示排行榜模態視窗
    async function showLeaderboardModal() {
        leaderboardList.innerHTML = '<li class="text-center text-gray-500">正在載入排行榜...</li>';
        leaderboardModal.style.display = 'flex';
        const leaders = await apiCall('/api/get_leaderboard');
        if (!leaders) {
            leaderboardList.innerHTML = '<li class="text-center text-red-500">無法載入排行榜，請稍後再試。</li>';
            return;
        }
        leaderboardList.innerHTML = '';
        if (leaders.length > 0) {
            leaders.forEach((entry, index) => {
                const li = document.createElement('li');
                li.className = `flex justify-between items-center p-3 rounded-lg ${index < 3 ? 'bg-amber-100' : 'bg-gray-100'}`;
                li.innerHTML = `
                    <span class="font-bold text-lg w-10 ${index + 1}.</span>
                    <span class="text-gray-800 font-medium flex-grow">${entry.name}</span>
                    <span class="font-bold text-violet-600">${entry.score} 分</span>
                `;
                leaderboardList.appendChild(li);
            });
        } else {
            leaderboardList.innerHTML = '<li class="text-center text-gray-500">目前還沒有人上榜，快來挑戰吧！</li>';
        }
    }

    // --- 事件監聽器 ---
    startGameBtn.addEventListener('click', startGame);
    restartBtn.addEventListener('click', () => location.reload()); // 重新載入頁面以重新開始遊戲
    reviewBtn.addEventListener('click', showReviewModal);
    closeReviewBtn.addEventListener('click', () => reviewModal.style.display = 'none');
    leaderboardBtn.addEventListener('click', showLeaderboardModal);
    closeLeaderboardBtn.addEventListener('click', () => leaderboardModal.style.display = 'none');

    // 點擊模態視窗外部關閉
    reviewModal.addEventListener('click', (e) => {
        if (e.target === reviewModal) reviewModal.style.display = 'none';
    });
    leaderboardModal.addEventListener('click', (e) => {
        if (e.target === leaderboardModal) leaderboardModal.style.display = 'none';
    });
});