"use strict";

const PAYTABLE = [
  { name: "Royal Flush", base: 2500, key: "royalFlush" },
  { name: "Straight Flush", base: 500, key: "straightFlush" },
  { name: "Four of a Kind", base: 250, key: "fourKind" },
  { name: "Full House", base: 80, key: "fullHouse" },
  { name: "Flush", base: 50, key: "flush" },
  { name: "Straight", base: 40, key: "straight" },
  { name: "Three of a Kind", base: 30, key: "threeKind" },
  { name: "Two Pair", base: 20, key: "twoPair" },
  { name: "Jacks or Better", base: 10, key: "jacksOrBetter" },
];

const SUITS = ["C", "D", "H", "S"];
const SUIT_SYMBOL = { C: "♣", D: "♦", H: "♥", S: "♠" };
const RANK_TEXT = {
  1: "A",
  2: "2",
  3: "3",
  4: "4",
  5: "5",
  6: "6",
  7: "7",
  8: "8",
  9: "9",
  10: "10",
  11: "J",
  12: "Q",
  13: "K",
};

const COURT_IMAGE = {
  11: "./assets/jack.jpg",
  12: "./assets/queen.jpg",
  13: "./assets/king.jpg",
};

const TAUNTS = [
  "You must be new to this game!",
  "Maybe you are lucky in other ways!",
  "Have you thought about other hobbies?",
  "Therapy might be cheaper!",
  "Better luck next time.",
  "Deposit car keys now.",
];

const state = {
  phase: "PRE_DEAL",
  soundOn: true,
  balance: 90,
  bet: 10,
  deck: [],
  top: 0,
  hand: [],
  hold: [false, false, false, false, false],
  drawStage: ["none", "none", "none", "none", "none"],
  highlightedPayKey: null,
  secretRedrawMode: false,
};

const el = {
  cards: document.getElementById("cards"),
  paytableList: document.getElementById("paytableList"),
  betValue: document.getElementById("betValue"),
  balanceValue: document.getElementById("balanceValue"),
  resultLine: document.getElementById("resultLine"),
  subLine: document.getElementById("subLine"),
  dealDrawBtn: document.getElementById("dealDrawBtn"),
  betUpBtn: document.getElementById("betUpBtn"),
  betDownBtn: document.getElementById("betDownBtn"),
  helpBtn: document.getElementById("helpBtn"),
  soundBtn: document.getElementById("soundBtn"),
  helpDialog: document.getElementById("helpDialog"),
};

let audioContext;
let dealTimers = [];

function ensureAudioContext() {
  if (!audioContext) {
    audioContext = new (window.AudioContext || window.webkitAudioContext)();
  }
  return audioContext;
}

function playTone(freq, duration, type = "triangle", volume = 0.05) {
  if (!state.soundOn) return;
  const ctx = ensureAudioContext();
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = type;
  osc.frequency.value = freq;
  gain.gain.value = volume;
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start();
  setTimeout(() => {
    osc.stop();
  }, duration);
}

function playSlide(startFreq, endFreq, duration, type = "sawtooth", volume = 0.055) {
  if (!state.soundOn) return;
  const ctx = ensureAudioContext();
  const now = ctx.currentTime;
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(startFreq, now);
  osc.frequency.linearRampToValueAtTime(endFreq, now + duration / 1000);
  gain.gain.value = volume;
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(now);
  osc.stop(now + duration / 1000);
}

function playSequence(sequence) {
  if (!state.soundOn) return;
  let delay = 0;
  for (const note of sequence) {
    setTimeout(() => playTone(note.f, note.d), delay);
    delay += note.d + 25;
  }
}

function startingSound() {
  playSequence([{ f: 262, d: 90 }, { f: 330, d: 90 }, { f: 392, d: 100 }, { f: 523, d: 130 }]);
}

function losingSound() {
  playSequence([{ f: 262, d: 140 }, { f: 247, d: 140 }, { f: 220, d: 140 }, { f: 196, d: 260 }]);
}

