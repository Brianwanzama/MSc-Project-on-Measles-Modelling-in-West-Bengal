# ============================================================
# Makefile — MSc Project Pipeline
# Deep Neural Network Modelling of Endemic Measles Dynamics
# in Post-Vaccination Settings
#
# This file shows the ORDER in which to run the code.
# Run each stage in sequence. Stages 4 and 5 require a GPU
# and take multiple days — run them inside tmux.
#
# QUICK REFERENCE:
#   make stage1    data preparation
#   make stage2    TSIR model
#   make stage3    SFNN model
#   make stage4    final PINN training (100 runs each)
#   make stage5    loss-weight sweep (300 runs)
#   make stage6    collect results
#   make stage7    all figures
#   make help      show this list
# ============================================================

BASE    = $(HOME)/Msc_project
CODE_R  = $(BASE)/code/R
CODE_PY = $(BASE)/code/python/pinn_experiments
SHELL_  = $(BASE)/code

PYTHON  = conda run -n finalmlenv python3
RSCRIPT = Rscript

.PHONY: help stage1 stage2 stage3 stage4 stage5 stage6 stage7 all

# ── HELP ──────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  MSc Project — run stages in order:"
	@echo ""
	@echo "  make stage1   (1) Data preparation"
	@echo "  make stage2   (2) TSIR V1V2 reconstruction"
	@echo "  make stage3   (3) SFNN — 100 runs"
	@echo "  make stage4   (4) Final PINN — 100 runs each model  [GPU, ~5 days]"
	@echo "  make stage5   (5) Loss-weight sweep — 300 runs      [GPU, ~5 days]"
	@echo "  make stage6   (6) Collect sweep results to CSV"
	@echo "  make stage7   (7) Generate all figures"
	@echo ""
	@echo "  make all      run stages 1-3 and 6-7 (not GPU stages)"
	@echo ""

# ── STAGE 1 — DATA PREPARATION ────────────────────────────────
stage1:
	@echo "=== Stage 1: Data preparation ==="
	$(RSCRIPT) $(CODE_R)/01_data_prep/wb_data_prep.R
	@echo "Done."

# ── STAGE 2 — TSIR RECONSTRUCTION ─────────────────────────────
stage2:
	@echo "=== Stage 2: TSIR V1V2 reconstruction ==="
	$(RSCRIPT) $(CODE_R)/01_data_prep/tsir_wb_process_V1V2.R
	$(RSCRIPT) $(CODE_R)/01_data_prep/tsir_wb_run_V1V2.R
	$(RSCRIPT) $(CODE_R)/01_data_prep/tsir_susceptibles_gen_V1V2.R
	@echo "Done."

# ── STAGE 3 — SFNN ────────────────────────────────────────────
stage3:
	@echo "=== Stage 3: SFNN — 100 runs ==="
	bash $(SHELL_)/wb_full_basic_optimal_V1V2.sh
	@echo "Done."

# ── STAGE 4 — FINAL PINN TRAINING ─────────────────────────────
# NaivePINN (GPU 0) and constrained TSIR-PINN (GPU 1)
# 100 runs each, 2500 epochs per run
# Runtime: ~65 hours per model
# Run inside tmux: tmux new-session -s pinn_final
stage4:
	@echo "=== Stage 4: Final PINN training ==="
	@echo "    NaivePINN v3  → GPU 0"
	@echo "    TSIR-PINN v3  → GPU 1"
	@echo "    100 runs each, ~65 hours per model"
	@echo "    Recommend: tmux new-session -s pinn_final"
	bash $(SHELL_)/wb_run_pinn_final.sh
	@echo "Done."

# ── STAGE 5 — LOSS-WEIGHT SWEEP ───────────────────────────────
# Unconstrained TSIR-PINN at 3 ratios x 100 runs
# Ratios: 10 (below), 35 (at), 10000 (above) beta_eq
# Runtime: ~130 hours total
# Run inside tmux: tmux new-session -s pinn_sweep
stage5:
	@echo "=== Stage 5: Loss-weight sweep ==="
	@echo "    Ratios: 10 | 35 | 10000"
	@echo "    100 runs per ratio, ~130 hours total"
	@echo "    Recommend: tmux new-session -s pinn_sweep"
	bash $(SHELL_)/wb_run_pinn_sweep.sh
	@echo "Done."

# ── STAGE 6 — COLLECT RESULTS ─────────────────────────────────
stage6:
	@echo "=== Stage 6: Collect sweep results ==="
	$(PYTHON) $(CODE_PY)/wb_collect_sweep_results.py
	$(PYTHON) $(CODE_PY)/wb_extract_s_latent.py
	@echo "Done. Tables in experiments/tables/"

# ── STAGE 7 — FIGURES ─────────────────────────────────────────
stage7:
	@echo "=== Stage 7: Generate figures ==="
	$(RSCRIPT) $(CODE_R)/02_figures/wb_city_rmse_pub.R
	$(RSCRIPT) $(CODE_R)/02_figures/wb_pinn_final_analysis.R
	$(RSCRIPT) $(CODE_R)/02_figures/wb_pinn_sweep_fig.R
	$(RSCRIPT) $(CODE_R)/02_figures/wb_s_latent_fig.R
	$(RSCRIPT) $(CODE_R)/03_counterfactual/wb_counterfactual_all_cities.R
	@echo "Done. Figures in experiments/figures/"

# ── ALL (skips GPU stages 4 and 5) ───────────────────────────
all: stage1 stage2 stage3 stage6 stage7
	@echo "Pipeline complete (GPU stages 4-5 skipped)."
