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

// Info popover
const infoToggle = document.getElementById('infoToggle');
const infoPopover = document.getElementById('infoPopover');

// History panel elements
const historyPanel = document.getElementById('historyPanel');
const closeHistoryPanel = document.getElementById('closeHistoryPanel');
const historyToggleBtn = document.getElementById('historyToggleBtn');
const historyList = document.getElementById('historyList');
const undoBtn = document.getElementById('undoBtn');
const firstMoveBtn = document.getElementById('firstMoveBtn');
const prevMoveBtn = document.getElementById('prevMoveBtn');
const nextMoveBtn = document.getElementById('nextMoveBtn');
const lastMoveBtn = document.getElementById('lastMoveBtn');

// Backdrop
const backdrop = document.getElementById('backdrop');

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

// Move history state
let moveHistory = [];
let replayPosition = -1; // -1 means viewing current state
let isViewingHistory = false;

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
    const res = await fetch(`/api/move/${from}/${to}`, { method: 'POST' });
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
    const res = await fetch('/api/state');
    const payload = await res.json();
    applyState(payload);
    // Also load move history for single player
    if (gameMode === 'single') {
      await loadMoveHistory();
    }
  } catch (err) {
    console.error('Failed to load state:', err);
    setMessage('Could not reach the chess server.');
  }
}

async function resetGame() {
  setMessage('Resetting…');
  try {
    if (gameMode === 'multi' && isInRoom) {
      await resetOnlineGame();
    } else {
      const res = await fetch('/api/reset', { method: 'POST' });
      const payload = await res.json();
      lastMove = null;
      applyState(payload);
      // Clear and reload history after reset
      moveHistory = [];
      replayPosition = -1;
      isViewingHistory = false;
      updateHistoryDisplay();
    }
  } catch (err) {
    setMessage('Reset failed: ' + err.message);
  }
}