function losingHandSound() {
  if (!state.soundOn) return;
  playSlide(420, 320, 180);
  setTimeout(() => playSlide(360, 250, 200), 140);
  setTimeout(() => playSlide(300, 180, 240), 310);
}

function winningSound() {
  playSequence([{ f: 523, d: 90 }, { f: 659, d: 90 }, { f: 784, d: 180 }, { f: 1047, d: 260 }]);
}

function goodWinningSound() {
  playSequence([
    { f: 494, d: 80 },
    { f: 587, d: 90 },
    { f: 740, d: 120 },
    { f: 880, d: 150 },
  ]);
}

function greatWinningSound() {
  playSequence([{ f: 659, d: 80 }, { f: 784, d: 80 }, { f: 1047, d: 110 }, { f: 1318, d: 140 }, { f: 1568, d: 190 }]);
}

function invalidBeep() {
  playTone(131, 55, "square", 0.045);
}

function hiBeep() {
  playTone(262, 22, "triangle", 0.04);
}

function holdChime() {
  playSequence([
    { f: 740, d: 35 },
    { f: 988, d: 45 },
  ]);
}

function cardFlipSound() {
  if (!state.soundOn) return;
  playSlide(700, 600, 85, "sine", 0.018);
  setTimeout(() => playTone(640, 22, "sine", 0.014), 32);
}

function clearDealTimers() {
  for (const id of dealTimers) clearTimeout(id);
  dealTimers = [];
}

function countUnheldCards() {
  let count = 0;
  for (let i = 0; i < 5; i += 1) {
    if (!state.hold[i]) count += 1;
  }
  return count;
}

function ensureDrawCapacity() {
  const needed = countUnheldCards();
  if (state.top + needed <= state.deck.length) return;
  state.deck = freshDeck();
  shuffleDeck(state.deck);
  state.top = 0;
}

function enterSecretRedrawMode() {
  state.secretRedrawMode = true;
  state.phase = "HOLD_SELECT";
  setResult("Secret test mode enabled.", "Press 1-5/tap to hold, Enter to redraw, Z to exit.");
  renderAll();
}

function exitSecretRedrawMode() {
  state.secretRedrawMode = false;
  state.phase = "RESULT";
  setResult("Secret test mode disabled.", "Press Enter for next hand, or Z to re-enable.");
  renderAll();
}

function freshDeck() {
  const deck = [];
  for (const suit of SUITS) {
    for (let rank = 1; rank <= 13; rank += 1) {
      deck.push({ rank, suit });
    }
  }
  return deck;
}

