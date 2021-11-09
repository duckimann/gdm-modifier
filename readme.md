# GDM-Modifier

## Shoutout to @thiggy01 and people at [change-gdm-background](https://github.com/thiggy01/change-gdm-background)

## Command Arguments
``` bash
--image                   | Set background to an image
--color                   | Set background to an color
--dialog-background       | Set login dialog background to an color
--dialog-font             | Set login dialog font & font color
--fix-streched-background | Fix background stretched on 2+ monitor setup (Experimental)

Syntax:
--image "path_to_image"
--color "color_in_hex_or_rgba_color"
--dialog-background "color_in_hex_or_rgba_color"
--dialog-font "font_color" "font_name

Example:
sudo ./gdm-modifier.sh --image ./00.jpg
sudo ./gdm-modifier.sh --color \#343434
sudo ./gdm-modifier.sh --color "rgb(0,0,0)"
sudo ./gdm-modifier.sh --dialog-background "rgba(0,0,0,0.5)"
sudo ./gdm-modifier.sh --dialog-font "#343434" "FreeMono"
```

# Tested on
```
Ubuntu 20.04.3
Ubuntu 21.10
PopOS 21.04
```

## FAQ (Could be lol)
```
Q: Why do you make this repo? You can contribute to the change-gdm-background right?

A: Yea... I can contribute there, in fact i did. But the thing is the repo name is "change-gdm-background" so i decided to make this one.
```
```
Q: Why it doesn't work on my machine?

A: As the "Tested on" section above, i can only guarantee the script will work on those distro / release.
```
```
Q: Will it have the functionality to make gradient color as GDM Background?

A: Well, it depends. Personally the "gdm.css" is a css file but also not. It can't set linear-gradient like css but have 3 props to set a gradient as background, plus the gradient can only be vertical or horizontal. But if people demand it, i'll add it.
```