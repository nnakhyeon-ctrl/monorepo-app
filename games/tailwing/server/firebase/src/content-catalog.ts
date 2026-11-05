// Stable content IDs; verified subscription state is still checked server-side.
export const freeContent = ['aurora', 'pilot', 'rion', 'eden', 'standard', 'barrier'] as const;
export const subscriptionContent = ['vector', 'safeguard', 'focus', 'mecha', 'pulse',
  'rion', 'eden', 'echo', 'prism', 'tuner', 'signature', 'tw_bear', 'tw_otter', 'tw_owl',
  'tw_squirrel', 'tw_hedgehog', 'tw_penguin', 'tw_chameleon', 'tw_eagle', 'tw_volt',
  'missile_storm', 'beam', 'absorb', 'blackhole', 'emp', 'chain',
  'petal_orbit', 'aurora_sweep', 'landing_beacon', 'gyro', 'capacitor', 'safety_cell'] as const;
// rion/eden stay in old paid ownership replies for compatibility; now also free.
