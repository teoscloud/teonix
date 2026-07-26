PREFIX        ?= $(HOME)/.local
LIBDIR        ?= $(PREFIX)/lib
LV2DIR        ?= $(LIBDIR)/lv2
LADSPADIR     ?= $(LIBDIR)/ladspa
SHAREDIR      ?= $(PREFIX)/share/eedn-denoiser

CC            ?= gcc
CFLAGS        ?= -O3 -ffast-math -fPIC -Wall -Wextra -std=c11
CFLAGS        += $(shell pkg-config --cflags lv2 2>/dev/null)
LDFLAGS       ?=
LIBS          ?= -lm

SRC_DSP       := src/dsp.c
SRC_LV2       := src/lv2_plugin.c
SRC_LADSPA    := src/ladspa_plugin.c

BUILD         := build
LV2_BUNDLE    := $(BUILD)/eedn.lv2
LV2_SO        := $(LV2_BUNDLE)/eedn.so
LADSPA_SO     := $(BUILD)/eedn_denoiser.so

SMOKE := $(BUILD)/smoke_test

.PHONY: all clean install uninstall test-load smoke

all: $(LV2_SO) $(LADSPA_SO)

smoke: $(SMOKE)
	$(SMOKE)

$(SMOKE): src/dsp.c src/smoke_test.c | $(BUILD)
	$(CC) $(CFLAGS) -Isrc -o $@ src/dsp.c src/smoke_test.c $(LDFLAGS) $(LIBS)

$(BUILD):
	mkdir -p $(BUILD)

$(LV2_BUNDLE): $(BUILD)
	mkdir -p $(LV2_BUNDLE)
	cp lv2/eedn.lv2/manifest.ttl lv2/eedn.lv2/eedn.ttl $(LV2_BUNDLE)/

$(LV2_SO): $(SRC_DSP) $(SRC_LV2) $(LV2_BUNDLE)
	$(CC) $(CFLAGS) -shared -o $@ $(SRC_DSP) $(SRC_LV2) $(LDFLAGS) $(LIBS)

$(LADSPA_SO): $(SRC_DSP) $(SRC_LADSPA) | $(BUILD)
	$(CC) $(CFLAGS) -Isrc -shared -o $@ $(SRC_DSP) $(SRC_LADSPA) $(LDFLAGS) $(LIBS)

install: all
	mkdir -p $(LV2DIR)/eedn.lv2 $(LADSPADIR) $(SHAREDIR)/presets $(SHAREDIR)/pipewire
	cp -f $(LV2_BUNDLE)/* $(LV2DIR)/eedn.lv2/
	cp -f $(LADSPA_SO) $(LADSPADIR)/
	cp -f presets/* $(SHAREDIR)/presets/
	cp -f pipewire/eedn-pcm2902-mic.conf pipewire/eedn-denoise-sink.conf $(SHAREDIR)/pipewire/
	@echo "Installed LV2  → $(LV2DIR)/eedn.lv2"
	@echo "Installed LADSPA → $(LADSPADIR)/eedn_denoiser.so"
	@echo "Installed presets/conf → $(SHAREDIR)"
	@echo "Add to env if needed:"
	@echo "  export LV2_PATH=\"$(LV2DIR):\$$LV2_PATH\""
	@echo "  export LADSPA_PATH=\"$(LADSPADIR):\$$LADSPA_PATH\""

uninstall:
	rm -rf $(LV2DIR)/eedn.lv2
	rm -f $(LADSPADIR)/eedn_denoiser.so

test-load: install
	@command -v lv2ls >/dev/null && lv2ls | grep -i eedn || echo "lv2ls not available; skip LV2 list"
	@command -v listplugins >/dev/null && listplugins 2>/dev/null | grep -i eedn || true

clean:
	rm -rf $(BUILD)
