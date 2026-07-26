/* eedn — zero-latency multiband downward-expander denoiser DSP
 *
 * Bertom Denoiser Classic–style: time-domain only (no FFT), 6 bands,
 * master threshold, per-band max reduction ("range"), HF bias, stereo link.
 */
#ifndef EEDN_DSP_H
#define EEDN_DSP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define EEDN_BANDS 6

typedef struct {
  float threshold_db;   /* 0 .. -140  (higher = more sensitive / more NR) */
  float range_db[EEDN_BANDS]; /* 0 .. 24  max reduction per band */
  float center_hz[EEDN_BANDS]; /* band center frequencies (Hz), must increase */
  float freq_low_hz;    /* edge HPF (derived from centers if 0) */
  float freq_high_hz;   /* edge LPF (derived from centers if 0) */
  float hf_bias;        /* 0..1  pass HF harmonics/transients more easily */
  float stereo_link;    /* 0..1  0=independent, 1=fully linked envelopes */
  float attack_ms;      /* envelope attack */
  float release_ms;     /* envelope release */
  float knee_db;        /* soft knee width */
  float ratio;          /* expander ratio (>= 1) */
  int   hpf_enable;     /* cut below freq_low */
  int   lpf_enable;     /* cut above freq_high */
  int   bypass;
  /* Post-denoise noise gate: hard-mute when only idle residual remains. */
  int   gate_enable;
  float gate_threshold_db;  /* open when envelope exceeds this (dBFS) */
  float gate_hysteresis_db; /* close below threshold - hysteresis */
  float gate_attack_ms;
  float gate_hold_ms;
  float gate_release_ms;
  float gate_range_db;      /* attenuation when closed (e.g. 100 = mute) */
} EednParams;

typedef struct EednState EednState;

EednState *eedn_create(void);
void eedn_destroy(EednState *s);
void eedn_reset(EednState *s, double sample_rate);
void eedn_set_params(EednState *s, const EednParams *p);

/* Process interleaved stereo (LRLR…) or separate channel buffers. */
void eedn_process(EednState *s,
                  const float *in_l, const float *in_r,
                  float *out_l, float *out_r,
                  uint32_t n_samples);

/* Metering helpers (dB). Call after process. */
float eedn_meter_input_peak_db(const EednState *s);
float eedn_meter_input_min_db(const EednState *s);
float eedn_meter_gr_min_db(const EednState *s, int band); /* most reduction (more negative) */
float eedn_meter_gr_max_db(const EednState *s, int band); /* least reduction (closest to 0) */

void eedn_default_params(EednParams *p);

#ifdef __cplusplus
}
#endif

#endif /* EEDN_DSP_H */
