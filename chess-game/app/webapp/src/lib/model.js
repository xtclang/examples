// Documentation data for the Guide page's description of the Insights move-choice model.
//
// The model itself -- scoring positions, fitting the softmax policy -- now runs on the server
// (see ModelApi.x / MoveModel.x). These weights describe that same model and must be kept in
// sync with MoveModel.x's MATERIAL_W / PLACEMENT_W / STRUCTURE_W / SHIELD_W / RESTRAINT_W /
// TEMPO_W / EXPOSURE_W if that model ever changes.

/** The six features, with the weights that turn them into pawns. */
export const FEATURES = [
  { key: 'material',  label: 'Material',       symbol: 'φ₁', w:  0.010, unit: 'cp',
    note: 'Σ own piece values − Σ opponent piece values' },
  { key: 'placement', label: 'Placement',      symbol: 'φ₂', w:  0.010, unit: 'cp',
    note: 'Piece-square table, own − opponent' },
  { key: 'structure', label: 'Pawn structure', symbol: 'φ₃', w: -0.180, unit: 'pawns',
    note: 'Doubled + isolated pawns, own − opponent' },
  { key: 'shield',    label: 'King shield',    symbol: 'φ₄', w:  0.140, unit: 'pawns',
    note: 'Own pawns guarding own king, own − opponent' },
  { key: 'restraint', label: 'Restraint',      symbol: 'φ₅', w: -0.015, unit: 'replies',
    note: 'Legal replies left to the opponent' },
  { key: 'tempo',     label: 'Tempo',          symbol: 'φ₆', w:  0.300, unit: '0 / 1',
    note: '1 when the move gives check' },
  { key: 'exposure',  label: 'Exposure',       symbol: 'φ₇', w: -0.010, unit: 'cp',
    note: 'Most material the opponent can win by exchange in reply' },
];
