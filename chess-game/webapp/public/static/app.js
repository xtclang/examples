// ===== DOM References =====
const boardEl = document.getElementById('board');
const turnEl = document.getElementById('turn');
const statusEl = document.getElementById('status');
const selectionEl = document.getElementById('selection');
const logEl = document.getElementById('log');
const playerScoreEl = document.getElementById('playerScore');
const opponentScoreEl = document.getElementById('opponentScore');
const resetBtn = document.getElementById('reset');
const refreshBtn = document.getElementById('refresh');
const toastContainer = document.getElementById('toastContainer');

// Inline scores
const playerScoreInline = document.getElementById('playerScoreInline');
const opponentScoreInline = document.getElementById('opponentScoreInline');
const playerScoreInlineMulti = document.getElementById('playerScoreInlineMulti');
const opponentScoreInlineMulti = document.getElementById('opponentScoreInlineMulti');

// Mode tabs
const singlePlayerBtn = document.getElementById('singlePlayerBtn');
const multiplayerBtn = document.getElementById('multiplayerBtn');

// Online panel elements
const onlinePanel = document.getElementById('onlinePanel');
const closeOnlinePanel = document.getElementById('closeOnlinePanel');
const lobbyOptions = document.getElementById('lobbyOptions');
const roomInfo = document.getElementById('roomInfo');
const createRoomBtn = document.getElementById('createRoomBtn');
const joinRoomBtn = document.getElementById('joinRoomBtn');
const roomCodeInput = document.getElementById('roomCodeInput');
const roomCodeDisplay = document.getElementById('roomCodeDisplay');
const playerColorDisplay = document.getElementById('playerColorDisplay');
const leaveRoomBtn = document.getElementById('leaveRoom');
const mpStatusPill = document.getElementById('mpStatusPill');

// Chat panel elements
const chatPanel = document.getElementById('chatPanel');
const closeChatPanel = document.getElementById('closeChatPanel');
const chatMessages = document.getElementById('chatMessages');
const chatInput = document.getElementById('chatInput');
const chatSendBtn = document.getElementById('chatSendBtn');
const chatBadge = document.getElementById('chatBadge');
const chatToggleBtn = document.getElementById('chatToggleBtn');

// Move history panel elements
const moveHistoryPanel = document.getElementById('moveHistoryPanel');
const closeMoveHistoryPanel = document.getElementById('closeMoveHistoryPanel');
const moveHistoryContainer = document.getElementById('moveHistoryContainer');
const moveHistoryToggleBtn = document.getElementById('moveHistoryToggleBtn');

// Info popover
const infoToggle = document.getElementById('infoToggle');
const infoPopover = document.getElementById('infoPopover');

// Time control elements
const timeControlBar = document.getElementById('timeControlBar');
const whiteTimerEl = document.getElementById('whiteTimer');
const blackTimerEl = document.getElementById('blackTimer');
const whiteTimeEl = document.getElementById('whiteTime');
const blackTimeEl = document.getElementById('blackTime');

// Time control modal elements
const timeControlModal = document.getElementById('timeControlModal');
const closeTimeControlModal = document.getElementById('closeTimeControlModal');
const timeControlOptions = document.querySelectorAll('.time-control-option');
const startWithTimeControl = document.getElementById('startWithTimeControl');
const onlineTimeControl = document.getElementById('onlineTimeControl');

// Backdrop
const backdrop = document.getElementById('backdrop');

// Game End Modal elements
const gameEndModal = document.getElementById('gameEndModal');
const gameEndTitle = document.getElementById('gameEndTitle');
const gameEndIcon = document.getElementById('gameEndIcon');
const gameEndMessage = document.getElementById('gameEndMessage');
const finalWhiteScore = document.getElementById('finalWhiteScore');
const finalBlackScore = document.getElementById('finalBlackScore');
const playAgainBtn = document.getElementById('playAgainBtn');
const closeGameEndModal = document.getElementById('closeGameEndModal');

// ===== Piece Map =====
const pieceMap = {
  r: '♜', n: '♞', b: '♝', q: '♛', k: '♚', p: '♟',
  R: '♖', N: '♘', B: '♗', Q: '♕', K: '♔', P: '♙',
  '.': ''
};

// ===== State =====
let selection = null;
let cachedBoard = [];
let opponentRefresh = null;
let lastMove = null;
let hasInitializedState = false;
let activeValidMoves = [];
let validMoveTimer = null;

let gameMode = 'single';
let roomCode = null;
let playerId = null;
let playerColor = null;
let isInRoom = false;

let lastChatTimestamp = 0;
let chatPollInterval = null;
let unreadChatCount = 0;

// Single player session ID (for browser isolation)
let singlePlayerSessionId = null;

// Time control state
let timeControl = null;
let clockInterval = null;
let currentTurn = 'White';
let previousTurn = null; // Track previous turn to detect turn changes
let selectedTimeControlMs = 600000; // Default: 10 min (Rapid)
let selectedIncrementMs = 0;

// Move history state
let moveHistory = [];

// ===== Utility Functions =====
function pushToast(message, variant = 'accent') {
  if (!toastContainer) return;
  const toast = document.createElement('div');
  toast.className = `toast ${variant}`;
  toast.textContent = message;
  toastContainer.appendChild(toast);
  requestAnimationFrame(() => toast.classList.add('show'));
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}

function algebraic(row, col) {
  const file = String.fromCodePoint('a'.codePointAt(0) + col);
  const rank = 8 - row;
  return `${file}${rank}`;
}

