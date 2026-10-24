import { FEATURES } from '../lib/model.js';

const TOC = [
  { id: 'play', label: 'How to play' },
  { id: 'reading', label: 'Reading the insights' },
  { id: 'position', label: 'This position' },
  { id: 'game', label: 'Your game' },
  { id: 'thinking', label: 'How you think' },
  { id: 'learn', label: 'Learning from a game' },
  { id: 'model', label: 'The model, in full' },
  { id: 'sources', label: 'Where the numbers come from' },
];

/** One metric: what it is, how it is worked out, how to read it, and what it is good for. */
function MetricDoc({ name, what, formula, read, helps }) {
  return (
    <article className="doc-metric">
      <h4>{name}</h4>
      <p className="doc-what">{what}</p>
      {formula && <p className="formula">{formula}</p>}
      <dl>
        <div>
          <dt>Reading it</dt>
          <dd>{read}</dd>
        </div>
        <div>
          <dt>Why it helps</dt>
          <dd>{helps}</dd>
        </div>
      </dl>
    </article>
  );
}

export default function Guide({ onPlay }) {
  return (
    <div className="guide">
      <header className="guide-hero">
        <div>
          <h1>Play the engine. Then see how you think.</h1>
          <p>
            Chess Playground pits you against Stockfish and, while you play, measures two
            things: how good each move was, and how you arrived at it. This page explains every
            number on the screen and how to turn them into better chess.
          </p>
          <button className="btn btn-primary" onClick={onPlay}>
            Start playing
          </button>
        </div>
      </header>

      <div className="guide-layout">
        <nav className="guide-toc" aria-label="On this page">
          <p>On this page</p>
          <ol>
            {TOC.map((t) => (
              <li key={t.id}>
                <a href={`#${t.id}`}>{t.label}</a>
              </li>
            ))}
          </ol>
        </nav>

        <div className="guide-body">
          <section id="play">
            <h2>How to play</h2>
            <ol className="steps">
              <li>
                <strong>You are White.</strong> Click one of your pieces. Dots mark the squares it
                can reach; a ring marks a piece it can capture.
              </li>
              <li>
                <strong>Click a dot to move.</strong> The piece moves at once. The engine — Stockfish,
                through the server — takes about three seconds to think, then its piece glides into
                place.
              </li>
              <li>
                <strong>Pick a clock</strong> under the board: none, 5 minutes, or 10 minutes plus 5
                seconds a move. Starting a new game resets the board.
              </li>
              <li>
                <strong>Look back any time.</strong> Click a move on the scoresheet, or any bar or
                point in a chart, and the board shows that position. <em>Back to the game</em> returns
                you to play; the engine waits.
              </li>
              <li>
                <strong>Just want to play?</strong> The arrow at the top of the insights hides them
                and gives the board the whole screen.
              </li>
            </ol>
            <p>
              <strong>Review</strong> mode loads anyone’s recent games from chess.com by username —
              or the daily puzzle — and shows the same insights for both players.
            </p>
          </section>

          <section id="reading">
            <h2>Reading the insights</h2>
            <p>
              The panel beside the board is split into sections you can fold away. Every number is
              live: the engine evaluates one position every second and a half — that is as fast as
              the free service allows — starting with the one on the board, then sketching the rest
              of the game end to end and filling in the gaps. Each position is asked about once and
              remembered, so a new move costs one request, not the whole game again.
            </p>
            <p>
              While a value is still on its way you will see a soft placeholder rather than a zero.
              The <em>Live</em> pill at the top says when everything is up to date; clicking it
              pauses the engine.
            </p>
          </section>

          <section id="position">
            <h2>This position</h2>
            <p className="section-lede">About the position on the board right now, before the next move.</p>

            <MetricDoc
              name="Engine evaluation"
              what="Stockfish’s verdict on the position, in pawns, from White’s side."
              formula="+1.00 ≈ White is a pawn up in effect · −1.00 ≈ Black is · ±12 marks a forced mate"
              read="Under ±0.3 is level. Up to ±1 is a small edge, ±1 to ±2.5 a clear one, beyond that winning. The bar beneath splits the win chance between the two sides."
              helps="It tells you whether you should be pressing or holding — and after a move, whether it changed anything. Stockfish’s own move is shown beside it."
            />
            <MetricDoc
              name="Win chance"
              what="The evaluation turned into a probability of winning, as a split bar."
              formula="win% = 50 + 50 · (2 / (1 + e^(−0.00368 · centipawns)) − 1)"
              read="Pawns are not linear: going from +0.5 to +1.5 matters far more than +8.5 to +9.5. Win chance flattens that out, which is why mistakes are judged in it."
              helps="It makes a lost pawn mean what it actually means in this position."
            />
            <MetricDoc
              name="Legal moves"
              what="How many moves are possible here — the branching factor."
              read="Twenty at the start, thirty to forty in a busy middlegame, a handful in an endgame or when in check."
              helps="More moves means more to check before you commit. It is the raw size of the choice."
            />
            <MetricDoc
              name="Uncertainty"
              what="How open the choice is, in bits: the entropy of the model’s move probabilities."
              formula="H = −Σ P(move) · log₂ P(move)"
              read="Zero bits means one move is obvious. log₂(legal moves) — about 4.3 bits with 20 moves — means every move looks the same. Most real positions sit in between."
              helps="High uncertainty is where games are decided. Spend your time here, not on recaptures."
            />
            <MetricDoc
              name="Real options"
              what="The uncertainty turned back into a number of moves."
              formula="real options = 2^H"
              read="Of 35 legal moves, maybe 6 are genuinely worth considering. This is that 6."
              helps="It is a candidate-move list size. If you consistently look at fewer, you will miss things."
            />
            <MetricDoc
              name="Model’s pick"
              what="The move the thinking model rates highest, and how likely it thinks it is."
              read="Not the engine’s choice — a human-like guess from simple features (material, piece placement, king safety, threats)."
              helps="When it differs from what you play, ask why. When it differs from the engine, the position has something subtle in it."
            />
          </section>

          <section id="game">
            <h2>Your game</h2>
            <p className="section-lede">How well each move was played, judged by the engine.</p>

            <MetricDoc
              name="Accuracy"
              what="The average quality of your moves, from 0 to 100%."
              formula="accuracy = 103.17 · e^(−0.0435 · win% lost) − 3.17, averaged over your moves"
              read="A move that keeps the win chance scores 100. Giving up 10 points scores about 62; 30 points about 24. Club players tend to land in the 70s and 80s."
              helps="One number to track from game to game. It moves slowly — that is the point."
            />
            <MetricDoc
              name="Average centipawn loss"
              what="How much evaluation, in hundredths of a pawn, you lost per move on average."
              formula="ACPL = 100 · mean(max(0, eval before − eval after)), from your side"
              read="Under 20 is excellent, 30–50 solid, above 80 shaky. It punishes one blunder hard."
              helps="The classic measure, comparable with what other sites publish."
            />
            <MetricDoc
              name="Engine’s move"
              what="How often your move was exactly the one Stockfish would have played."
              read="30–50% is normal for strong club play. Many good moves are not the engine’s first choice."
              helps="Read it next to accuracy: low match with high accuracy means a different but sound style."
            />
            <MetricDoc
              name="Inaccuracies, mistakes, blunders"
              what="Moves that gave away at least 10, 20 or 30 points of win chance."
              read="Counted in win chance, not pawns: dropping two pawns at +8 is not a blunder; dropping one at 0 might be."
              helps="These are the moves to study. Everything else is noise."
            />
            <MetricDoc
              name="Worst move"
              what="The single move that cost the most win chance, and how much."
              read="Click it in the table or the chart to put the position on the board."
              helps="If you only study one move from a game, study this one."
            />
            <MetricDoc
              name="Evaluation chart"
              what="The engine’s evaluation after every move, blue above the line for White, red below for Black."
              read="Steep drops are mistakes; long flat stretches are quiet manoeuvring; a curve that crosses the line is a game that changed hands."
              helps="The shape of the game at a glance — where it was won and lost."
            />
            <MetricDoc
              name="Cost of each move"
              what="Win chance thrown away by each of your moves, with the three thresholds drawn as labelled lines."
              read="Tall bars are bad moves; the line a bar crosses names it. A cluster of bars means a bad spell, not bad luck."
              helps="Find the phase of the game where you go wrong — opening, middlegame, or converting."
            />
          </section>

          <section id="thinking">
            <h2>How you think</h2>
            <p className="section-lede">
              A mathematical model of your choices: not whether a move was good, but how predictable
              it was and what that says about how you choose.
            </p>

            <MetricDoc
              name="Decisiveness β̂"
              what="How sharply you prefer moves the model rates highly. The model’s one free parameter, fitted to the moves you actually played."
              formula="β̂ = argmax Σ log P(your move)"
              read="Near 0, your moves look random to the model. Around 1–3 you follow its values with some freedom. Higher is very consistent."
              helps="It rises as your play gets more principled. Watch it across many games, not one."
            />
            <MetricDoc
              name="Options weighed"
              what="The perplexity of the model on your moves: how many moves it effectively had to pick from to explain you."
              formula="options weighed = 2^(mean surprise)"
              read="Compare it with the average legal moves. 8 of 30 means you choose from a tight, consistent set."
              helps="A small number with good accuracy means good instincts; a small number with poor accuracy means a blind spot."
            />
            <MetricDoc
              name="Mean surprise"
              what="How unexpected your moves were, in bits, on average."
              formula="surprise = −log₂ P(your move)"
              read="One bit is a coin flip’s worth of surprise. The note shows how many bits better than picking at random the model does."
              helps="It falls as your choices become more predictable from the position — a sign of understanding, not of being easy to beat."
            />
            <MetricDoc
              name="Model’s first choice"
              what="How often you played the model’s top-rated move, and how often one of its top three."
              read="Top three above 50% means the model reads your priorities well."
              helps="When you play outside its top three and the engine agrees with you, you saw something the simple features miss."
            />
            <MetricDoc
              name="Surprise and uncertainty chart"
              what="Bars: the surprise of each move. Line: the uncertainty of the position it was played in."
              read="A bar well above the line is a move the position did not call for. A bar below it is the natural move."
              helps="High surprise in a clear position, followed by a tall cost bar, is the signature of a missed tactic."
            />
            <MetricDoc
              name="Complexity chart"
              what="Legal moves each side had at every turn."
              read="Peaks are open, tactical positions; troughs are forced sequences and endgames."
              helps="Lay it over the cost chart. If your mistakes sit on the peaks, slow down when the position opens up."
            />
          </section>

          <section id="learn">
            <h2>Learning from a game</h2>
            <ol className="steps">
              <li>
                <strong>Play a full game.</strong> Don’t look at the numbers while you play — fold the
                insights away with the arrow if they distract you.
              </li>
              <li>
                <strong>Find the turning points.</strong> Open <em>Every move</em> and sort by{' '}
                <em>Win lost</em>. The top two or three rows are the game.
              </li>
              <li>
                <strong>Go back to the position before each one.</strong> Click the row. Before reading
                anything, choose the move you would play now.
              </li>
              <li>
                <strong>Compare.</strong> The evaluation card shows what Stockfish wanted. <em>The
                choice here</em> shows what the model expected and where your move ranked. If the
                engine’s move was not in the model’s top few either, it was hard; if it was, you missed
                something you would normally see.
              </li>
              <li>
                <strong>Name the pattern.</strong> A high-surprise, high-cost move is usually a tactic
                you didn’t calculate. A low-surprise, high-cost move is a natural-looking mistake — the
                kind worth memorising.
              </li>
              <li>
                <strong>Watch the trends.</strong> Accuracy and decisiveness move slowly. Compare across
                games, not moves.
              </li>
              <li>
                <strong>Learn from others.</strong> In <em>Review</em>, load a strong player’s games and
                look at their profile: how decisive they are, how few options they really weigh, and
                where in their games the complexity peaks.
              </li>
            </ol>
          </section>

          <section id="model">
            <h2>The model, in full</h2>
            <p>
              The thinking model runs in your browser. It values a position with seven simple
              features, then assumes you pick moves the way a person under time pressure does: usually
              the best-looking one, sometimes another, in proportion to how good each looks.
            </p>
            <div className="formulas">
              <p className="formula">V(p) = Σᵢ wᵢ · φᵢ(p) — the value of a position, from the mover’s side</p>
              <p className="formula">P(m | p) = e^(β·V(p∘m)) / Σₘ′ e^(β·V(p∘m′)) — a softmax policy over the legal moves</p>
              <p className="formula">β̂ = argmax_β Σₜ log P(mₜ | pₜ) — fitted to the moves actually played</p>
              <p className="formula">H(p) = −Σ P log₂ P · S(m) = −log₂ P(m) · options = 2^(mean S)</p>
            </div>
            <p>
              The log-likelihood is concave in β, so a simple search finds the single best fit. A
              neat consequence: at that fit, your mean surprise equals your mean uncertainty exactly —
              setting the derivative to zero forces the expected and actual values to balance. The
              charts therefore show the move-by-move gap between the two, which is where the
              information is.
            </p>
            <table className="features">
              <caption>The seven features and their weights</caption>
              <thead>
                <tr>
                  <th scope="col">φ</th>
                  <th scope="col">Feature</th>
                  <th scope="col">w</th>
                  <th scope="col">Measured as</th>
                </tr>
              </thead>
              <tbody>
                {FEATURES.map((f) => (
                  <tr key={f.key}>
                    <td>{f.symbol}</td>
                    <td>{f.label}</td>
                    <td className="num">{f.w}</td>
                    <td>
                      {f.note} ({f.unit})
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p>
              <strong>Model fit</strong>, at the bottom of the insights, regresses the engine’s
              evaluation on the model’s value across the game. r² near 1 means the model tracks the
              engine closely; the slope says how far apart their scales are. It will never be perfect:
              the model sees one move ahead, Stockfish many. That gap is the point — it is a model of a
              person, not a search.
            </p>
          </section>

          <section id="sources">
            <h2>Where the numbers come from</h2>
            <ul className="sources">
              <li>
                <strong>The engine’s moves and evaluations</strong> come from Stockfish Online, through
                this server’s <code>/api/engine</code> proxy. Nothing chooses the computer’s moves
                locally.
              </li>
              <li>
                <strong>The thinking model</strong> runs entirely in your browser.
              </li>
              <li>
                <strong>Win chance and accuracy</strong> use the formulas Lichess publishes, so they
                compare with what you see there.
              </li>
              <li>
                <strong>Games to review</strong> come from chess.com’s public API, through the server’s{' '}
                <code>/api/chesscom</code> proxy.
              </li>
              <li>
                <strong>Evaluations are remembered</strong> in your browser, so returning to a game is
                instant and the shared engine is not asked twice.
              </li>
            </ul>
          </section>
        </div>
      </div>
    </div>
  );
}
