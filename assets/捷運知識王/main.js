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
    }

    // 顯示問題
    function displayQuestion(question) {
        state.currentQuestionDetails = question; // 更新當前問題詳情
        isAnswering = false; // 允許玩家再次作答
        clearFeedback(); // 清除上一題的回饋訊息
        
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

        const result = await apiCall('/api/submit_answer', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ answer: selectedAnswer })
        });

        if (!result) {
            // API 呼叫失敗已在 apiCall 內部處理，這裡直接返回
            return;
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
        switchScreen('end'); // 切換到結束畫面
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

        // 遊戲中或結束畫面顯示火車動畫
        if (screen === 'game' || screen === 'end') {
            trainContainer.classList.remove('hidden');
        }
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
            correctSound.play();
        } else {
            if (clickedButton) clickedButton.classList.add('incorrect'); // 玩家點擊的按鈕
            feedbackDisplay.className = 'text-center font-bold text-2xl mt-6 min-h-[40px] text-red-500';
            // 標示正確答案
            Array.from(optionsContainer.children).forEach(btn => {
                if (btn.textContent === result.correct_answer) {
                    btn.classList.add('correct'); // 正確答案按鈕標示綠色
                }
            });
            incorrectSound.play();
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
                    <span class="font-bold text-lg w-10 ${index < 3 ? 'text-amber-500' : 'text-gray-600'}">#${index + 1}</span>
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