function setMessage(text) {
  if (logEl) logEl.textContent = text;
}

function saveSession() {
  if (gameMode === 'multi' && roomCode && playerId) {
    localStorage.setItem('chess_session', JSON.stringify({ roomCode, playerId, playerColor }));
  } else {
    localStorage.removeItem('chess_session');
  }
}

function generateSessionId() {
  return 'sp_' + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
}

function getSinglePlayerSessionId() {
  if (!singlePlayerSessionId) {
    // Try to get from sessionStorage (browser tab specific)
    singlePlayerSessionId = sessionStorage.getItem('chess_single_player_id');
    if (!singlePlayerSessionId) {
      singlePlayerSessionId = generateSessionId();
      sessionStorage.setItem('chess_single_player_id', singlePlayerSessionId);
    }
  }
  return singlePlayerSessionId;
}

function loadSession() {
  try {
    const session = JSON.parse(localStorage.getItem('chess_session'));
    if (session?.roomCode && session?.playerId) {
      return session;
    }
  } catch {
    localStorage.removeItem('chess_session');
  }
  return null;
}

// ===== Valid Moves Management =====
function clearActiveValidMoves(skipRender = false) {
  if (validMoveTimer) {
    clearTimeout(validMoveTimer);
    validMoveTimer = null;
  }
  activeValidMoves = [];
  if (!skipRender && cachedBoard.length) {
    renderBoard(cachedBoard, false);
  }
}

function setActiveValidMoves(moves) {
  clearActiveValidMoves(true);
  if (moves?.length) {
    activeValidMoves = moves;
    validMoveTimer = setTimeout(() => clearActiveValidMoves(), 4500);
  }
  if (cachedBoard.length) {
    renderBoard(cachedBoard, false);
  }
}

// ===== Board Rendering =====
function renderBoard(boardRows, disabled = false, highlightMoves = activeValidMoves) {
  cachedBoard = boardRows;
  boardEl.innerHTML = '';
  boardEl.classList.toggle('disabled', disabled);

  let lastMoveFrom = null;
  let lastMoveTo = null;
  if (lastMove?.length >= 4) {
    lastMoveFrom = lastMove.substring(0, 2);
    lastMoveTo = lastMove.substring(2, 4);
  }

  boardRows.forEach((rowString, rowIdx) => {
    [...rowString].forEach((ch, colIdx) => {
      const btn = document.createElement('button');
      const square = algebraic(rowIdx, colIdx);
      btn.className = `square ${(rowIdx + colIdx) % 2 === 0 ? 'dark' : 'light'}`;
      btn.dataset.square = square;
      btn.textContent = pieceMap[ch] ?? '';

      if (selection === square) btn.classList.add('selected');
      if (lastMoveFrom === square) btn.classList.add('last-move-from');
      if (lastMoveTo === square) btn.classList.add('last-move-to');

      if (highlightMoves?.includes(square)) {
        btn.classList.add(ch === '.' ? 'valid-move' : 'valid-capture');
      }

      if (!disabled) {
        btn.addEventListener('click', () => handleSquareClick(square));
      }

      boardEl.appendChild(btn);
    });
  });
}

// ===== Click Handling =====
async function handleSquareClick(square) {
  if (!selection) {
    selection = square;
    if (selectionEl) selectionEl.textContent = `From ${square}`;
    clearActiveValidMoves(true);
    await loadValidMoves(square);
    return;
  }

  if (selection === square) {
    selection = null;
    if (selectionEl) selectionEl.textContent = 'Pick a piece';
    clearActiveValidMoves();
    renderBoard(cachedBoard, false);
    return;
  }

  const from = selection;
  const to = square;
  selection = null;
  if (selectionEl) selectionEl.textContent = 'Sending move…';
  clearActiveValidMoves(true);

  if (gameMode === 'multi' && isInRoom) {
    sendOnlineMove(from, to);
  } else {
    sendMove(from, to);
  }
}

// ===== API Calls =====
async function sendMove(from, to) {
  try {
    const sessionId = getSinglePlayerSessionId();
    const res = await fetch(`/api/move/${sessionId}/${from}/${to}`, { method: 'POST' });
    const payload = await res.json();
    applyState(payload);
    if (selectionEl) selectionEl.textContent = 'Pick a piece';
  } catch (err) {
    setMessage('Move failed: ' + err.message);
  }
}

async function loadState() {
  setMessage('Syncing with server…');
  try {
    const sessionId = getSinglePlayerSessionId();
    const res = await fetch(`/api/state/${sessionId}`);
    const payload = await res.json();
    applyState(payload);
  } catch (err) {
    console.error('Failed to load state:', err);
    setMessage('Could not reach the chess server.');
  }
}

