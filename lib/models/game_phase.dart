/// Top level screen/game state machine.
enum GamePhase {
  /// Game is stopped, showing the title and "Swipe to start" hint.
  ready,

  /// Active gameplay.
  playing,

  /// Gameplay is frozen behind the pause menu.
  paused,

  /// Player died, showing the result and a restart prompt.
  gameOver,
}
