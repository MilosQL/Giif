# Known problems

This document provides descriptions of common bugs and issues that end-users may come across. It's likely that eventual upgrades of the underlying components, such as the Guacamole portal and iDRAC firmware, will resolve some of the issues mentioned here.


## Distorted picture on iDRAC based servers

From time to time, you may encounter a distorted console screen image:

![distorted-screen.png](/bugs/distorted-screen.png)

This bug is rooted in the iDRAC firmware and its VNC server, as it can manifest in VNC clients other than Guacamole. To address the issue, operators can perform a soft reset in iDRAC. If end-users have access to the firmware reset feature, they can utilize it on their own to clear the problem.

## Keystrokes not passing through in early boot phase on iDRAC-based servers

This issue applies to both hardware and Guacamole soft keyboards, and it can hinder users from accessing their firmware settings, including the BIOS and RAID configuration menus. If performing a firmware reset (or a soft reset on the iDRAC) doesn't resolve the problem, operators have the option to use the iDRAC's HTML5 console to apply the necessary firmware changes on behalf of the affected users.

## Random case-sensitivity changes

While typing, it's possible to encounter random changes in case sensitivity, even though the "Shift" key hasn't been pressed, and the "Caps Lock" state hasn't been altered. This issue appears to be specific to Debian and Ubuntu-based clients.

![random-caps-locking.png](/bugs/random-caps-locking.png)

The problem seems to originate from the lack of synchronization between the "Caps Lock" states on the client's machine (the one on which the browser accessing the Guacamole portal is running) and the remote server. This "split" in turn creates four possible cases, two of which result in this undesired behavior:

![caps-states.png](/bugs/caps-states.png)

In order to gain insight into transitioning between the different states outlined in the table above, let's begin with an examination of the hardware keyboard and temporarily disregard the availability of Guacamole's soft keyboard.

A single "Caps Lock" key press toggles between "On" and "Off" states on your local machine but (somewhat surprisingly) does not affect the "Caps Lock" state on the remote machine. As can been seen from the table above, the bug comes to effect when the local "Caps Lock" is "On", regardless of its remote counterpart. So in order to avoid this behavior, make sure to always have the "Caps Lock" in "Off" state on your local (web browsing) machine.

To change the state of "Caps Lock" on the remote machine, the "Caps Lock" key needs to be pressed in a combination with another letter key. For example, "Caps Lock" + "W" will change change the remote "Caps Lock" state. However, this "combo" also has some small and undesired side-effects:

- The letter keystroke (in our example "W") is also sent to the console, typically resulting in it being displayed on the screen.
- The local "Caps Lock" states also changes (and you might need to restore it to "Off" manually in order to avoid the buggy behavior).

### The role of Guacamole's soft keyboard

Keeping the "Caps Lock" pressed in the Guacamole's soft keyboard acts as an inversion of the remote "Caps Lock" state. Once the soft keyboard is closed, this behavior stops, regardless of the "color" (i.e., the pressed state) in which the "Caps" is in that moment:

![soft-keyboard.png](/bugs/soft-keyboard.png)

The soft keyboard does not have any impact on the local "Caps Lock" state, and thus, it provides no assistance in addressing this particular issue.
