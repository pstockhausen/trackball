#pragma once

// Type-safe clamp: returns val clamped to [lo, hi].
template<typename T>
inline T clamp(T val, T lo, T hi) { return val > hi ? hi : (val < lo ? lo : val); }
