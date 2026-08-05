/// The two vertical lanes the player can occupy.
enum Lane { left, right }

extension LaneX on Lane {
  Lane get opposite => this == Lane.left ? Lane.right : Lane.left;
}
