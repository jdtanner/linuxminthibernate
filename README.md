These scripts enable hibernate in Linux Mint 22.2 and disable suspend (useful if you have a  laptop that only supports modern suspend).

It is advisable to ensure the following:

1. You create a swap **partition** 1.25x the size of your ram before running this script.
2. Ensure that the swap partition is formatted as swap; do not reuse an existing swap partition as this may have a stale resume state if you have played with hibernation before.
3. Check the command blkid before you run the script, and note the uuid of the device on which your swap partition exists (not the uuid of the swap partition itself).

If you have any doubts whatsoever, do not run this script! Download it and read what it does first!

Run the scripts in order, 1 then 2. 

1 enables hibernate; reboot after it has run.
2 disables suspend (modern suspend doesn't work on a lot of laptops)

Best of luck!
John H-T