async function loadValidMoves(square) {
  try {
    const url = (gameMode === 'multi' && isInRoom && roomCode && playerId)
      ? `/api/online/validmoves/${roomCode}/${playerId}/${square}`
      : `/api/validmoves/${square}`;
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

  renderBoard(state.board, false);
  if (turnEl) turnEl.textContent = state.turn ?? '—';
  if (statusEl) statusEl.textContent = state.status ?? '—';
  if (selectionEl) selectionEl.textContent = 'Pick a piece';
  syncScores(state);

  const move = state.lastMove ? `Last move: ${state.lastMove}` : 'Ready';
  setMessage(`${state.message || 'Synced.'}\n${move}`);

  if (state.opponentPending) {
    opponentRefresh = setTimeout(loadState, 3000);
  }

  announceMove(state.lastMove, previousMove);
  hasInitializedState = true;
}

// ===== Online Multiplayer =====
async function createRoom() {
  setMessage('Creating room…');
  try {
    const res = await fetch('/api/online/create', { method: 'POST' });
    const data = await res.json();

    if (data.roomCode && data.playerId) {
      roomCode = data.roomCode;
      playerId = data.playerId;
      playerColor = 'White';
      isInRoom = true;
      lastMove = null;

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
  try {
    const res = await fetch(`/api/online/reset/${roomCode}/${playerId}`, { method: 'POST' });
    const state = await res.json();
    lastMove = null;
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

  const disabled = !state.isYourTurn && state.status === 'Ongoing';
  if (state.board?.length > 0) {
    renderBoard(state.board, disabled);
  }

  if (turnEl) turnEl.textContent = state.turn ?? '—';
  if (statusEl) statusEl.textContent = state.status ?? '—';
  if (selectionEl) selectionEl.textContent = state.isYourTurn ? 'Your turn' : 'Waiting…';
  syncScores(state);

  // Handle opponent leaving
  if (state.opponentLeft) {
    if (mpStatusPill) mpStatusPill.textContent = 'Opponent left';
    pushToast('Your opponent has left the game', 'secondary');
    setMessage('Opponent left the room. You win!');
    // Don't start polling again - game is over
    return;
  }

  if (mpStatusPill) {
    if (state.waitingForOpponent) {
      mpStatusPill.textContent = 'Waiting for opponent...';
    } else if (state.isYourTurn) {
      mpStatusPill.textContent = 'Your turn!';
    } else if (state.status === 'Ongoing') {
      mpStatusPill.textContent = "Opponent's turn...";
    } else {
      mpStatusPill.textContent = state.status;
    }
  }

  const move = state.lastMove ? `Last move: ${state.lastMove}` : '';
  setMessage(`${state.message || 'Synced.'}\n${move}`);

  if (state.status === 'Ongoing') {
    opponentRefresh = setTimeout(loadOnlineState, 1000);
  } else if (state.status !== 'Ongoing') {
    // Game ended, show result
    if (state.winner) {
      const isWinner = (state.winner === 'White' && playerColor === 'White') ||
                       (state.winner === 'Black' && playerColor === 'Black');
      pushToast(isWinner ? 'You won!' : 'You lost!', isWinner ? 'success' : 'accent');
    }
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
    // Exit any online room when switching to single player
    if (isInRoom) {
      exitMultiplayerMode();
    }
    lastMove = null;
    closeChatPanelFn();
    closeOnlinePanelFn();
    closeHistoryPanelFn();
    // Reset move history for single player
    moveHistory = [];
    replayPosition = -1;
    isViewingHistory = false;
    updateHistoryDisplay();
    loadState();
  } else {
    // When switching to multiplayer, show lobby but don't start any polling yet
    lastMove = null;
    moveHistory = [];
    replayPosition = -1;
    isViewingHistory = false;
    updateHistoryDisplay();
    showLobbyOptions();
    openOnlinePanel();
    // Render empty board while waiting for room
    renderBoard(['rnbqkbnr', 'pppppppp', '........', '........', '........', '........', 'PPPPPPPP', 'RNBQKBNR'], true);
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
  moveHistory = [];
  replayPosition = -1;
  isViewingHistory = false;
  updateHistoryDisplay();
  renderBoard(['rnbqkbnr', 'pppppppp', '........', '........', '........', '........', 'PPPPPPPP', 'RNBQKBNR'], true);
}

// ===== Panel Controls =====
function openOnlinePanel() {
  onlinePanel?.classList.add('open');
  backdrop?.classList.add('visible');
}

function closeOnlinePanelFn() {
  onlinePanel?.classList.remove('open');
  if (!chatPanel?.classList.contains('open') && !historyPanel?.classList.contains('open')) {
    backdrop?.classList.remove('visible');
  }
}

function openChatPanel() {
  chatPanel?.classList.add('open');
  backdrop?.classList.add('visible');
  resetChatBadge();
  loadChatMessages();
  startChatPolling();
}

function closeChatPanelFn() {
  chatPanel?.classList.remove('open');
  if (!onlinePanel?.classList.contains('open') && !historyPanel?.classList.contains('open')) {
    backdrop?.classList.remove('visible');
  }
}

function openHistoryPanel() {
  historyPanel?.classList.add('open');
  backdrop?.classList.add('visible');
  loadMoveHistory();
}

function closeHistoryPanelFn() {
  historyPanel?.classList.remove('open');
  if (!onlinePanel?.classList.contains('open') && !chatPanel?.classList.contains('open')) {
    backdrop?.classList.remove('visible');
  }
  // If viewing history, return to current position when closing
  if (isViewingHistory) {
    exitHistoryReplay();
  }
}

function toggleInfoPopover() {
  infoPopover?.classList.toggle('open');
}

function closeAllPanels() {
  closeOnlinePanelFn();
  closeChatPanelFn();
  closeHistoryPanelFn();
  infoPopover?.classList.remove('open');
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
    const res = await fetch(`/api/chat/history/${roomCode}/${playerId}?limit=100`);
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
    const res = await fetch(`/api/chat/recent/${roomCode}/${playerId}/${lastChatTimestamp || 0}`);
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

  let ts = msg.timestamp;
  if (ts < 946684800000) ts *= 1000;
  const time = new Date(ts);
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
  chatPollInterval = setInterval(pollNewChatMessages, 2000);
}

function stopChatPolling() {
  if (chatPollInterval) {
    clearInterval(chatPollInterval);
    chatPollInterval = null;
  }
}

// ===== Move History =====
async function loadMoveHistory() {
  try {
    const res = await fetch('/api/history');
    const data = await res.json();
    if (data.success && data.history) {
      moveHistory = data.history;
      updateHistoryDisplay();
    }
  } catch (err) {
    console.error('Error loading history:', err);
  }
}

function updateHistoryDisplay() {
  if (!historyList) return;
  
  if (!moveHistory || moveHistory.length === 0) {
    historyList.innerHTML = '<div class="history-empty">No moves yet. Make your first move!</div>';
    updateHistoryButtons();
    return;
  }
  
  historyList.innerHTML = '';
  
  // Group moves into pairs (white + black)
  for (let i = 0; i < moveHistory.length; i += 2) {
    const moveNum = Math.floor(i / 2) + 1;
    const row = document.createElement('div');
    row.className = 'move-row';
    
    // Move number
    const numEl = document.createElement('span');
    numEl.className = 'move-number';
    numEl.textContent = `${moveNum}.`;
    row.appendChild(numEl);
    
    // White's move
    const whiteMove = moveHistory[i];
    const whiteEl = document.createElement('div');
    whiteEl.className = 'move-entry white';
    whiteEl.textContent = whiteMove.notation || `${whiteMove.fromSquare}-${whiteMove.toSquare}`;
    whiteEl.dataset.moveIndex = i;
    if (replayPosition === i) whiteEl.classList.add('active');
    whiteEl.addEventListener('click', () => goToMove(i));
    row.appendChild(whiteEl);
    
    // Black's move (if exists)
    if (i + 1 < moveHistory.length) {
      const blackMove = moveHistory[i + 1];
      const blackEl = document.createElement('div');
      blackEl.className = 'move-entry black';
      blackEl.textContent = blackMove.notation || `${blackMove.fromSquare}-${blackMove.toSquare}`;
      blackEl.dataset.moveIndex = i + 1;
      if (replayPosition === i + 1) blackEl.classList.add('active');
      blackEl.addEventListener('click', () => goToMove(i + 1));
      row.appendChild(blackEl);
    } else {
      // Empty placeholder for alignment
      const emptyEl = document.createElement('div');
      emptyEl.className = 'move-entry';
      emptyEl.style.visibility = 'hidden';
      row.appendChild(emptyEl);
    }
    
    historyList.appendChild(row);
  }
  
  // Scroll to bottom if viewing current state
  if (replayPosition === -1) {
    historyList.scrollTop = historyList.scrollHeight;
  }
  
  updateHistoryButtons();
}

function updateHistoryButtons() {
  const hasMoves = moveHistory && moveHistory.length > 0;
  const atStart = replayPosition === 0 || (!isViewingHistory && moveHistory.length === 0);
  const atEnd = replayPosition === -1 || replayPosition === moveHistory.length - 1;
  
  if (undoBtn) undoBtn.disabled = !hasMoves || isViewingHistory;
  if (firstMoveBtn) firstMoveBtn.disabled = !hasMoves || atStart;
  if (prevMoveBtn) prevMoveBtn.disabled = !hasMoves || atStart;
  if (nextMoveBtn) nextMoveBtn.disabled = !hasMoves || atEnd;
  if (lastMoveBtn) lastMoveBtn.disabled = !hasMoves || replayPosition === -1;
}

async function goToMove(index) {
  if (!moveHistory || index < 0 || index >= moveHistory.length) return;
  
  try {
    // Fetch the board state at this move
    const res = await fetch(`/api/replay/${index + 1}`); // API uses 1-based move numbers
    const data = await res.json();
    
    if (data.board) {
      isViewingHistory = true;
      replayPosition = index;
      renderBoard(data.board, true); // Disable interaction while viewing history
      
      // Update active move highlight
      const moveEntries = historyList.querySelectorAll('.move-entry');
      moveEntries.forEach(el => el.classList.remove('active'));
      const activeEl = historyList.querySelector(`[data-move-index="${index}"]`);
      if (activeEl) activeEl.classList.add('active');
      
      updateHistoryButtons();
      setMessage(`Viewing move ${index + 1} of ${moveHistory.length}`);
    }
  } catch (err) {
    console.error('Error loading replay:', err);
    setMessage('Failed to load move replay');
  }
}

function goToFirstMove() {
  if (moveHistory && moveHistory.length > 0) {
    goToMove(0);
  }
}

function goToPrevMove() {
  if (!moveHistory || moveHistory.length === 0) return;
  
  if (replayPosition === -1) {
    // Currently at end, go to last move
    goToMove(moveHistory.length - 1);
  } else if (replayPosition > 0) {
    goToMove(replayPosition - 1);
  }
}

function goToNextMove() {
  if (!moveHistory || moveHistory.length === 0) return;
  
  if (replayPosition === -1) return; // Already at current
  
  if (replayPosition < moveHistory.length - 1) {
    goToMove(replayPosition + 1);
  } else {
    // At last historical move, exit replay
    exitHistoryReplay();
  }
}

function goToLastMove() {
  exitHistoryReplay();
}

function exitHistoryReplay() {
  if (!isViewingHistory) return;
  
  isViewingHistory = false;
  replayPosition = -1;
  
  // Reload current game state
  if (gameMode === 'multi' && isInRoom) {
    loadOnlineState();
  } else {
    loadState();
  }
  
  // Remove active highlights
  const moveEntries = historyList?.querySelectorAll('.move-entry');
  moveEntries?.forEach(el => el.classList.remove('active'));
  
  updateHistoryButtons();
  setMessage('Returned to current game');
}

async function undoLastMove() {
  if (isViewingHistory) return;
  
  try {
    const res = await fetch('/api/undo', { method: 'POST' });
    const data = await res.json();
    
    if (data.success) {
      await loadState();
      await loadMoveHistory();
      pushToast('Move undone', 'success');
    } else {
      setMessage(data.message || 'Cannot undo');
    }
  } catch (err) {
    console.error('Error undoing move:', err);
    setMessage('Failed to undo move');
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
resetBtn?.addEventListener('click', resetGame);
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
chatToggleBtn?.addEventListener('click', () => {
  if (chatPanel?.classList.contains('open')) {
    closeChatPanelFn();
  } else {
    openChatPanel();
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

// History panel event listeners
closeHistoryPanel?.addEventListener('click', closeHistoryPanelFn);
historyToggleBtn?.addEventListener('click', () => {
  if (historyPanel?.classList.contains('open')) {
    closeHistoryPanelFn();
  } else {
    openHistoryPanel();
  }
});
undoBtn?.addEventListener('click', undoLastMove);
firstMoveBtn?.addEventListener('click', goToFirstMove);
prevMoveBtn?.addEventListener('click', goToPrevMove);
nextMoveBtn?.addEventListener('click', goToNextMove);
lastMoveBtn?.addEventListener('click', goToLastMove);

backdrop?.addEventListener('click', closeAllPanels);

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
