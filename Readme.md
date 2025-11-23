# Wideband & Low-Bitrate Speech Coding Implementation (LPC, Voice-Excited & CELP)

**Course:** EE623 - Speech Processing  
**Assignment:** 2  
**Date:** November 2025  

---

## **Project Overview**
This repository contains the MATLAB implementation for a comparative study of speech coding techniques. The project explores the trade-offs between bitrate, computational complexity, and perceptual quality across three specific vocoder architectures:

1.  **Plain LPC Vocoder:** A low-bitrate source-filter model using synthetic excitation.
2.  **Voice-Excited LPC Vocoder:** A higher-quality model transmitting compressed residuals.
3.  **CELP (Code-Excited Linear Prediction):** An Analysis-by-Synthesis coder targeting telephony quality at ~13 kbps.

## **Objectives**

### **Objective 1: Wideband Source-Filter Vocoders**
* **Goal:** Compare traditional LPC-10 against Voice-Excited LPC strategies.
* **Plain LPC:** Uses an impulse train/white noise model with phase-continuous synthesis. Target: **< 8 kbps**.
* **Voice-Excited LPC:** Uses DCT compression on the residual signal with High-Frequency Regeneration (HFR). Target: **< 16 kbps**.

### **Objective 2: Low-Bitrate CELP (13 kbps)**
* **Goal:** Implement a robust narrowband coder using Analysis-by-Synthesis.
* **Configuration:**
    * **Sampling Rate:** 8000 Hz (Resampled from wideband).
    * **Frame Structure:** 20 ms frames with **8 subframes** (2.5 ms resolution) for high-fidelity tracking.
    * **Quantization:** 12th-order LPC (LSF), Logarithmic Gain Quantization, and Stochastic Codebook search.
    * **Target Bitrate:** **~13.4 kbps**.

---

## **Repository Structure**

```text
.
├── celp13k.m              # Core function for CELP codec (Analysis & Synthesis logic)
├── objective2_runner.m    # Master script for Objective 2 (CELP Bitrate, PESQ, SegSNR)
├── vocoders.m             # Master script for Objective 1 (Plain vs. Voice-Excited LPC)
│
├── celpana.m              # Helper: CELP Analysis/Encoder
├── celpsyn.m              # Helper: CELP Synthesis/Decoder
├── proclpc.m              # Helper: LPC Analysis (Levinson-Durbin)
├── synlpc_plain.m         # Helper: Plain LPC Synthesis (Phase Continuous)
├── synlpc_voice.m         # Helper: Voice-Excited Synthesis (HFR)
│
├── pesqbin.m              # Utility: MATLAB Wrapper for PESQ executable
├── segsnr.m               # Utility: Segmental SNR Calculator
├── vec2frames.m           # Utility: Frame blocking helper
│
├── pesq.exe               # (Required) External ITU-T P.862 Binary for PESQ scores
└── *.wav                  # Input audio files (male1, male2, female1, female2)