async function resetGame() {
  setMessage('Resetting…');
  resetGameEndState(); // Reset game end modal state
  try {
    if (gameMode === 'multi' && isInRoom) {
      await resetOnlineGame();
    } else {
      const sessionId = getSinglePlayerSessionId();
      const res = await fetch(`/api/reset/${sessionId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          timeControlMs: selectedTimeControlMs,
          incrementMs: selectedIncrementMs
        })
      });
      const payload = await res.json();
      lastMove = null;
      clearMoveHistory();
      applyState(payload);
    }
  } catch (err) {
    setMessage('Reset failed: ' + err.message);
  }
}

async function loadValidMoves(square) {
  try {
    let url;
    if (gameMode === 'multi' && isInRoom && roomCode && playerId) {
      url = `/api/online/validmoves/${roomCode}/${playerId}/${square}`;
    } else {
      const sessionId = getSinglePlayerSessionId();
      url = `/api/validmoves/${sessionId}/${square}`;
    }
    const res = await fetch(url);
    const data = await res.json();
    if (data.success && data.validMoves) {
      setActiveValidMoves(data.validMoves);
    } else {
      clearActiveValidMoves();
    }
  } catch (err) {
    console.error('Failed to load valid moves:', err);
    clearActiveValidMoves();
  }
}

// ===== State Application =====
function syncScores(state) {
  const playerScore = state.playerScore ?? 0;
  const opponentScore = state.opponentScore ?? 0;
  if (playerScoreEl) playerScoreEl.textContent = playerScore;
  if (opponentScoreEl) opponentScoreEl.textContent = opponentScore;
  if (playerScoreInline) playerScoreInline.textContent = playerScore;
  if (opponentScoreInline) opponentScoreInline.textContent = opponentScore;
  if (playerScoreInlineMulti) playerScoreInlineMulti.textContent = playerScore;
  if (opponentScoreInlineMulti) opponentScoreInlineMulti.textContent = opponentScore;
}

// ===== Time Control Functions =====
function formatTime(ms) {
  if (ms == null || ms < 0) return '--:--';
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  // Show h:mm:ss when >= 1 hour
  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  // Show m:ss.t (tenths) when < 10 seconds for urgency
  if (totalSeconds < 10) {
    const tenths = Math.floor((ms % 1000) / 100);
    return `${minutes}:${seconds.toString().padStart(2, '0')}.${tenths}`;
  }

  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

function updateTimeControl(tc, turn, gameStatus = 'Ongoing', hasMoves = false) {
  if (!tc || (tc.whiteTimeMs === 0 && tc.blackTimeMs === 0)) {
    hideTimeControl();
    return;
  }
  
  const turnChanged = previousTurn !== null && previousTurn !== turn;
  previousTurn = turn;
  currentTurn = turn;
  
  // Show time control bar
  if (timeControlBar) timeControlBar.classList.add('visible');
  
  // Always update times from server (server is authoritative)
  timeControl = tc;
  if (whiteTimeEl) whiteTimeEl.textContent = formatTime(tc.whiteTimeMs);
  if (blackTimeEl) blackTimeEl.textContent = formatTime(tc.blackTimeMs);
  
  // Only run clock if game is ongoing AND at least one move has been made
  const shouldRunClock = gameStatus === 'Ongoing' && hasMoves;
  
  if (shouldRunClock && (turnChanged || !clockInterval)) {
    startClock();
  } else if (!shouldRunClock) {
    stopClock();
  }
  
  // Update active state (always update visual indicators)
  if (whiteTimerEl) {
    whiteTimerEl.classList.toggle('active', turn === 'White' && shouldRunClock);
    whiteTimerEl.classList.toggle('low-time', timeControl.whiteTimeMs > 0 && timeControl.whiteTimeMs < 30000);
  }
  if (blackTimerEl) {
    blackTimerEl.classList.toggle('active', turn === 'Black' && shouldRunClock);
    blackTimerEl.classList.toggle('low-time', timeControl.blackTimeMs > 0 && timeControl.blackTimeMs < 30000);
  }
}

function hideTimeControl() {
  if (timeControlBar) timeControlBar.classList.remove('visible');
  stopClock();
  timeControl = null;
  previousTurn = null; // Reset turn tracking when hiding
}

// ===== Game End Modal =====
let gameEndShown = false;

/**
 * Determine game result display properties based on status and winner.
 */
function determineGameResult(status, message, isOnline, myColor) {
  const isWhiteWinner = message?.includes('White wins') ?? false;
  const isBlackWinner = message?.includes('Black wins') ?? false;
  
  // Draw statuses
  const drawStatuses = {
    'Stalemate': { icon: '🤝', title: 'Stalemate' },
    'FiftyMoveRule': { icon: '🤝', title: 'Draw — 50-Move Rule' },
    'InsufficientMaterial': { icon: '🤝', title: 'Draw — Insufficient Material' },
    'ThreefoldRepetition': { icon: '🔄', title: 'Draw — Threefold Repetition' },
  };
  
  if (drawStatuses[status]) {
    return { resultType: 'draw', ...drawStatuses[status] };
  }
  
  // Timeout — someone lost on time (not a draw)
  if (status === 'Timeout') {
    const didIWin = isOnline && myColor
      ? (myColor === 'White' && isBlackWinner) || (myColor === 'Black' && isWhiteWinner)
        ? false
        : (myColor === 'White' && isWhiteWinner) || (myColor === 'Black' && isBlackWinner)
      : !message?.includes('Black wins');
    
    if (didIWin) {
      return { resultType: 'win', icon: '⏱️', title: isOnline ? 'Victory on Time!' : 'You Win on Time!' };
    }
    return { resultType: 'loss', icon: '⏱️', title: isOnline ? 'Lost on Time' : 'You Lost on Time' };
  }
  
  if (status !== 'Checkmate') {
    return { resultType: 'draw', icon: '🤝', title: 'Game Over' };
  }
  
  // Checkmate — determine winner
  const didIWin = isOnline && myColor
    ? (myColor === 'White' && isWhiteWinner) || (myColor === 'Black' && isBlackWinner)
    : isWhiteWinner;
  
  if (didIWin) {
    return { resultType: 'win', icon: '🏆', title: isOnline ? 'Checkmate! Victory!' : 'Checkmate! You Win!' };
  }
  
  if (isWhiteWinner || isBlackWinner) {
    return { resultType: 'loss', icon: '😔', title: isOnline ? 'Checkmate — Defeat' : 'Checkmate — You Lost' };
  }
  
  return { resultType: 'draw', icon: '🤝', title: 'Game Over' };
}

function showGameEndModal(status, message, whiteScore, blackScore, isOnline = false, myColor = null) {
  if (gameEndShown || !gameEndModal) return;
  gameEndShown = true;
  
  const { resultType, icon, title } = determineGameResult(status, message, isOnline, myColor);
  
  // Update modal content
  if (gameEndTitle) gameEndTitle.textContent = title;
  if (gameEndIcon) gameEndIcon.textContent = icon;
  if (gameEndMessage) gameEndMessage.textContent = message || status;
  if (finalWhiteScore) finalWhiteScore.textContent = whiteScore;
  if (finalBlackScore) finalBlackScore.textContent = blackScore;
  
  // Update modal class
  gameEndModal.className = 'modal-overlay';
  const modalContent = gameEndModal.querySelector('.modal-content');
  if (modalContent) {
    modalContent.className = `modal-content game-end-modal result-${resultType}`;
  }
  
  // Show modal
  gameEndModal.classList.remove('hidden');
}

function hideGameEndModal() {
  if (gameEndModal) gameEndModal.classList.add('hidden');
  gameEndShown = false;
}

function resetGameEndState() {
  gameEndShown = false;
}

function startClock() {
  stopClock();
  if (!timeControl) return;
  
  let lastUpdateTime = Date.now();
  
  clockInterval = setInterval(() => {
    if (!timeControl) {
      stopClock();
      return;
    }
    
    const now = Date.now();
    const deltaMs = now - lastUpdateTime;
    lastUpdateTime = now;
    
    // Update display only (don't modify the stored timeControl object)
    // The server will send authoritative time updates
    if (currentTurn === 'White') {
      const newWhiteTime = Math.max(0, timeControl.whiteTimeMs - deltaMs);
      if (whiteTimeEl) whiteTimeEl.textContent = formatTime(newWhiteTime);
      if (whiteTimerEl) whiteTimerEl.classList.toggle('low-time', newWhiteTime > 0 && newWhiteTime < 30000);
      
      // Stop local countdown if time runs out (server will handle the actual timeout)
      if (newWhiteTime <= 0) stopClock();
    } else {
      const newBlackTime = Math.max(0, timeControl.blackTimeMs - deltaMs);
      if (blackTimeEl) blackTimeEl.textContent = formatTime(newBlackTime);
      if (blackTimerEl) blackTimerEl.classList.toggle('low-time', newBlackTime > 0 && newBlackTime < 30000);
      
      // Stop local countdown if time runs out (server will handle the actual timeout)
      if (newBlackTime <= 0) stopClock();
    }
  }, 100); // Update every 100ms for smoother countdown
}

function stopClock() {
  if (clockInterval) {
    clearInterval(clockInterval);
    clockInterval = null;
  }
}

function announceMove(move, previousMove) {
  if (!move || move === previousMove || !hasInitializedState) return;
  pushToast(`Move: ${move}`, 'accent');
}

function applyState(state) {
  if (!state?.board) {
    setMessage('Unexpected response from server.');
    return;
  }

  if (opponentRefresh !== null) {
    clearTimeout(opponentRefresh);
    opponentRefresh = null;
  }

  const previousMove = lastMove;
  if (state.lastMove) lastMove = state.lastMove;
  currentTurn = state.turn || 'White';

  renderBoard(state.board, false);
  if (turnEl) turnEl.textContent = state.turn ?? '—';
  if (statusEl) statusEl.textContent = state.status ?? '—';
  if (selectionEl) selectionEl.textContent = 'Pick a piece';
  syncScores(state);

  // Update time control display
  if (state.timeControl) {
    const hasMoves = state.moveHistory && state.moveHistory.length > 0;
    updateTimeControl(state.timeControl, state.turn, state.status, hasMoves);
  } else {
    hideTimeControl();
  }

  // Update move history display
  if (state.moveHistory) {
    moveHistory = state.moveHistory;
    renderMoveHistory();
  }

  const move = state.lastMove ? `Last move: ${state.lastMove}` : 'Ready';
  setMessage(`${state.message || 'Synced.'}\n${move}`);

  if (state.opponentPending) {
    opponentRefresh = setTimeout(loadState, 3000);
  }

  announceMove(state.lastMove, previousMove);
  hasInitializedState = true;

  // Show game end modal if game is over
  if (state.status !== 'Ongoing') {
    stopClock();
    showGameEndModal(
      state.status,
      state.message,
      state.playerScore || 0,
      state.opponentScore || 0,
      false,
      null
    );
  }
}

// ===== Online Multiplayer =====
async function createRoom() {
  setMessage('Creating room…');
  try {
    // Get time control from dropdown
    let tcMs = 600000, incMs = 0;
    if (onlineTimeControl) {
      const [time, inc] = onlineTimeControl.value.split('|').map(Number);
      tcMs = time;
      incMs = inc;
    }
    
    const res = await fetch('/api/online/create', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        timeControlMs: tcMs,
        incrementMs: incMs
      })
    });
    const data = await res.json();

    if (data.roomCode && data.playerId) {
      roomCode = data.roomCode;
      playerId = data.playerId;
      playerColor = 'White';
      isInRoom = true;
      lastMove = null;

      // Clear previous room's chat messages to ensure proper isolation
      clearChat();

      saveSession();
      showRoomInfo();
      openChatPanel();
      setMessage(data.message || 'Room created!');
      startMultiplayerPolling();
    } else {
      setMessage('Failed to create room.');
    }
  } catch (err) {
    setMessage('Failed to create room: ' + err.message);
  }
}

async function joinRoom(code) {
  if (!code || code.length < 4) {
    setMessage('Please enter a valid room code.');
    return;
  }

  setMessage('Joining room…');
  try {
    const res = await fetch(`/api/online/join/${code.toUpperCase()}`, { method: 'POST' });
    const data = await res.json();

    if (data.playerId && data.roomCode) {
      roomCode = data.roomCode;
      playerId = data.playerId;
      playerColor = data.playerColor || 'Black';
      isInRoom = true;
      lastMove = null;

      // Clear previous room's chat messages to ensure proper isolation
      clearChat();

      saveSession();
      showRoomInfo();
      openChatPanel();
      setMessage(data.message || 'Joined!');
      applyOnlineState(data);
      startMultiplayerPolling();
    } else if (data.message) {
      setMessage(data.message);
    } else {
      setMessage('Failed to join room.');
    }
  } catch (err) {
    setMessage('Failed to join room: ' + err.message);
  }
}

async function loadOnlineState() {
  if (!roomCode || !playerId) return;
  try {
    const res = await fetch(`/api/online/state/${roomCode}/${playerId}`);
    const state = await res.json();
    applyOnlineState(state);
  } catch (err) {
    setMessage('Failed to load game state: ' + err.message);
  }
}

async function sendOnlineMove(from, to) {
  if (!roomCode || !playerId) return;
  try {
    const res = await fetch(`/api/online/move/${roomCode}/${playerId}/${from}/${to}`, { method: 'POST' });
    const state = await res.json();
    applyOnlineState(state);
    if (selectionEl) selectionEl.textContent = 'Pick a piece';
  } catch (err) {
    setMessage('Move failed: ' + err.message);
  }
}

async function resetOnlineGame() {
  if (!roomCode || !playerId) return;
  resetGameEndState(); // Reset game end modal state
  try {
    const res = await fetch(`/api/online/reset/${roomCode}/${playerId}`, { method: 'POST' });
    const state = await res.json();
    lastMove = null;
    clearMoveHistory();
    applyOnlineState(state);
  } catch (err) {
    setMessage('Reset failed: ' + err.message);
  }
}

async function leaveRoom() {
  if (roomCode && playerId) {
    try {
      await fetch(`/api/online/leave/${roomCode}/${playerId}`, { method: 'POST' });
    } catch {}
  }
  exitMultiplayerMode();
  setMessage('Left the room.');
}

/**
 * Update multiplayer status pill based on game state.
 */
function updateStatusPill(state) {
  if (!mpStatusPill) return;
  
  if (state.waitingForOpponent) {
    mpStatusPill.textContent = 'Waiting for opponent...';
  } else if (state.status === 'Ongoing' && state.isYourTurn) {
    mpStatusPill.textContent = 'Your turn!';
  } else if (state.status === 'Ongoing') {
    mpStatusPill.textContent = "Opponent's turn...";
  } else {
    // Game over — show descriptive status
    const statusLabels = {
      'Checkmate': '♚ Checkmate',
      'Stalemate': '🤝 Stalemate',
      'FiftyMoveRule': '🤝 Draw — 50-Move Rule',
      'InsufficientMaterial': '🤝 Draw — Insufficient Material',
      'ThreefoldRepetition': '🔄 Draw — Repetition',
      'Timeout': '⏱️ Timeout',
    };
    mpStatusPill.textContent = statusLabels[state.status] || state.status;
  }
}

/**
 * Update UI elements based on online state.
 */
function updateOnlineUI(state) {
  const disabled = !state.isYourTurn && state.status === 'Ongoing';
  if (state.board?.length > 0) {
    renderBoard(state.board, disabled);
  }

  if (turnEl) turnEl.textContent = state.turn ?? '—';
  if (statusEl) statusEl.textContent = state.status ?? '—';
  if (selectionEl) selectionEl.textContent = state.isYourTurn ? 'Your turn' : 'Waiting…';
  syncScores(state);

  if (state.moveHistory) {
    moveHistory = state.moveHistory;
    renderMoveHistory();
  }

  if (state.timeControl) {
    const hasMoves = state.moveHistory && state.moveHistory.length > 0;
    updateTimeControl(state.timeControl, state.turn, state.status, hasMoves);
  } else {
    hideTimeControl();
  }
}

function applyOnlineState(state) {
  if (!state) {
    setMessage('Unexpected response from server.');
    return;
  }

  if (opponentRefresh !== null) {
    clearTimeout(opponentRefresh);
    opponentRefresh = null;
  }

  const previousMove = lastMove;
  if (state.lastMove) lastMove = state.lastMove;

  updateOnlineUI(state);

  // Handle opponent leaving
  if (state.opponentLeft) {
    if (mpStatusPill) mpStatusPill.textContent = 'Opponent left';
    pushToast('Your opponent has left the game', 'secondary');
    setMessage('Opponent left the room. You win!');
    return;
  }

  updateStatusPill(state);

  const move = state.lastMove ? `Last move: ${state.lastMove}` : '';
  setMessage(`${state.message || 'Synced.'}\n${move}`);

  if (state.status === 'Ongoing') {
    opponentRefresh = setTimeout(loadOnlineState, 1000);
  } else {
    stopClock();
    showGameEndModal(
      state.status,
      state.message,
      state.playerScore || 0,
      state.opponentScore || 0,
      true,
      playerColor
    );
  }

  announceMove(state.lastMove, previousMove);
  hasInitializedState = true;
}

function startMultiplayerPolling() {
  if (opponentRefresh !== null) {
    clearTimeout(opponentRefresh);
  }
  loadOnlineState();
}

// ===== UI State =====
function showRoomInfo() {
  if (lobbyOptions) lobbyOptions.classList.add('hidden');
  if (roomInfo) roomInfo.classList.remove('hidden');
  if (roomCodeDisplay) roomCodeDisplay.textContent = roomCode || '------';

  if (playerColorDisplay) {
    if (playerColor === 'White') {
      playerColorDisplay.innerHTML = '<span class="piece">♔</span> White';
      playerColorDisplay.className = 'player-color-badge white';
    } else {
      playerColorDisplay.innerHTML = '<span class="piece">♚</span> Black';
      playerColorDisplay.className = 'player-color-badge black';
    }
  }
}

function showLobbyOptions() {
  if (lobbyOptions) lobbyOptions.classList.remove('hidden');
  if (roomInfo) roomInfo.classList.add('hidden');
}

function setGameMode(mode) {
  // If already in the requested mode, do nothing
  if (gameMode === mode) {
    return;
  }

  // Always clear any pending timers first to prevent cross-mode interference
  if (opponentRefresh !== null) {
    clearTimeout(opponentRefresh);
    opponentRefresh = null;
  }
  stopChatPolling();
  
  // Clear selection and valid moves to prevent stale state
  selection = null;
  activeValidMoves = [];
  if (validMoveTimer) {
    clearTimeout(validMoveTimer);
    validMoveTimer = null;
  }

  gameMode = mode;
  document.body.classList.remove('mode-single', 'mode-multi');
  document.body.classList.add(mode === 'single' ? 'mode-single' : 'mode-multi');

  singlePlayerBtn?.classList.toggle('active', mode === 'single');
  multiplayerBtn?.classList.toggle('active', mode === 'multi');

  if (mode === 'single') {
    // Switch to single player mode but keep the online session active
    // Only the "Leave Room" button will actually exit the room
    lastMove = null;
    closeChatPanelFn();
    closeOnlinePanelFn();
    loadState();
  } else {
    // When switching to multiplayer mode
    lastMove = null;
    if (isInRoom) {
      // If already in a room, show room info and resume
      showRoomInfo();
      openOnlinePanel();
      openChatPanel(); // Restart chat polling when switching back to multiplayer
      startMultiplayerPolling();
      loadOnlineState();
    } else {
      // Not in a room, show lobby options
      showLobbyOptions();
      openOnlinePanel();
      // Render empty board while waiting for room
      renderBoard(['rnbqkbnr', 'pppppppp', '........', '........', '........', '........', 'PPPPPPPP', 'RNBQKBNR'], true);
    }
  }
}

function exitMultiplayerMode() {
  roomCode = null;
  playerId = null;
  playerColor = null;
  isInRoom = false;
  lastMove = null;
  localStorage.removeItem('chess_session');

  if (opponentRefresh !== null) {
    clearTimeout(opponentRefresh);
    opponentRefresh = null;
  }

  stopChatPolling();
  clearChat();
  showLobbyOptions();
  renderBoard(['rnbqkbnr', 'pppppppp', '........', '........', '........', '........', 'PPPPPPPP', 'RNBQKBNR'], true);
}

// ===== Panel Controls =====
function openOnlinePanel() {
  onlinePanel?.classList.add('open');
  // Don't show backdrop in online mode - let panels coexist with board
}

function closeOnlinePanelFn() {
  onlinePanel?.classList.remove('open');
}

function openChatPanel() {
  chatPanel?.classList.add('open');
  // Don't show backdrop in online mode - let panels coexist with board
  resetChatBadge();
  loadChatMessages();
  startChatPolling();
}

function closeChatPanelFn() {
  chatPanel?.classList.remove('open');
}

function openMoveHistoryPanel() {
  moveHistoryPanel?.classList.add('open');
}

function closeMoveHistoryPanelFn() {
  moveHistoryPanel?.classList.remove('open');
}

function toggleInfoPopover() {
  infoPopover?.classList.toggle('open');
}

function closeAllPanels() {
  closeOnlinePanelFn();
  closeChatPanelFn();
  closeMoveHistoryPanelFn();
  infoPopover?.classList.remove('open');
  hideTimeControlModal();
}

// ===== Time Control Modal =====
function showTimeControlModal() {
  timeControlModal?.classList.remove('hidden');
}

function hideTimeControlModal() {
  timeControlModal?.classList.add('hidden');
}

// ===== Chat =====
async function sendChatMessage(message) {
  if (!roomCode || !playerId || !message?.trim()) return;

  if (chatSendBtn) chatSendBtn.disabled = true;

  try {
    const res = await fetch(`/api/chat/send/${roomCode}/${playerId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: message.trim() })
    });
    const data = await res.json();

    if (data.success) {
      if (chatInput) chatInput.value = '';
      await loadChatMessages();
    } else {
      setMessage('Chat error: ' + (data.error || 'Failed'));
    }
  } catch {
    setMessage('Chat error: Could not send');
  } finally {
    if (chatSendBtn) chatSendBtn.disabled = false;
    chatInput?.focus();
  }
}

