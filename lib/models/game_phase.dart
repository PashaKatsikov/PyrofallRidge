/// Top level screen/game state machine.
enum GamePhase {
  /// Game is stopped, showing the title and "Swipe to start" hint.
  ready,

  /// Active gameplay.
  playing,

  /// Gameplay is frozen behind the pause menu.
  paused,

  /// The run is over but the death animation is still playing: the climber is
  /// tumbling, the camera is shaking and the world keeps drawing. Input is
  /// ignored and no overlay is shown yet, so the moment lands before the
  /// results panel covers it.
  dying,

  /// Player died, showing the result and a restart prompt.
  gameOver,
}
