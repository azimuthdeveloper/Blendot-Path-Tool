# Blendot-Path-Tool

When you save .blend files, everything imports into Godot EXCEPT paths. My game is very path-heavy so I wrote an importer. Only works for Bezier curves in Godot.

## Instructions

* Clone the repo
* Install the blender plugin via normal methods (it's a python file, I don't actually know python, so if the code is terrible don't judge too harshly)

The blender plugin hooks the save action in Blender, so when you save your .blend file, it exports the curves as json. It also performs a matrix transform on the path so it works in Godot's world.

* Install the Godot plugin through normal methods

In order to use the path importer, you have to have an inherited scene from the .blend file. The plugin performs some error checking to work out if your selected item is actually able to have paths imported or not. I don't know GDScript either so if it's terrible don't judge again haha.

I aim to improve this plugin so the path importing from Blender to Godot is much easier. You can help me work on this by donating here: https://ko-fi.com/stageplay.