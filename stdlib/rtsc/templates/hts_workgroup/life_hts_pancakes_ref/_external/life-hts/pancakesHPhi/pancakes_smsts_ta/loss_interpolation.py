import sys
import numpy as np
from scipy.interpolate import PchipInterpolator

# this script is called within the GetDP resolution to perform loss interpolation from analyzed tapes to the whole pancake

print_in_txt_files = True

if len(sys.argv) < 5:
    print("Should have at least 4 arguments: num_pancakes, num_tapes, num_analyzed_tapes, <tape_id_list>")
    sys.exit(1)
else:
    num_pancakes = int(sys.argv[1])
    num_tapes = int(sys.argv[2])
    num_analyzed_tapes = int(sys.argv[3])
    analyzed_tape_ids = []
    for i in range(num_analyzed_tapes):
        analyzed_tape_ids.append(int(sys.argv[4 + i]))

res_folder = f'res/smsts_{num_pancakes}_pancakes_{num_analyzed_tapes}_tapes_out_of_{num_tapes}'

smsts_analyzed_tape_IDs = np.array(analyzed_tape_ids)
all_tapes_IDS = np.arange(1, num_tapes + 1)

total_losses = 0
time = 0. # will be updated
first_time_step = False
for i in range(num_pancakes):
    pancake_analyzed_tapes_losses = np.zeros((num_analyzed_tapes, 1))
    for j in range(num_analyzed_tapes):
        tapeID = i*num_analyzed_tapes + j + 1
        sim_data = np.loadtxt(res_folder + '/power_ts_' + str(tapeID) + '.txt', delimiter=" ", usecols=[1, 2])
        if(sim_data.ndim == 1): #1D array because first time-step
            pancake_analyzed_tapes_losses[j] = sim_data[-1]
            if(i == 0 and j == 0):
                time = sim_data[0]
                first_time_step = True
        else:
            pancake_analyzed_tapes_losses[j] = sim_data[-1, 1]
            if(i == 0 and j == 0):
                time = sim_data[-1, 0]

    pchip_interpolator = PchipInterpolator(smsts_analyzed_tape_IDs, pancake_analyzed_tapes_losses)
    pancake_losses = pchip_interpolator(all_tapes_IDS).sum()
    total_losses += pancake_losses

    if(print_in_txt_files):
        if(first_time_step):
            file_process_type = "w"
        else:
            file_process_type = "a"
        with open(f"res/smsts_{num_pancakes}_pancakes_{num_analyzed_tapes}_tapes_out_of_{num_tapes}/powerPancake_{i+1}.txt", file_process_type) as f:
            f.write(f"{time:.5f} {pancake_losses:.12f}\n")

    #print(f"Pancake {i+1} losses: {pancake_losses:.12f} W/m")
print(f"Total losses: {total_losses:.5f} W/m at t = {time:.5f} s")

if(print_in_txt_files):
    if(first_time_step):
        file_process_type = "w"
    else:
        file_process_type = "a"
    with open(f"res/smsts_{num_pancakes}_pancakes_{num_analyzed_tapes}_tapes_out_of_{num_tapes}/powerTOT.txt", file_process_type) as f:
        f.write(f"{time:.5f} {total_losses:.5f}\n")