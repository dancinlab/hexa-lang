# ATLAS/hypotheses/verify_h_rob_4

H-ROB-4: PureField = Proprioception
Simulated walking controller with proprioception vs vision split.
Tests if field-only (proprioception) >> eq-only (vision) for gait prediction.

## Function `generate_gait_data`

Generate realistic walking joint angle patterns.

Joint angles follow sinusoidal patterns with phase offsets.
Ground contact is binary (heel strike to toe off).
Vision provides distance to next obstacle.

## Function `extract_features`

Extract features based on mode.

full: all channels (proprioception + vision)
field: proprioception only (joints + velocities + contacts)
eq: vision only (distance + slope)

## Function `train_linear_predictor`

Train a simple linear predictor: target = W @ features + b.
Uses gradient descent. Returns final MSE on train set.