async function loadChatMessages() {
  if (!roomCode || !playerId) return;
  try {
    // Add cache-busting parameter to prevent stale responses
    const timestamp = Date.now();
    const res = await fetch(`/api/chat/history/${roomCode}/${playerId}?limit=100&_=${timestamp}`);
    const data = await res.json();
    if (data.success && data.messages) {
      displayChatMessages(data.messages);
      if (data.messages.length > 0) {
        lastChatTimestamp = Math.max(...data.messages.map(m => m.timestamp));
      }
    }
  } catch (err) {
    console.error('Error loading chat:', err);
  }
}

async function pollNewChatMessages() {
  if (!roomCode || !playerId) return;
  try {
    // Add cache-busting parameter to prevent stale responses
    const timestamp = Date.now();
    const res = await fetch(`/api/chat/recent/${roomCode}/${playerId}/${lastChatTimestamp || 0}?_=${timestamp}`);
    const data = await res.json();
    if (data.success && data.messages?.length > 0) {
      appendChatMessages(data.messages, { notify: true });
      lastChatTimestamp = Math.max(...data.messages.map(m => m.timestamp));
    }
  } catch (err) {
    console.error('Error polling chat:', err);
  }
}

function displayChatMessages(messages) {
  if (!chatMessages) return;
  chatMessages.innerHTML = '';
  if (!messages?.length) {
    chatMessages.innerHTML = '<div class="chat-empty">No messages yet</div>';
    return;
  }
  messages.forEach(msg => {
    chatMessages.appendChild(createChatMessageElement(msg));
  });
  scrollChatToBottom();
}

