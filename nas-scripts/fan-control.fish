#!/usr/bin/env fish

# Set fan mode: raw 0x30 0x45 0x01 [x]
# [x] Modes:      CPU Zone  Peripheral Zone
#                 Target    Target 
# -------------   --------  ---------------
# 00  Standard    50%      50%
# 01  Full        100%     100%
# 02  Optimal     30%      30%
# 04  Heavy I/O   50%      75%
sudo ipmitool raw 0x30 0x45 0x01 0x02
