function fan-control --argument-names level
	switch $level
		case standard
			sudo ipmitool raw 0x30 0x45 0x01 0x00

		case full
			sudo ipmitool raw 0x30 0x45 0x01 0x01

		case optimal
			sudo ipmitool raw 0x30 0x45 0x01 0x02

		case io
			sudo ipmitool raw 0x30 0x45 0x01 0x03

		case '*'
			echo "usage: fan-control [level]"
			echo "levels: standard,full,optimal,io"
			echo "[x] Modes:      CPU Zone  Peripheral Zone"
			echo "                Target    Target "
			echo "-------------   --------  ---------------"
			echo "00  Standard    50%      50%"
			echo "01  Full        100%     100%"
			echo "02  Optimal     30%      30%"
			echo "04  Heavy I/O   50%      75%"
	end
end