function appendChatMessages(messages, { notify = false } = {}) {
  if (!messages?.length || !chatMessages) return;

  const emptyEl = chatMessages.querySelector('.chat-empty');
  if (emptyEl) emptyEl.remove();

  messages.forEach(msg => {
    chatMessages.appendChild(createChatMessageElement(msg));
    const isOwn = msg.playerId === playerId;
    if (notify && !isOwn && !chatPanel?.classList.contains('open')) {
      incrementChatBadge();
      pushToast(`Chat from ${msg.playerColor}`, 'secondary');
    }
  });
  scrollChatToBottom();
}

function createChatMessageElement(msg) {
  const div = document.createElement('div');
  const isOwn = msg.playerId === playerId;
  div.className = `chat-message ${msg.playerColor.toLowerCase()}${isOwn ? ' own' : ''}`;

  // Timestamp is now always in epoch milliseconds from server
  const time = new Date(msg.timestamp);
  const timeStr = time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

  div.innerHTML = `
    <div class="chat-message-header">
      <span class="chat-sender">${isOwn ? 'You' : msg.playerColor}</span>
      <span class="chat-timestamp">${timeStr}</span>
    </div>
    <div class="chat-text">${escapeHtml(msg.message)}</div>
  `;
  return div;
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function scrollChatToBottom() {
  if (chatMessages) chatMessages.scrollTop = chatMessages.scrollHeight;
}

function clearChat() {
  if (chatMessages) chatMessages.innerHTML = '<div class="chat-empty">No messages yet</div>';
  if (chatInput) chatInput.value = '';
  lastChatTimestamp = 0;
  resetChatBadge();
}

function incrementChatBadge() {
  unreadChatCount++;
  if (chatBadge) {
    chatBadge.textContent = unreadChatCount;
    chatBadge.classList.add('visible');
  }
}

function resetChatBadge() {
  unreadChatCount = 0;
  if (chatBadge) {
    chatBadge.textContent = '0';
    chatBadge.classList.remove('visible');
  }
}

function startChatPolling() {
  stopChatPolling();
  // Poll immediately, then set up interval
  pollNewChatMessages();
  chatPollInterval = setInterval(pollNewChatMessages, 2000);
}

function stopChatPolling() {
  if (chatPollInterval) {
    clearInterval(chatPollInterval);
    chatPollInterval = null;
  }
}

// ===== Move History =====
const pieceSymbolMap = {
  'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
  'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟'
};

/**
 * Get maximum move number from a list of moves.
 */
function getMaxMoveNumber(moves) {
  if (moves.length === 0) return 0;
  return Math.max(...moves.map(m => m.moveNumber));
}

/**
 * Build move history table HTML.
 */
function buildMoveHistoryTable(whiteMoves, blackMoves, maxMoveNum) {
  const rows = [];
  for (let i = 1; i <= maxMoveNum; i++) {
    const whiteMove = whiteMoves.find(m => m.moveNumber === i);
    const blackMove = blackMoves.find(m => m.moveNumber === i);
    rows.push(`<tr>
      <td class="move-number">${i}.</td>
      <td class="white-move">${formatMoveEntry(whiteMove)}</td>
      <td class="black-move">${formatMoveEntry(blackMove)}</td>
    </tr>`);
  }
  return `<table class="move-history-table">
    <thead><tr><th>#</th><th>♔ White</th><th>♚ Black</th></tr></thead>
    <tbody>${rows.join('')}</tbody>
  </table>`;
}

function renderMoveHistory() {
  if (!moveHistoryContainer) return;
  
  if (!moveHistory || moveHistory.length === 0) {
    moveHistoryContainer.innerHTML = '<div class="move-history-empty">No moves yet. Start playing!</div>';
    return;
  }

  const whiteMoves = moveHistory.filter(m => m.color === 'White');
  const blackMoves = moveHistory.filter(m => m.color === 'Black');
  const maxMoveNum = Math.max(getMaxMoveNumber(whiteMoves), getMaxMoveNumber(blackMoves));

  moveHistoryContainer.innerHTML = buildMoveHistoryTable(whiteMoves, blackMoves, maxMoveNum);
  moveHistoryContainer.scrollTop = moveHistoryContainer.scrollHeight;
}

/**
 * Build chess notation from move object.
 */
function buildMoveNotation(move) {
  const piece = move.piece?.toUpperCase() || '';
  const pieceSymbol = piece && piece !== 'P' ? piece : '';
  const capture = move.capturedPiece ? 'x' : '';
  const to = move.toSquare || '';
  const promo = move.promotion ? `=${move.promotion.toUpperCase()}` : '';
  let check = '';
  if (move.isCheckmate) check = '#';
  else if (move.isCheck) check = '+';
  return `${pieceSymbol}${capture}${to}${promo}${check}`;
}

/**
 * Get CSS class for move type styling.
 */
function getMoveClassName(move) {
  if (move.isCheckmate) return 'checkmate';
  if (move.isCheck) return 'check';
  if (move.capturedPiece) return 'capture';
  if (move.isCastle) return 'castle';
  return '';
}

function formatMoveEntry(move) {
  if (!move) return '—';
  const notation = move.notation || buildMoveNotation(move);
  const className = getMoveClassName(move);
  return `<span class="move-notation ${className}">${notation}</span>`;
}

function clearMoveHistory() {
  moveHistory = [];
  if (moveHistoryContainer) {
    moveHistoryContainer.innerHTML = '<div class="move-history-empty">No moves yet. Start playing!</div>';
  }
}

// ===== Restore Session =====
function startMultiplayerUI(session) {
  document.body.classList.remove('mode-single');
  document.body.classList.add('mode-multi');
  multiplayerBtn?.classList.add('active');
  singlePlayerBtn?.classList.remove('active');

  if (session) {
    roomCode = session.roomCode;
    playerId = session.playerId;
    playerColor = session.playerColor;
    isInRoom = true;
  }

  showRoomInfo();
  openChatPanel();
  startMultiplayerPolling();
}

// ===== Event Listeners =====
resetBtn?.addEventListener('click', () => {
  if (gameMode === 'single') {
    showTimeControlModal();
  } else {
    resetGame();
  }
});
refreshBtn?.addEventListener('click', () => {
  if (gameMode === 'multi' && isInRoom) {
    loadOnlineState();
  } else {
    loadState();
  }
});

singlePlayerBtn?.addEventListener('click', () => setGameMode('single'));
multiplayerBtn?.addEventListener('click', () => setGameMode('multi'));

createRoomBtn?.addEventListener('click', createRoom);
joinRoomBtn?.addEventListener('click', () => joinRoom(roomCodeInput?.value));
roomCodeInput?.addEventListener('keypress', (e) => {
  if (e.key === 'Enter') joinRoom(roomCodeInput.value);
});
leaveRoomBtn?.addEventListener('click', leaveRoom);

closeOnlinePanel?.addEventListener('click', closeOnlinePanelFn);
closeChatPanel?.addEventListener('click', closeChatPanelFn);
closeMoveHistoryPanel?.addEventListener('click', closeMoveHistoryPanelFn);
chatToggleBtn?.addEventListener('click', () => {
  if (chatPanel?.classList.contains('open')) {
    closeChatPanelFn();
  } else {
    openChatPanel();
  }
});
moveHistoryToggleBtn?.addEventListener('click', () => {
  if (moveHistoryPanel?.classList.contains('open')) {
    closeMoveHistoryPanelFn();
  } else {
    openMoveHistoryPanel();
  }
});

chatSendBtn?.addEventListener('click', () => {
  const msg = chatInput?.value?.trim();
  if (msg) sendChatMessage(msg);
});
chatInput?.addEventListener('keypress', (e) => {
  if (e.key === 'Enter') {
    const msg = chatInput.value?.trim();
    if (msg) sendChatMessage(msg);
  }
});

infoToggle?.addEventListener('click', toggleInfoPopover);

// Time control modal handlers
closeTimeControlModal?.addEventListener('click', hideTimeControlModal);
startWithTimeControl?.addEventListener('click', () => {
  hideTimeControlModal();
  resetGame();
});
timeControlOptions?.forEach(option => {
  option.addEventListener('click', () => {
    // Update selection UI
    timeControlOptions.forEach(o => o.classList.remove('selected'));
    option.classList.add('selected');
    // Update state
    selectedTimeControlMs = Number.parseInt(option.dataset.time) || 0;
    selectedIncrementMs = Number.parseInt(option.dataset.increment) || 0;
  });
});

backdrop?.addEventListener('click', closeAllPanels);

// Close modal when clicking outside modal content
timeControlModal?.addEventListener('click', (e) => {
  if (e.target === timeControlModal) {
    hideTimeControlModal();
  }
});

// Game end modal handlers
closeGameEndModal?.addEventListener('click', hideGameEndModal);
playAgainBtn?.addEventListener('click', () => {
  hideGameEndModal();
  if (gameMode === 'multi' && isInRoom) {
    resetOnlineGame();
  } else {
    resetGame();
  }
});
gameEndModal?.addEventListener('click', (e) => {
  if (e.target === gameEndModal) {
    hideGameEndModal();
  }
});

// Close modal on Escape key
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    hideTimeControlModal();
    hideGameEndModal();
  }
});

// Close popover when clicking outside
document.addEventListener('click', (e) => {
  if (!infoPopover?.contains(e.target) && !infoToggle?.contains(e.target)) {
    infoPopover?.classList.remove('open');
  }
});

// ===== Initialize =====
(async () => {
  const savedSession = loadSession();
  if (savedSession) {
    startMultiplayerUI(savedSession);
  } else {
    await loadState();
  }
})();