function shuffleDeck(deck) {
  for (let i = deck.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
}

function rankCounts(hand) {
  const counts = Array(14).fill(0);
  for (const card of hand) counts[card.rank] += 1;
  return counts;
}

function isStraightFromCounts(counts) {
  for (let start = 1; start <= 9; start += 1) {
    let ok = true;
    for (let r = start; r < start + 5; r += 1) {
      if (counts[r] !== 1) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  const aceLow = counts[1] === 1 && counts[2] === 1 && counts[3] === 1 && counts[4] === 1 && counts[5] === 1;
  const aceHigh = counts[1] === 1 && counts[10] === 1 && counts[11] === 1 && counts[12] === 1 && counts[13] === 1;
  return aceLow || aceHigh;
}

function evaluateHand(hand) {
  const counts = rankCounts(hand);
  const pairs = [];
  let three = false;
  let four = false;
  for (let r = 1; r <= 13; r += 1) {
    if (counts[r] === 2) pairs.push(r);
    if (counts[r] === 3) three = true;
    if (counts[r] === 4) four = true;
  }
  const flush = hand.every((c) => c.suit === hand[0].suit);
  const straight = isStraightFromCounts(counts);
  const royal = counts[1] && counts[10] && counts[11] && counts[12] && counts[13];

  if (straight && flush && royal) return { key: "royalFlush", text: "Royal Flush!", base: 2500 };
  if (straight && flush) return { key: "straightFlush", text: "Straight Flush!", base: 500 };
  if (four) return { key: "fourKind", text: "Four of a Kind!", base: 250 };
  if (three && pairs.length === 1) return { key: "fullHouse", text: "Full House!", base: 80 };
  if (flush) return { key: "flush", text: "Flush!", base: 50 };
  if (straight) return { key: "straight", text: "Straight", base: 40 };
  if (three) return { key: "threeKind", text: "Three of a Kind", base: 30 };
  if (pairs.length === 2) return { key: "twoPair", text: "Two Pair", base: 20 };
  if (pairs.length === 1 && [1, 11, 12, 13].includes(pairs[0])) {
    return { key: "jacksOrBetter", text: "Jacks or Better", base: 10 };
  }
  if (pairs.length === 1) return { key: null, text: "Only a Pair", base: 0 };
  return { key: null, text: "Nothing!", base: 0 };
}

function formatCash(v) {
  return `$${v}`;
}

function renderPaytable() {
  el.paytableList.innerHTML = "";
  for (const row of PAYTABLE) {
    const li = document.createElement("li");
    if (state.highlightedPayKey === row.key) li.classList.add("win");
    li.innerHTML = `<span>${row.name}</span><span>${row.base}</span>`;
    el.paytableList.appendChild(li);
  }
}

function pipPattern(rank) {
  const layouts = {
    1: [[3, 2]],
    2: [[1, 2], [5, 2]],
    3: [[1, 2], [3, 2], [5, 2]],
    4: [[1, 1], [1, 3], [5, 1], [5, 3]],
    5: [[1, 1], [1, 3], [3, 2], [5, 1], [5, 3]],
    6: [[1, 1], [1, 3], [3, 1], [3, 3], [5, 1], [5, 3]],
    7: [[1, 1], [1, 3], [2, 2], [3, 1], [3, 3], [5, 1], [5, 3]],
    8: [[1, 1], [1, 3], [2, 2], [3, 1], [3, 3], [4, 2], [5, 1], [5, 3]],
    9: [[1, 1], [1, 3], [2, 2], [3, 1], [3, 2], [3, 3], [4, 2], [5, 1], [5, 3]],
    10: [[1, 1], [1, 3], [2, 1], [2, 3], [3, 1], [3, 3], [4, 1], [4, 3], [5, 1], [5, 3]],
  };
  return layouts[rank] || [[3, 2]];
}

function renderPipBody(card) {
  const pips = pipPattern(card.rank);
  const symbol = SUIT_SYMBOL[card.suit];
  const pipNodes = pips
    .map(([row, col]) => {
      const invertClass = row >= 4 ? " invert" : "";
      return `<span class="pip${invertClass}" style="grid-row:${row};grid-column:${col};">${symbol}</span>`;
    })
    .join("");
  return `<div class="pip-field">${pipNodes}</div>`;
}

function renderCourtBody(card) {
  const rank = RANK_TEXT[card.rank];
  const label = `${rank} of ${card.suit}`;
  const src = COURT_IMAGE[card.rank];
  return `
    <div class="court-wrap">
      <img class="court-img" src="${src}" alt="${label}" />
    </div>
  `;
}

function renderAceBody(card) {
  return `
    <div class="ace-art">
      <img class="ace-logo ace-logo-center" src="./assets/tahoe-5-logo-1.png" alt="" aria-hidden="true" />
      <div class="ace-ribbon"></div>
    </div>
  `;
}

function renderCardInner(card) {
  if (!card) {
    return '<div class="card-back" aria-hidden="true"></div>';
  }
  const isFace = card.rank === 1 || card.rank >= 11;
  const isAce = card.rank === 1;
  const cornerTop = isFace
    ? `<div class="card-corner top"><span class="rank">${RANK_TEXT[card.rank]}</span><span class="suit">${SUIT_SYMBOL[card.suit]}</span></div>`
    : `<div class="card-corner top"><span class="rank">${RANK_TEXT[card.rank]}</span></div>`;
  const cornerBottom = isFace
    ? `<div class="card-corner bottom"><span class="rank">${RANK_TEXT[card.rank]}</span><span class="suit">${SUIT_SYMBOL[card.suit]}</span></div>`
    : `<div class="card-corner bottom"><span class="rank">${RANK_TEXT[card.rank]}</span></div>`;
  const center = isAce ? renderAceBody(card) : card.rank >= 11 ? renderCourtBody(card) : renderPipBody(card);

  return `
    ${cornerTop}
    <div class="card-body">${center}</div>
    ${cornerBottom}
  `;
}

function renderCards() {
  el.cards.innerHTML = "";
  for (let i = 0; i < 5; i += 1) {
    const card = state.hand[i];
    const column = document.createElement("div");
    column.className = "card-column";
    if (state.hold[i]) column.classList.add("is-held");
    const topMeta = document.createElement("div");
    topMeta.className = "card-meta";
    const slotNumber = document.createElement("div");
    slotNumber.className = "slot-number";
    slotNumber.textContent = state.hold[i] ? "" : String(i + 1);
    const holdStatus = document.createElement("div");
    holdStatus.className = "hold-outside";
    holdStatus.textContent = state.hold[i] ? "HOLD" : "";
    const slot = document.createElement("button");
    slot.type = "button";
    slot.className = "card-slot";
    if (card && ["D", "H"].includes(card.suit)) slot.classList.add("red");
    if (state.phase === "DEALING" && card) slot.classList.add("is-dealing");
    if (state.drawStage[i] === "back") slot.classList.add("is-draw-back");
    if (state.drawStage[i] === "reveal") slot.classList.add("is-draw-reveal");
    slot.setAttribute("aria-label", `Card ${i + 1}`);
    slot.dataset.index = String(i + 1);
    slot.innerHTML = state.drawStage[i] === "back" ? renderCardInner(null) : renderCardInner(card);
    const canToggleHold = state.phase === "HOLD_SELECT" || (state.secretRedrawMode && state.phase === "RESULT");
    slot.disabled = !canToggleHold;
    slot.addEventListener("click", () => toggleHold(i));
    topMeta.appendChild(slotNumber);
    topMeta.appendChild(holdStatus);
    column.appendChild(topMeta);
    column.appendChild(slot);
    el.cards.appendChild(column);
  }
}

function renderStatus() {
  el.betValue.textContent = formatCash(state.bet);
  el.balanceValue.textContent = formatCash(state.balance);
  el.soundBtn.textContent = `Sound: ${state.soundOn ? "On" : "Off"} (S)`;
  el.betUpBtn.disabled = state.phase !== "PRE_DEAL";
  el.betDownBtn.disabled = state.phase !== "PRE_DEAL";
  if (state.phase === "HOLD_SELECT") {
    el.dealDrawBtn.textContent = state.secretRedrawMode ? "Redraw (Enter)" : "Draw (Enter)";
  } else if (state.phase === "RESULT") {
    el.dealDrawBtn.textContent = state.secretRedrawMode ? "Redraw Setup (Enter)" : "Next Hand (Enter)";
  } else if (state.phase === "DEALING") {
    el.dealDrawBtn.textContent = "Dealing...";
  } else if (state.phase === "DRAWING") {
    el.dealDrawBtn.textContent = "Drawing...";
  } else {
    el.dealDrawBtn.textContent = "Deal (Enter)";
  }
  el.dealDrawBtn.disabled = state.phase === "DEALING" || state.phase === "DRAWING";
}

function setResult(main, sub, toneClass = "") {
  el.resultLine.textContent = main;
  el.resultLine.classList.remove("is-win", "is-loss");
  if (toneClass) el.resultLine.classList.add(toneClass);
  el.subLine.textContent = sub;
}

function renderAll() {
  renderStatus();
  renderCards();
  renderPaytable();
}

function startNewRoundState() {
  state.phase = "PRE_DEAL";
  state.deck = [];
  state.top = 0;
  state.hand = [];
  state.hold = [false, false, false, false, false];
  state.drawStage = ["none", "none", "none", "none", "none"];
  state.highlightedPayKey = null;
  renderAll();
}

function adjustBet(delta) {
  if (state.phase !== "PRE_DEAL") return;
  if (delta > 0) {
    if (state.balance >= 10) {
      state.bet += 10;
      state.balance -= 10;
      hiBeep();
    } else {
      invalidBeep();
    }
  } else if (delta < 0) {
    if (state.bet > 10) {
      state.bet -= 10;
      state.balance += 10;
      hiBeep();
    } else {
      invalidBeep();
    }
  }
  renderStatus();
}

function dealHand() {
  if (state.phase !== "PRE_DEAL") return;
  clearDealTimers();
  state.secretRedrawMode = false;
  state.deck = freshDeck();
  shuffleDeck(state.deck);
  state.top = 0;
  state.hand = [null, null, null, null, null];
  state.hold = [false, false, false, false, false];
  state.drawStage = ["none", "none", "none", "none", "none"];
  state.phase = "DEALING";
  state.highlightedPayKey = null;
  setResult("Dealing...", "Cards are on the way.");
  renderAll();
  for (let i = 0; i < 5; i += 1) {
    const timer = setTimeout(() => {
      state.hand[i] = state.deck[state.top];
      state.top += 1;
      state.drawStage[i] = "reveal";
      cardFlipSound();
      renderCards();
      const settle = setTimeout(() => {
        state.drawStage[i] = "none";
        renderCards();
      }, 280);
      dealTimers.push(settle);
      if (i === 4) {
        const done = setTimeout(() => {
          state.phase = "HOLD_SELECT";
          setResult("Select holds, then Draw.", "Press 1-5 or tap cards to toggle HOLD.");
          renderAll();
        }, 290);
        dealTimers.push(done);
      }
    }, 140 * (i + 1));
    dealTimers.push(timer);
  }
}

function toggleHold(i) {
  const canToggleHold = state.phase === "HOLD_SELECT" || (state.secretRedrawMode && state.phase === "RESULT");
  if (!canToggleHold) return;
  state.hold[i] = !state.hold[i];
  holdChime();
  renderCards();
}

function drawHand() {
  if (state.phase !== "HOLD_SELECT") return;
  clearDealTimers();
  ensureDrawCapacity();
  const drawPositions = [];
  for (let i = 0; i < 5; i += 1) if (!state.hold[i]) drawPositions.push(i);
  state.phase = "DRAWING";
  setResult("Drawing...", "Replacing non-held cards.");
  renderAll();

  const step = 240;
  const backDuration = 260;
  const revealDuration = 320;
  for (let order = 0; order < drawPositions.length; order += 1) {
    const i = drawPositions[order];
    const t0 = order * step;
    dealTimers.push(
      setTimeout(() => {
        state.drawStage[i] = "back";
        cardFlipSound();
        renderCards();
      }, t0)
    );
    dealTimers.push(
      setTimeout(() => {
        state.hand[i] = state.deck[state.top];
        state.top += 1;
        state.drawStage[i] = "reveal";
        cardFlipSound();
        renderCards();
      }, t0 + backDuration)
    );
    dealTimers.push(
      setTimeout(() => {
        state.drawStage[i] = "none";
        renderCards();
      }, t0 + backDuration + revealDuration)
    );
  }

  const doneDelay = drawPositions.length > 0 ? (drawPositions.length - 1) * step + backDuration + revealDuration + 20 : 0;
  dealTimers.push(
    setTimeout(() => {
      const result = evaluateHand(state.hand);
      const multiplier = state.bet / 10;
      const payout = Math.round(result.base * multiplier);
      state.highlightedPayKey = result.key;

      if (payout > 0) {
        if (result.base >= 80) {
          greatWinningSound();
        } else if (result.base >= 40) {
          goodWinningSound();
        } else {
          winningSound();
        }
        if (state.secretRedrawMode) {
          setResult(
            `${result.text} Test payout ${formatCash(payout)}.`,
            "Secret test mode: no balance changes. Press Enter to redraw, Z to exit.",
            "is-win"
          );
        } else {
          setResult(`${result.text} You win ${formatCash(payout)}.`, "Press Enter to play the next hand.", "is-win");
        }
      } else {
        losingHandSound();
        if (state.secretRedrawMode) {
          setResult(
            `${result.text} Test payout ${formatCash(0)}.`,
            "Secret test mode: no balance changes. Press Enter to redraw, Z to exit.",
            "is-loss"
          );
        } else {
          setResult(`${result.text} You lose ${formatCash(state.bet)}.`, "Press Enter to play the next hand.", "is-loss");
        }
      }

      if (!state.secretRedrawMode) {
        state.balance += payout;
        state.balance -= 10;
        if (state.balance <= 0) {
          state.balance = 90;
          losingSound();
          const taunt = TAUNTS[Math.floor(Math.random() * TAUNTS.length)];
          setResult("Emergency loan $100!", taunt, "is-loss");
        }
        state.bet = 10;
      }

      state.phase = "RESULT";
      renderAll();
    }, doneDelay)
  );
}

function prepareNextHand() {
  if (state.phase !== "RESULT") return;
  state.secretRedrawMode = false;
  state.phase = "PRE_DEAL";
  state.hand = [];
  state.hold = [false, false, false, false, false];
  state.drawStage = ["none", "none", "none", "none", "none"];
  state.highlightedPayKey = null;
  setResult("Ready for next hand.", "Press Deal to receive five new cards.");
  renderAll();
}

function toggleSound() {
  state.soundOn = !state.soundOn;
  renderStatus();
  if (state.soundOn) startingSound();
}

function openHelp() {
  if (!el.helpDialog.open) el.helpDialog.showModal();
}

function resetSession() {
  state.balance = 90;
  state.bet = 10;
  state.phase = "PRE_DEAL";
  state.secretRedrawMode = false;
  state.hand = [];
  state.deck = [];
  state.top = 0;
  state.hold = [false, false, false, false, false];
  state.drawStage = ["none", "none", "none", "none", "none"];
  state.highlightedPayKey = null;
  clearDealTimers();
  setResult("Session reset.", "Press Deal to start a new game.");
  renderAll();
}

function handleEnter() {
  if (state.phase === "PRE_DEAL") {
    dealHand();
  } else if (state.phase === "HOLD_SELECT") {
    drawHand();
  } else if (state.phase === "RESULT") {
    if (state.secretRedrawMode) {
      state.phase = "HOLD_SELECT";
      setResult("Secret test mode.", "Adjust holds and press Enter to redraw. Press Z to exit.");
      renderAll();
    } else {
      prepareNextHand();
    }
  }
}

function wireEvents() {
  el.dealDrawBtn.addEventListener("click", handleEnter);
  el.betUpBtn.addEventListener("click", () => adjustBet(10));
  el.betDownBtn.addEventListener("click", () => adjustBet(-10));
  el.helpBtn.addEventListener("click", openHelp);
  el.soundBtn.addEventListener("click", toggleSound);

  document.addEventListener("keydown", (e) => {
    const key = e.key;
    if (key === "Enter") {
      e.preventDefault();
      handleEnter();
      return;
    }
    if (key === "Escape") {
      e.preventDefault();
      resetSession();
      return;
    }
    if (key === "h" || key === "H") {
      e.preventDefault();
      openHelp();
      return;
    }
    if (key === "s" || key === "S") {
      e.preventDefault();
      toggleSound();
      return;
    }
    if ((key === "z" || key === "Z") && state.phase === "RESULT") {
      e.preventDefault();
      if (state.secretRedrawMode) {
        exitSecretRedrawMode();
      } else {
        enterSecretRedrawMode();
      }
      return;
    }
    if (state.phase === "PRE_DEAL") {
      if (key === "ArrowUp" || key === "ArrowRight") {
        e.preventDefault();
        adjustBet(10);
      } else if (key === "ArrowDown" || key === "ArrowLeft") {
        e.preventDefault();
        adjustBet(-10);
      }
    }
    if ((state.phase === "HOLD_SELECT" || (state.secretRedrawMode && state.phase === "RESULT")) && /^[1-5]$/.test(key)) {
      e.preventDefault();
      toggleHold(Number(key) - 1);
    }
  });
}

function init() {
  renderPaytable();
  renderAll();
  wireEvents();
}

init();
