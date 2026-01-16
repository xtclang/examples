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
  gameMode = mode;
  document.body.classList.remove('mode-single', 'mode-multi');
  document.body.classList.add(mode === 'single' ? 'mode-single' : 'mode-multi');

  singlePlayerBtn?.classList.toggle('active', mode === 'single');
  multiplayerBtn?.classList.toggle('active', mode === 'multi');

  if (mode === 'single') {
    if (opponentRefresh !== null) {
      clearTimeout(opponentRefresh);
      opponentRefresh = null;
    }
    lastMove = null;
    closeChatPanelFn();
    closeOnlinePanelFn();
    loadState();
  } else {
    showLobbyOptions();
    openOnlinePanel();
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
  backdrop?.classList.add('visible');
}

function closeOnlinePanelFn() {
  onlinePanel?.classList.remove('open');
  if (!chatPanel?.classList.contains('open')) {
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
  if (!onlinePanel?.classList.contains('open')) {
    backdrop?.classList.remove('visible');
  }
}

function toggleInfoPopover() {
  infoPopover?.classList.toggle('open');
}

function closeAllPanels() {
  closeOnlinePanelFn();
  closeChatPanelFn();
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
